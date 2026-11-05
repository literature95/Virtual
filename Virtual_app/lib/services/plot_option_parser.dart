import 'dart:convert';

/// 解析「剧情选项」请求的返回值。
///
/// 约定输出为严格 JSON：`{"options":["…","…","…"]}`。
/// 但小模型/免费端点经常夹带 markdown 代码块、编号或自然语言，
/// 因此按三级降级解析，尽量不让用户看到空结果：
///   1. 直接 JSON（含 ``` 包裹时先剥围栏）；
///   2. 逐行提取（去掉 `1.` / `-` / `•` 等编号与成对引号）；
///   3. 单行内按编号切分。
///
/// 返回最多 3 条、去重、去空白；全部失败返回空列表（由上层提示重试）。
List<String> parsePlotOptions(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const [];

  // 1) 严格 JSON / 代码块包裹的 JSON
    final direct = _parseJson(text) ?? _parseJson(_stripFence(text));
  if (direct != null) {
    final cleaned = direct
        .map(_cleanOption)
        .where((s) => s.isNotEmpty)
        .toList();
    final unique = _dedupe(cleaned);
    if (unique.isNotEmpty) return unique.take(3).toList();
  }

  // 2) 逐行提取（过滤 JSON 括号、字段名等噪声行）
  final lines = _stripFence(text)
      .split(RegExp(r'\r?\n'))
      .map(_cleanOption)
      .where((s) => s.isNotEmpty && !_isNoiseLine(s))
      .toList();
  final lineOptions = _dedupe(lines);
  if (lineOptions.length >= 2) return lineOptions.take(3).toList();

  // 3) 单行编号切分：`1. 我要… 2. 我要… 3. 我要…`
  final inline = _splitByNumbering(text);
  if (inline.isNotEmpty) return inline.take(3).toList();

  // 行数不足时仍允许返回 1 条（模型只给了一条也算可用）
  if (lineOptions.isNotEmpty) return lineOptions.take(3).toList();
  return const [];
}

/// 尝试把文本按 JSON 解析成选项列表；失败返回 null。
List<String>? _parseJson(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      final rawList = decoded['options'];
      if (rawList is List) {
        return rawList
            .whereType<Object>()
            .map((e) => e.toString())
            .toList();
      }
    }
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// 去掉 ``` / ```json 围栏。
String _stripFence(String text) {
  final t = text.trim();
  if (!t.startsWith('```')) return t;
  final firstLineEnd = t.indexOf('\n');
  if (firstLineEnd == -1) return t.replaceAll('`', '').trim();
  var body = t.substring(firstLineEnd + 1);
  final end = body.lastIndexOf('```');
  if (end != -1) body = body.substring(0, end);
  return body.trim();
}

/// 单条清洗：去编号、去项目符号、去成对引号、压缩空白。
String _cleanOption(String line) {
  var s = line.trim();
  if (s.isEmpty) return '';

  // JSON 残留符号
  s = s.replaceAll(RegExp(r'^[\[{]+|[\]},]+$'), '').trim();

  // 编号 / 项目符号：1. 1、 1) (1) - * •
  s = s.replaceAll(
      RegExp(r'^(?:[-*•·]|\(?\d+[.、)．]?|第[一二三123]条[：:]?)\s*'), '');
  s = s.replaceAll(RegExp(r'^\d+[.、)．]\s*'), '').trim();

  // 字段名（模型偶尔输出 "options": "…"）
  s = s.replaceAll(RegExp(r'^"?(?:option|text|content)"?\s*:\s*'), '');

  // 成对引号 / 中文引号
  for (final pair in const [
    ['"', '"'],
    ["'", "'"],
    ['「', '」'],
    ['“', '”'],
    ['『', '』'],
  ]) {
    if (s.length >= 2 && s.startsWith(pair[0]) && s.endsWith(pair[1])) {
      s = s.substring(1, s.length - 1).trim();
    }
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isNoiseLine(String s) {
  final lower = s.toLowerCase();
  if (s == '{' ||
      s == '}' ||
      s == '[' ||
      s == ']' ||
      s == ',' ||
      s == '```') {
    return true;
  }
  if (lower.startsWith('options') ||
      lower.startsWith('"options"') ||
      lower.contains('"options"')) {
    return true;
  }
  // 纯标点（如「……」）不是可用选项
  if (!RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]').hasMatch(s)) return true;
  // 模型拒答 / 解释性文本，按解析失败处理
  if (_looksLikeFailureText(lower)) return true;
  if (s.length <= 1) return true;
  return false;
}

bool _looksLikeFailureText(String lower) {
  const markers = [
    '抱歉',
    '无法生成',
    '无法提供',
    'cannot',
    "can't",
    'sorry',
    'as an ai',
  ];
  return markers.any(lower.contains);
}

List<String> _dedupe(List<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final s in items) {
    if (seen.add(s)) out.add(s);
  }
  return out;
}

/// 把 `1. A 2. B 3. C` 这类单行文本按编号拆成多条。
List<String> _splitByNumbering(String text) {
  final oneLine = text.replaceAll(RegExp(r'\r?\n'), ' ').trim();
  if (!RegExp(r'\d+[.、)．]').hasMatch(oneLine)) return const [];
  final parts = oneLine.split(RegExp(r'\s*\d+[.、)．]\s*'));
  final out = <String>[];
  for (final p in parts) {
    final cleaned = _cleanOption(p);
    if (cleaned.isNotEmpty && !_isNoiseLine(cleaned)) out.add(cleaned);
  }
  return _dedupe(out);
}

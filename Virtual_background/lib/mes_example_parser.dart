/// `mes_example` 原始文本解析器（后端移植版）
///
/// 与 App `Character.parseMesExample`（Virtual_app/lib/models/character.dart）保持
/// 同一套规则——规则固化于 docs/character-card-schema.md 第三节：
///
/// - `<START>` 分块；无 `<START>` 时支持 `1.` `2.` 序号行分界（chub.ai 常见）
/// - 说话人归属：charName / `{{char}}` / assistant 别名 → assistant 侧；
///   `{{user}}` / user 别名 → user 侧；**任何未知第三方名字 → user 侧**
/// - 行首缩进 / 无 `Name:` 结构 / 说话人含叙述符号 → 续写，归并到上一位说话人
/// - 块内多轮按说话人分别拼接（user/assistant 两栏是格式限制）
///
/// 返回结构与 App `CharacterExampleMessage.toJson()` 一致：
/// `[{userMessage, assistantMessage}]` —— App 的 OnlineCharacter.fromJson
/// 直接消费该形态（导入时不做二次解析），后端必须产出相同结构。
library;

/// 解析 CCv2 `mes_example`（字符串）为结构化示例对话数组。
///
/// [raw] 已是 List 时原样归一化返回（兼容种子里直接存数组的情况）；
/// [charName] 用于说话人归属判定（大小写/空白不敏感）。
List<Map<String, dynamic>> parseMesExample(dynamic raw, {String? charName}) {
  if (raw == null) return [];
  if (raw is List) {
    return raw.map((e) {
      if (e is Map) {
        return <String, dynamic>{
          'userMessage': e['userMessage']?.toString() ?? '',
          'assistantMessage': e['assistantMessage']?.toString() ?? '',
          if (e['note'] != null) 'note': e['note'].toString(),
        };
      }
      // 兼容纯字符串数组：整条视作角色台词
      return <String, dynamic>{
        'userMessage': '',
        'assistantMessage': e.toString(),
      };
    }).toList();
  }
  if (raw is! String) return [];

  final result = <Map<String, dynamic>>[];
  for (final block in raw.split('<START>')) {
    if (block.trim().isEmpty) continue;

    final userTurns = <String>[];
    final charTurns = <String>[];
    var isAssistantTurn = false;
    final buffer = StringBuffer();

    void flush() {
      final text = buffer.toString().trim();
      buffer.clear();
      if (text.isEmpty) return;
      (isAssistantTurn ? charTurns : userTurns).add(text);
    }

    /// 结束当前示例并入列
    void emit() {
      flush();
      if (userTurns.isEmpty && charTurns.isEmpty) return;
      result.add(<String, dynamic>{
        'userMessage': userTurns.join('\n\n').trim(),
        'assistantMessage': charTurns.join('\n\n').trim(),
      });
      userTurns.clear();
      charTurns.clear();
    }

    for (final rawLine in block.split('\n')) {
      final trimmed = rawLine.trim();
      final speaker = _matchExampleSpeaker(rawLine, charName);

      if (trimmed.isEmpty) {
        buffer.writeln();
        continue;
      }
      if (_isNumberingLine(trimmed)) {
        // 部分作者不使用 <START>，仅用 `1.` `2.` 分隔示例（如 chub.ai 导出）
        emit();
        continue;
      }

      if (speaker != null) {
        flush();
        isAssistantTurn = speaker.isAssistant;
        if (speaker.content.isNotEmpty) {
          buffer.writeln(speaker.content);
        }
      } else {
        // 续写行：归并到上一位说话人
        buffer.writeln(trimmed);
      }
    }
    emit();
  }
  return result;
}

/// 结构化示例对话数组 → CCv2 `mes_example` 文本（列重组导出路径用，种子卡无
/// raw_card 时兜底；非无损，仅保证语义可读）。
String examplePairsToMesExample(List<dynamic> pairs) {
  final lines = <String>[];
  for (var i = 0; i < pairs.length; i++) {
    final p = pairs[i];
    if (p is! Map) continue;
    if (i > 0) lines.add('');
    lines.add('${i + 1}.');
    final user = p['userMessage']?.toString() ?? '';
    final assistant = p['assistantMessage']?.toString() ?? '';
    if (user.isNotEmpty) lines.add('{{user}}: $user');
    if (assistant.isNotEmpty) lines.add('{{char}}: $assistant');
  }
  return lines.join('\n');
}

bool _isNumberingLine(String trimmed) =>
    RegExp(r'^\d+\s*[.、)）:：]*$').hasMatch(trimmed);

class _ExampleSpeaker {
  const _ExampleSpeaker({required this.isAssistant, required this.content});

  final bool isAssistant;
  final String content;
}

/// 尝试从一行中解析出「说话人 + 内容」；null 表示续写行。
_ExampleSpeaker? _matchExampleSpeaker(String line, String? charName) {
  // 续写判定：行首缩进，或无 `Name:` 结构
  if (line.trimLeft() != line) return null;
  const maxSpeakerLen = 32;
  final idx = line.indexOf(':');
  if (idx <= 0 || idx > maxSpeakerLen) return null;

  final speakerRaw = line.substring(0, idx).trim();
  final content = line.substring(idx + 1).trimLeft();
  if (speakerRaw.isEmpty) return null;
  // 说话人不应含句号/星号等叙述符号，避免把 `*Cricket thinks: maybe` 误判
  if (RegExp(r'[*{}<>\n]').hasMatch(speakerRaw)) {
    // `{{char}}` / `{{user}}` 是合法例外
    if (!RegExp(
      r'^\{\{?\s*(char|user|Char|User|persona)\s*\}?\}$',
    ).hasMatch(speakerRaw)) {
      return null;
    }
  }

  final key = speakerRaw.toLowerCase().replaceAll(RegExp(r'[{}\s]'), '');
  const assistantAliases = {
    'char',
    'assistant',
    'ai',
    'bot',
    'model',
    'system',
    'charname',
    '角色',
    'ai助手',
  };
  const userAliases = {'user', 'you', 'human', 'player', '用户', '我'};

  bool? explicitRole;
  if (assistantAliases.contains(key)) explicitRole = true;
  if (userAliases.contains(key)) explicitRole = false;

  final nameMatchesChar =
      charName != null &&
      charName.trim().isNotEmpty &&
      _normalize(speakerRaw) == _normalize(charName);

  return _ExampleSpeaker(
    isAssistant: explicitRole ?? nameMatchesChar,
    content: content,
  );
}

String _normalize(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/character.dart';
import '../models/lorebook.dart';
import '../utils/png_card_extractor.dart';

/// 一次角色卡导入的完整产物
///
/// Character Card v2/v3 的单个文件里可能同时包含「角色本体」与「世界书」
///（`character_book`）。旧接口只返回 [Character]，世界书会被静默丢弃，导致
/// 人物设定中的专有名词（地点、货币、组织）失去定义，模型只能靠猜测补全。
/// 因此这里统一返回 bundle，由调用方决定如何落库。
class CharacterImportBundle {
  /// 角色本体
  final Character character;

  /// 从 `character_book` 解析出的世界书（无该节点时为 null）
  final Lorebook? lorebook;

  /// 导入过程中产生的提示（字段降级、不支持的写法等）
  final List<String> warnings;

  /// 原始卡片来源：`Character Card v2` / `Character Card v3` / `SillyTavern`
  final String sourceFormat;

  const CharacterImportBundle({
    required this.character,
    required this.sourceFormat,
    this.lorebook,
    this.warnings = const [],
  });

  bool get hasLorebook => lorebook != null;

  /// 人类可读的导入摘要，用于 UI 提示
  String get summary {
    final b = StringBuffer()
      ..write(sourceFormat)
      ..write(' · 示例对话 ${character.exampleMessages.length} 条')
      ..write(' · 备用开场 ${character.alternateGreetings.length} 条');
    if (hasLorebook) {
      b.write(' · 世界书 ${lorebook!.entries.length} 条');
    }
    if (character.avatarPath?.isNotEmpty ?? false) {
      b.write(' · 头像');
    }
    return b.toString();
  }
}

class CharacterImportService {
  final Dio _dio;

  CharacterImportService(this._dio) {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Import from URL (直链 JSON / RisuAI / JannyAI / Pygmalion)
  ///
  /// 注意：chub.ai 网页链接（`chub.ai/characters/...`）无法直接导入——其公开
  /// 下载 API 已废弃（实测 `POST /api/characters/download` 返回 405/422），
  /// 完整角色卡需登录获取。此处识别后给出可操作的引导，而非静默失败。
  Future<Character> importFromUrl(String url) async =>
      (await importBundleFromUrl(url)).character;

  /// 同 [importFromUrl]，但保留完整产物（含 `character_book` 世界书）
  Future<CharacterImportBundle> importBundleFromUrl(String url) async {
    if (_isChubPage(url)) {
      throw Exception(
        'chub.ai 网页链接无法直接导入：请在该角色卡页面点击 Download '
        '下载 PNG/JSON 文件，再使用「从文件导入」。',
      );
    }
    final response = await _dio.get(url);
    return importBundleFromResponse(response.data);
  }

  CharacterImportBundle importBundleFromResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return importBundleFromJson(data);
    } else if (data is String) {
      final trimmed = data.trimLeft();
      if (trimmed.startsWith('{')) {
        try {
          return importBundleFromJson(jsonDecode(data) as Map<String, dynamic>);
        } catch (_) {
          throw Exception('响应不是合法的角色卡 JSON');
        }
      }
      throw Exception('响应不是 JSON，请提供角色卡直链（JSON 端点）');
    }
    throw Exception('不支持的响应格式');
  }

  /// 是否为 chub.ai 角色卡网页链接（而非角色卡 JSON 直链）。
  bool _isChubPage(String url) => RegExp(
        r'https?://(?:www\.)?chub\.ai/characters/',
        caseSensitive: false,
      ).hasMatch(url);

  /// 从原始字节导入 —— **平台无关的主入口**
  ///
  /// 调用方只需提供 `Uint8List`（`file_picker` 的 `withData: true`、`dio` 的
  /// `ResponseBody`、内存中的粘贴内容均可），因此 Web / 桌面 / 移动三端
  /// 共用同一条路径，不再依赖 `dart:io`（Web 上 `File` 不可用）。
  ///
  /// 回退顺序：
  /// 1. 按 PNG 规范解析 `tEXt` / `zTXt` / `iTXt` 中的 `chara` / `ccv3` 块
  ///    （压缩块先 zlib 解压，再 base64 解码）；
  /// 2. 把整包按 UTF-8 解码后当作 JSON 文本（裸 `.json`，容忍 BOM）；
  /// 3. 把整包当作文本，用花括号配平切出候选 JSON（兼容非规范 PNG）。
  CharacterImportBundle importBundleFromBytes(
    Uint8List bytes, {
    String? sourceName,
  }) {
    final label = sourceName ?? '文件';

    // 1) 规范 PNG 容器（CCv2 / CCv3 的实际导出形态）
    final payload = extractPngCard(bytes);
    if (payload != null) {
      try {
        final bundle = importBundleFromJsonText(payload.json);
        return CharacterImportBundle(
          character: bundle.character,
          lorebook: bundle.lorebook,
          warnings: bundle.warnings,
          sourceFormat: '${bundle.sourceFormat} · PNG(${payload.keyword})',
        );
      } catch (e) {
        throw Exception(
          'PNG 内嵌角色卡解析失败（关键字 ${payload.keyword}）：$e',
        );
      }
    }

    // 2) 纯 UTF-8 JSON 文本（裸 .json 文件；容忍 BOM 与前后空白）
    //
    // 必须先于 latin1 文本扫描：`String.fromCharCodes` 会把 UTF-8 字节逐字节
    // 映射成字符，多字节中文因此变成乱码，但**仍是合法 JSON 文本**，会"解析成功"
    // 并带着乱码角色名返回，静默污染数据。
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      if (text.trimLeft().startsWith('{')) return importBundleFromJsonText(text);
    } catch (_) {
      // 落到下一步回退
    }

    // 3) 非规范 PNG：文本块内直写 JSON，或 JSON 混在更大的文本里
    final fallback = _extractFromTextContent(String.fromCharCodes(bytes));
    if (fallback != null) return fallback;

    // 提示要能区分三种失败：普通图片（无卡片数据）、其他格式、非 PNG 文本
    if (hasPngSignature(bytes)) {
      throw Exception(
        '$label 是一张 PNG 图片，但其中不含角色卡数据 —— '
        '未找到 chara / ccv3 文本块，可能是直接导出的插画而非角色卡',
      );
    }
    throw Exception(
      bytes.length < 8
          ? '$label 不是有效的 PNG，也不是角色卡 JSON'
          : '在 $label 中未找到角色卡数据',
    );
  }

  /// 从 JSON 文本导入（含 BOM / 前后空白容忍）
  CharacterImportBundle importBundleFromJsonText(String text) {
    final decoded = jsonDecode(_stripBom(text));
    if (decoded is Map<String, dynamic>) {
      return importBundleFromJson(decoded);
    }
    throw Exception('文件内容不是角色卡对象');
  }

  String _stripBom(String text) =>
      text.startsWith('\uFEFF') ? text.substring(1) : text;

  /// Import from JSON (supports CCv2, CCv3, SillyTavern formats)
  Character importFromJson(Map<String, dynamic> json) =>
      importBundleFromJson(json).character;

  /// 同 [importFromJson]，但保留完整产物（含世界书）
  CharacterImportBundle importBundleFromJson(Map<String, dynamic> json) {
    // CCv3 顶层包装
    if (json['spec'] == 'chara_card_v3') {
      return _parseBundle(json, sourceFormat: 'Character Card v3');
    }
    // CCv2 顶层包装：{spec, spec_version, data}
    final spec = json['spec']?.toString();
    if (json['data'] is Map) {
      final data = json['data'] as Map<String, dynamic>;
      if (data.containsKey('name') || spec != null) {
        final version = json['spec_version']?.toString();
        final label = version == null || version.isEmpty
            ? 'Character Card v2'
            : 'Character Card v$version';
        return _parseBundle(json, sourceFormat: label);
      }
    }
    // SillyTavern / 平铺直接格式
    if (json.containsKey('name')) {
      return _parseBundle(
        json,
        sourceFormat: 'SillyTavern',
        flat: true,
      );
    }
    throw Exception('无法识别的角色卡格式');
  }

  CharacterImportBundle _parseBundle(
    Map<String, dynamic> json, {
    required String sourceFormat,
    bool flat = false,
  }) {
    final warnings = <String>[];
    final d = flat
        ? json
        : json['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final name = (d['name'] ?? '') as String;

    // ---- 扩展字段归一化 ----
    final extensions = <String, dynamic>{
      ...Map<String, dynamic>.from(d['extensions'] ?? const {}),
    };
    _normalizeExtensions(extensions);

    // ---- 示例对话（需角色名判定说话人归属） ----
    final exampleMessages = Character.parseMesExample(
      d['mes_example'] ?? d['mesExample'],
      charName: name,
    );
    if (d['mes_example'] is String &&
        (d['mes_example'] as String).trim().isNotEmpty &&
        exampleMessages.isEmpty) {
      warnings.add('示例对话未能解析，已跳过');
    }

    // ---- 世界书 ----
    Lorebook? lorebook;
    final bookRaw = d['character_book'];
    if (bookRaw is Map && (bookRaw['entries'] as List? ?? []).isNotEmpty) {
      try {
        lorebook = Lorebook.fromCharacterBook(
          Map<String, dynamic>.from(bookRaw),
          fallbackName: '$name 的世界书',
        );
      } catch (e) {
        warnings.add('世界书解析失败：$e');
      }
    }

    final character = Character(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      nickname: d['nickname'] as String?,
      description: d['description'] as String?,
      personality: d['personality'] as String?,
      scenario: d['scenario'] as String?,
      firstMessage: (d['first_mes'] ?? d['firstMessage']) as String?,
      avatarPath: d['avatar'] as String?,
      creatorNotes: d['creator_notes'] as String?,
      systemPrompt: d['system_prompt'] as String?,
      postHistoryInstructions: d['post_history_instructions'] as String?,
      tags: _asStringList(d['tags']),
      alternateGreetings:
          _asStringList(d['alternate_greetings'] ?? d['alternateGreetings']),
      exampleMessages: exampleMessages,
      groupOnlyGreetings: _asStringList(d['group_only_greetings']),
      creator: d['creator'] as String?,
      characterVersion: d['character_version']?.toString(),
      source: sourceFormat,
      extensions: extensions,
      creatorNotesMultilingual:
          _asStringMap(d['creator_notes_multilingual']),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return CharacterImportBundle(
      character: character,
      lorebook: lorebook,
      sourceFormat: sourceFormat,
      warnings: warnings,
    );
  }

  /// 将厂商私有扩展提升为本项目约定的键，并把源里的 snake_case 一并补上
  ///
  /// 主要处理 `extensions.depth_prompt.prompt` —— Prompt 组装层读取的是
  /// `extensions['depthPrompt']`，原名 `depth_prompt` 会被漏读。
  void _normalizeExtensions(Map<String, dynamic> extensions) {
    final depthPrompt = extensions['depth_prompt'];
    if (depthPrompt is Map) {
      final prompt = depthPrompt['prompt']?.toString() ?? '';
      final depth = depthPrompt['depth'];
      if (prompt.isNotEmpty) extensions['depthPrompt'] = prompt;
      if (depth != null) extensions['depth'] = depth;
    }

    // chub.ai 的 full_path 保留下来，便于回溯来源
    final chub = extensions['chub'];
    if (chub is Map && chub['full_path'] != null) {
      extensions['sourceUrl'] = 'https://chub.ai/characters/${chub['full_path']}';
    }
  }

  /// 从任意文本（非规范 PNG 的块载荷、裸 JSON 文本等）中抽取角色卡 JSON
  ///
  /// 用「锚点 + 花括号配平」而不是 `\{[^{}]*"spec":…[^{}]*\}` 这类正则：
  /// CCv2/v3 的包装体必然嵌套 `data` 对象，`[^{}]*` 跨不过内层花括号，
  /// 对标准包装恒不匹配（旧实现的隐蔽缺陷）。
  CharacterImportBundle? _extractFromTextContent(String content) {
    // 优先锚定 spec 声明，可精确落在包装体边界上；退而锚定 name 字段
    final anchors = <RegExp>[
      RegExp(r'"spec"\s*:\s*"chara_card_v[23]"'),
      RegExp(r'"name"\s*:\s*"'),
    ];
    for (final anchor in anchors) {
      for (final match in anchor.allMatches(content)) {
        final sliced = _sliceEnclosingObject(content, match.start);
        if (sliced == null) continue;
        for (final text in _sliceDecodings(sliced)) {
          try {
            final decoded = jsonDecode(text);
            if (decoded is Map<String, dynamic>) {
              return importBundleFromJson(decoded);
            }
          } catch (_) {
            // 换下一种解码方式
          }
        }
      }
    }
    return null;
  }

  /// `content` 由 `String.fromCharCodes(bytes)` 构造 —— 每个代码单元恰好等于
  /// 一个原始字节。因此切出的片段可以按字节还原后再正确按 UTF-8 解码，
  /// 避免多字节字符被当成 latin1 而变成乱码。
  ///
  /// **UTF-8 优先**：latin1 解释对 ASCII 与 UTF-8 同样"能解析成功"，先试它
  /// 只会得到乱码却不报错。反过来，真正的 latin1 内容在 UTF-8 解码时会抛错，
  /// 自然退回 [sliced]。
  Iterable<String> _sliceDecodings(String sliced) sync* {
    try {
      final bytes = latin1.encode(sliced);
      final proper = utf8.decode(bytes, allowMalformed: false);
      if (proper != sliced) yield proper;
    } catch (_) {
      // 原始字节不是合法 UTF-8，保持 latin1 解释
    }
    yield sliced;
  }

  /// 以 [at] 为锚点向左右配平花括号，切出完整包含该位置的 JSON 对象
  String? _sliceEnclosingObject(String s, int at) {
    var depth = 0;
    var start = -1;
    for (var i = at; i >= 0; i--) {
      final c = s.codeUnitAt(i);
      if (c == 0x7D) depth++; // }
      if (c == 0x7B) {
        // {
        depth--;
        if (depth <= 0) {
          start = i;
          break;
        }
      }
    }
    if (start < 0) return null;

    depth = 0;
    for (var i = start; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c == 0x7B) depth++;
      if (c == 0x7D) {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Map<String, String> _asStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/character.dart';
import '../models/lorebook.dart';

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

  /// Import from local PNG file (extracts embedded character card)
  Future<Character> importFromPng(String filePath) async =>
      (await importBundleFromPng(filePath)).character;

  /// 同 [importFromPng]，但保留完整产物
  Future<CharacterImportBundle> importBundleFromPng(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // PNG 的元数据以 latin1 兼容字节存放，避免 UTF-8 解码破坏二进制结构
    final String content = String.fromCharCodes(bytes);

    final bundle = _extractFromTextContent(content, source: 'PNG');
    if (bundle != null) return bundle;
    throw Exception('PNG 文件中未找到角色卡数据');
  }

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

  /// 从任意文本（PNG 解码结果等）中抽取角色卡 JSON
  CharacterImportBundle? _extractFromTextContent(
    String content, {
    required String source,
  }) {
    final jsonPattern = RegExp(r'\{[^{}]*"spec"\s*:\s*"chara_card_v[23]"[^{}]*\}');
    final match = jsonPattern.firstMatch(content);
    if (match != null) {
      try {
        return importBundleFromJson(jsonDecode(match.group(0)!) as Map<String, dynamic>);
      } catch (_) {}
    }

    final broadPattern = RegExp(r'\{[\s\S]*"name"\s*:\s*"[^"]+"[\s\S]*\}');
    final broadMatch = broadPattern.firstMatch(content);
    if (broadMatch != null) {
      try {
        return importBundleFromJson(jsonDecode(broadMatch.group(0)!) as Map<String, dynamic>);
      } catch (_) {}
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

  /// Import from local JSON file
  Future<Character> importFromFile(String filePath) async =>
      (await importBundleFromFile(filePath)).character;

  /// 同 [importFromFile]，但保留完整产物
  Future<CharacterImportBundle> importBundleFromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      return importBundleFromJson(decoded);
    }
    throw Exception('文件内容不是角色卡对象');
  }
}

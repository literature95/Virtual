import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/character.dart';

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
  Future<Character> importFromUrl(String url) async {
    if (_isChubPage(url)) {
      throw Exception(
        'chub.ai 网页链接无法直接导入：请在该角色卡页面点击 Download '
        '下载 PNG/JSON 文件，再使用「从文件导入」。',
      );
    }
    final response = await _dio.get(url);
    final data = response.data;
    
    // Try to detect format
    if (data is Map<String, dynamic>) {
      return importFromJson(data);
    } else if (data is String) {
      // Might be JSON string
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        return importFromJson(json);
      } catch (_) {
        throw Exception('无法解析响应数据');
      }
    }
    throw Exception('不支持的响应格式');
  }

  /// 是否为 chub.ai 角色卡网页链接（而非角色卡 JSON 直链）。
  bool _isChubPage(String url) => RegExp(
        r'https?://(?:www\.)?chub\.ai/characters/',
        caseSensitive: false,
      ).hasMatch(url);

  /// Import from local PNG file (extracts embedded character card)
  Future<Character> importFromPng(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    
    // PNG files may contain embedded chara_card_v2 JSON in tEXt chunks
    // Look for JSON pattern in the binary data
    final String content = String.fromCharCodes(bytes);
    
    // Try to find JSON block with spec character
    final jsonPattern = RegExp(r'\{[^{}]*"spec"\s*:\s*"chara_card_v[23]"[^{}]*\}');
    final match = jsonPattern.firstMatch(content);
    
    if (match != null) {
      try {
        final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        return importFromJson(json);
      } catch (_) {}
    }
    
    // Try broader JSON extraction
    final broadPattern = RegExp(r'\{[\s\S]*"name"\s*:\s*"[^"]+"[\s\S]*\}');
    final broadMatch = broadPattern.firstMatch(content);
    if (broadMatch != null) {
      try {
        final json = jsonDecode(broadMatch.group(0)!) as Map<String, dynamic>;
        return importFromJson(json);
      } catch (_) {}
    }
    
    throw Exception('PNG 文件中未找到角色卡数据');
  }

  /// Import from JSON (supports CCv2, CCv3, SillyTavern formats)
  Character importFromJson(Map<String, dynamic> json) {
    // Check for CCv3 wrapper
    if (json.containsKey('spec') && json['spec'] == 'chara_card_v3') {
      return _parseCCv3(json);
    }
    
    // Check for CCv2 wrapper
    if (json.containsKey('data') && json['data'] is Map) {
      final data = json['data'] as Map<String, dynamic>;
      if (data.containsKey('name')) {
        return _parseCCv3({'data': data, 'spec': 'chara_card_v3'});
      }
    }
    
    // Direct format (SillyTavern style)
    if (json.containsKey('name')) {
      return _parseDirect(json);
    }
    
    throw Exception('无法识别的角色卡格式');
  }

  Character _parseCCv3(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return _parseFields(data);
  }

  Character _parseDirect(Map<String, dynamic> json) {
    return _parseFields(json);
  }

  /// 从角色卡字段 map 构建 Character，覆盖 CCv3 / SillyTavern 完整字段。
  ///
  /// 字段名兼容 snake_case（CCv3）与 camelCase（SillyTavern 直接格式）。
  /// 关键人设字段（示例对话、系统提示词、备用问候等）在此处完整映射，
  /// 避免导入时静默丢失导致角色「漂移」（OOC）。
  Character _parseFields(Map<String, dynamic> d) {
    return Character(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: (d['name'] ?? '') as String,
      nickname: d['nickname'] as String?,
      description: d['description'] as String?,
      personality: d['personality'] as String?,
      scenario: d['scenario'] as String?,
      firstMessage:
          (d['first_mes'] ?? d['firstMessage'] ?? '') as String?,
      avatarPath: d['avatar'] as String?,
      creatorNotes: d['creator_notes'] as String?,
      systemPrompt: d['system_prompt'] as String?,
      postHistoryInstructions: d['post_history_instructions'] as String?,
      tags: _asStringList(d['tags']),
      alternateGreetings: _asStringList(d['alternate_greetings']),
      exampleMessages: Character.parseMesExample(d['mes_example']),
      groupOnlyGreetings: _asStringList(d['group_only_greetings']),
      creator: d['creator'] as String?,
      characterVersion: d['character_version']?.toString(),
      source: d['source'] as String?,
      extensions: (d['extensions'] as Map<String, dynamic>?) ?? const {},
      creatorNotesMultilingual: _asStringMap(d['creator_notes_multilingual']),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
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
  Future<Character> importFromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return importFromJson(json);
  }
}
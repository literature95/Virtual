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

  /// Import from URL (Chub.ai, RisuAI, JannyAI, Pygmalion)
  Future<Character> importFromUrl(String url) async {
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
    return Character(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      personality: data['personality'] as String? ?? '',
      scenario: data['scenario'] as String? ?? '',
      firstMessage: data['first_mes'] as String? ?? '',
      creatorNotes: data['creator_notes'] as String? ?? '',
      creator: data['creator'] as String? ?? '',
      characterVersion: data['character_version']?.toString() ?? '',
      nickname: data['nickname'] as String? ?? '',
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
      avatarPath: data['avatar'] as String? ?? '',
      extensions: (data['extensions'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Character _parseDirect(Map<String, dynamic> json) {
    return Character(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      personality: json['personality'] as String? ?? '',
      scenario: json['scenario'] as String? ?? '',
      firstMessage: json['first_mes'] as String? ?? '',
      creatorNotes: json['creator_notes'] as String? ?? '',
      creator: json['creator'] as String? ?? '',
      characterVersion: json['character_version']?.toString() ?? '',
      nickname: json['nickname'] as String? ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      avatarPath: json['avatar'] as String? ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Import from local JSON file
  Future<Character> importFromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return importFromJson(json);
  }
}
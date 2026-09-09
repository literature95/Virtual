import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/character.dart';

/// 在线角色卡（来自 Virtual_background /api/characters）
///
/// 列表接口返回精简字段，详情接口返回完整角色卡。两种形态共用同一套解析，
/// 缺失字段自然为空，因此列表可以直接用于卡片墙展示，详情可以用于一键导入。
class OnlineCharacter {
  final String id;
  final String name;
  final String description;
  final String? avatarUrl;
  final List<String> tags;
  final String? greeting;
  final String? persona;
  final String? firstMessage;

  // --- 完整角色卡字段（CCv3 对齐，仅详情接口下发）---
  final String? nickname;
  final String? personality;
  final String? scenario;
  final String? systemPrompt;
  final String? postHistoryInstructions;
  final String? creatorNotes;
  final String? creator;
  final String? characterVersion;
  final String? source;
  final List<String> alternateGreetings;
  final List<String> groupOnlyGreetings;
  final List<CharacterExampleMessage> exampleMessages;
  final Map<String, dynamic> extensions;
  final Map<String, String> creatorNotesMultilingual;

  const OnlineCharacter({
    required this.id,
    required this.name,
    required this.description,
    this.avatarUrl,
    this.tags = const [],
    this.greeting,
    this.persona,
    this.firstMessage,
    this.nickname,
    this.personality,
    this.scenario,
    this.systemPrompt,
    this.postHistoryInstructions,
    this.creatorNotes,
    this.creator,
    this.characterVersion,
    this.source,
    this.alternateGreetings = const [],
    this.groupOnlyGreetings = const [],
    this.exampleMessages = const [],
    this.extensions = const {},
    this.creatorNotesMultilingual = const {},
  });

  factory OnlineCharacter.fromJson(Map<String, dynamic> json) {
    List<String> stringList(Object? raw) =>
        (raw as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    return OnlineCharacter(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名',
      description: json['description']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      tags: stringList(json['tags']),
      greeting: json['greeting']?.toString(),
      persona: json['persona']?.toString(),
      firstMessage: json['firstMessage']?.toString(),
      nickname: json['nickname']?.toString(),
      personality: json['personality']?.toString(),
      scenario: json['scenario']?.toString(),
      systemPrompt: json['systemPrompt']?.toString(),
      postHistoryInstructions: json['postHistoryInstructions']?.toString(),
      creatorNotes: json['creatorNotes']?.toString(),
      creator: json['creator']?.toString(),
      characterVersion: json['characterVersion']?.toString(),
      source: json['source']?.toString(),
      alternateGreetings: stringList(json['alternateGreetings']),
      groupOnlyGreetings: stringList(json['groupOnlyGreetings']),
      exampleMessages: (json['exampleMessages'] as List<dynamic>? ?? [])
          .map((e) => CharacterExampleMessage.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList(),
      extensions: Map<String, dynamic>.from(json['extensions'] ?? {}),
      creatorNotesMultilingual: (json['creatorNotesMultilingual'] as Map? ?? {})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }

  /// 是否为完整角色卡（含结构化人设），而非列表精简条目
  bool get isFullCard =>
      exampleMessages.isNotEmpty || personality != null || scenario != null;

  /// 导入到本地时写入 [Character.extensions] 的内容
  ///
  /// 除卡片自带扩展外，额外写入 `sourceId`（= 后端角色 ID）。本地 id 是
  /// `createCharacter` 内部现生成的 uuid，后端 ID 若不留存就无从查重，
  /// 同一个在线角色会被反复导入成多个副本。
  Map<String, dynamic> get importExtensions => <String, dynamic>{
        ...extensions,
        if (id.isNotEmpty) 'sourceId': id,
      };

  /// 转为本地 Character（用于一键导入）
  Character toCharacter() => Character(
        id: id,
        name: name,
        nickname: nickname,
        description: description,
        // 后端未单独下发 persona 时，退回 greeting 语义，避免丢失旧数据
        personality: personality,
        scenario: scenario,
        firstMessage: firstMessage ?? greeting,
        avatarPath: avatarUrl,
        creatorNotes: creatorNotes,
        systemPrompt: systemPrompt,
        postHistoryInstructions: postHistoryInstructions,
        tags: tags,
        alternateGreetings: alternateGreetings,
        exampleMessages: exampleMessages,
        groupOnlyGreetings: groupOnlyGreetings,
        creator: creator,
        characterVersion: characterVersion,
        source: source ?? 'Virtual backend',
        extensions: importExtensions,
        creatorNotesMultilingual: creatorNotesMultilingual,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}

/// 在线角色卡服务：从本地 Virtual_background 后端拉取
class OnlineCharacterService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// 拉取在线角色卡列表；[backendBaseUrl] 为空时返回空
  Future<List<OnlineCharacter>> fetchCharacters(String backendBaseUrl) async {
    final base = _normalizeBase(backendBaseUrl);
    if (base.isEmpty) return const [];
    final res = await _dio.get<List<dynamic>>(
      '$base/api/characters',
      options: Options(responseType: ResponseType.json),
    );
    final data = res.data ?? const [];
    return data
        .map((e) => OnlineCharacter.fromJson(
            e is Map<String, dynamic> ? e : jsonDecode(jsonEncode(e))))
        .toList();
  }

  /// 拉取单张完整角色卡（`/api/characters/:id`）
  ///
  /// 列表接口为节省带宽只下发卡片墙所需字段；一键导入必须走详情接口，
  /// 否则 exampleMessages / personality 等核心人设会丢失。
  Future<OnlineCharacter> fetchCharacter(
    String backendBaseUrl,
    String id,
  ) async {
    final base = _normalizeBase(backendBaseUrl);
    final res = await _dio.get<Map<String, dynamic>>(
      '$base/api/characters/${Uri.encodeComponent(id)}',
      options: Options(responseType: ResponseType.json),
    );
    return OnlineCharacter.fromJson(res.data ?? const {});
  }

  String _normalizeBase(String backendBaseUrl) {
    final base = backendBaseUrl.trim();
    if (base.isEmpty) return '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }
}

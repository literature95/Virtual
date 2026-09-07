import 'dart:convert';

import 'package:dio/dio.dart';

/// 在线角色卡（来自 Virtual_background /api/characters）
class OnlineCharacter {
  final String id;
  final String name;
  final String description;
  final String? avatarUrl;
  final List<String> tags;
  final String? greeting;
  final String? persona;
  final String? firstMessage;

  const OnlineCharacter({
    required this.id,
    required this.name,
    required this.description,
    this.avatarUrl,
    this.tags = const [],
    this.greeting,
    this.persona,
    this.firstMessage,
  });

  factory OnlineCharacter.fromJson(Map<String, dynamic> json) {
    return OnlineCharacter(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名',
      description: json['description']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      greeting: json['greeting']?.toString(),
      persona: json['persona']?.toString(),
      firstMessage: json['firstMessage']?.toString(),
    );
  }
}

/// 在线角色卡服务：从本地 Virtual_background 后端拉取
class OnlineCharacterService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// 拉取在线角色卡列表；[backendBaseUrl] 为空时返回空
  Future<List<OnlineCharacter>> fetchCharacters(String backendBaseUrl) async {
    final base = backendBaseUrl.trim();
    if (base.isEmpty) return const [];
    final res = await _dio.get<List<dynamic>>(
      '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}'
      '/api/characters',
      options: Options(responseType: ResponseType.json),
    );
    final data = res.data ?? const [];
    return data
        .map((e) => OnlineCharacter.fromJson(
            e is Map<String, dynamic> ? e : jsonDecode(jsonEncode(e))))
        .toList();
  }
}

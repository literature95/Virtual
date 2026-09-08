import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/avatar_url.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';

/// GET /api/characters/[id] — 角色卡详情（完整字段）
///
/// 字段名统一 camelCase；`avatarUrl` 为相对路径时按请求来源补全为绝对 URL，
/// 保证 App / Web 端零改动，且真机调试可自动适配局域网 IP。
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  Map<String, dynamic>? result;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      // execute 直接接收 SQL 字符串 + parameters（与既有路由写法保持一致）
      final rows = await conn!.execute(
        '''
SELECT id, name, nickname, description, personality, scenario, avatar_url, tags,
       greeting, first_message, persona, example_messages, system_prompt,
       post_history_instructions, creator_notes, creator, character_version,
       source, alternate_greetings, group_only_greetings, extensions,
       creator_notes_multilingual
  FROM characters WHERE id = @id''',
        parameters: {'id': id},
      );
      if (rows.isNotEmpty) {
        final r = rows.first.toColumnMap();
        result = {
          'id': r['id'],
          'name': r['name'],
          'nickname': r['nickname'],
          'description': r['description'],
          'personality': r['personality'],
          'scenario': r['scenario'],
          'avatar_url': r['avatar_url'],
          'tags': CharacterCardMapper.decodeJson<List<String>>(
              r['tags'], const []),
          'greeting': r['greeting'],
          'first_mes': r['first_message'],
          'persona': r['persona'],
          'example_messages': CharacterCardMapper.decodeJson<List<dynamic>>(
              r['example_messages'], const []),
          'system_prompt': r['system_prompt'],
          'post_history_instructions': r['post_history_instructions'],
          'creator_notes': r['creator_notes'],
          'creator': r['creator'],
          'character_version': r['character_version'],
          'source': r['source'],
          'alternate_greetings': CharacterCardMapper.decodeJson<List<String>>(
              r['alternate_greetings'], const []),
          'group_only_greetings':
              CharacterCardMapper.decodeJson<List<String>>(
                  r['group_only_greetings'], const []),
          'extensions': CharacterCardMapper.decodeJson<Map<String, dynamic>>(
              r['extensions'], const {}),
          'creator_notes_multilingual':
              CharacterCardMapper.decodeJson<Map<String, String>>(
                  r['creator_notes_multilingual'], const {}),
        };
      }
    } catch (e) {
      // 回退到内存种子数据
    }
  }

  result ??= SeedData.characters.firstWhere(
    (c) => c['id'] == id,
    orElse: () => <String, dynamic>{},
  );

  if (result.isEmpty || result['id'] == null) {
    return Response(statusCode: 404, body: 'Character not found');
  }

  final avatar = (result['avatar_url'] ?? result['avatarUrl'])?.toString();
  final body = CharacterCardMapper.toApiJson(
    result,
    avatarUrl: avatar == null || avatar.isEmpty
        ? null
        : resolveAvatarUrl(avatar, context.request.uri),
  );

  return Response.json(body: body);
}

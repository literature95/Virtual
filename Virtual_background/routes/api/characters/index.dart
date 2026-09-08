import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/avatar_url.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';

/// GET /api/characters — 角色卡列表
///
/// 列表只下发卡片墙需要的精简字段（不含 example_messages / description 全文），
/// 需要完整角色卡请请求 `/api/characters/[id]`。
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  List<Map<String, dynamic>> chars;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      final rows = await conn!.execute(
        'SELECT id, name, description, avatar_url, tags, greeting, persona, '
        'creator, character_version FROM characters ORDER BY created_at',
      );
      chars = rows.map((row) {
        final r = row.toColumnMap();
        return {
          'id': r['id'],
          'name': r['name'],
          'description': r['description'],
          'avatar_url': r['avatar_url'],
          'tags': CharacterCardMapper.decodeJson<List<String>>(
              r['tags'], const []),
          'greeting': r['greeting'],
          'persona': r['persona'],
          'creator': r['creator'],
          'character_version': r['character_version'],
        };
      }).toList();
    } catch (e) {
      chars = SeedData.characters;
    }
  } else {
    chars = SeedData.characters;
  }

  final uri = context.request.uri;
  final summary = chars.map((c) {
    final raw = (c['avatar_url'] ?? c['avatarUrl'])?.toString();
    return CharacterCardMapper.toSummaryJson(
      c,
      avatarUrl: raw == null || raw.isEmpty ? null : resolveAvatarUrl(raw, uri),
    );
  }).toList();

  return Response.json(body: summary);
}

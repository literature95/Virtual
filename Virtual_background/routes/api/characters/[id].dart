import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/avatar_url.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';
import 'package:virtual_background/path_param.dart';

/// GET /api/characters/[id] — 角色卡详情（完整字段）
///
/// 字段名统一 camelCase；`avatarUrl` 为相对路径时按请求来源补全为绝对 URL，
/// 保证 App / Web 端零改动，且真机调试可自动适配局域网 IP。
///
/// 多版本语义（docs/character-publish-design.md §2.2）：按 id 取 updated_at
/// 最新版；详情在现有字段基础上追加 `characterBook`（CCv3 原样 JSON，
/// 与 App lorebook.dart 的双向映射兼容）。`rawCard` 不下发（体积大且
/// App 无消费方，导出走 /api/characters/[id]/export）。
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  // dart_frog 不解码路径参数：含汉字的 id 会以字面量 `%E5%B8%8C…` 到达，
  // 与库中的 `希露妲` 不等 → 恒 404。此处归一化（原因见 path_param.dart）。
  final characterId = decodePathParam(id);

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  Map<String, dynamic>? result;
  // jsonb 列在 postgres 驱动下可能返回 Map 或 String，统一用 dynamic 接住，
  // 交由 CharacterCardMapper.decodeJson 归一化。
  dynamic characterBookRaw;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      // execute 直接接收 SQL 字符串 + parameters（与既有路由写法保持一致）
      final rows = await conn!.execute(
        // postgres 3.5：@命名参数必须经 Sql.named 解析（同 index.dart / seed.dart）。
        Sql.named('''
SELECT id, name, nickname, description, personality, scenario, avatar_url, tags,
       greeting, first_message, persona, example_messages, system_prompt,
       post_history_instructions, creator_notes, creator, character_version,
       source, alternate_greetings, group_only_greetings, extensions,
       creator_notes_multilingual, character_book
  FROM characters WHERE id = @id
  ORDER BY updated_at DESC
  LIMIT 1'''),
        parameters: {'id': characterId},
      );
      if (rows.isNotEmpty) {
        final r = rows.first.toColumnMap();
        // 原样保留驱动返回值：jsonb 列可能已是 Map，直接 toString() 会得到
        // Dart 风格字符串（键无引号），后续 jsonDecode 必然失败 → 世界书变空。
        characterBookRaw = r['character_book'];
        result = {
          'id': r['id'],
          'name': r['name'],
          'nickname': r['nickname'],
          'description': r['description'],
          'personality': r['personality'],
          'scenario': r['scenario'],
          'avatar_url': r['avatar_url'],
          'tags': CharacterCardMapper.decodeJson<List<String>>(
            r['tags'],
            const [],
          ),
          'greeting': r['greeting'],
          'first_mes': r['first_message'],
          'persona': r['persona'],
          'example_messages': CharacterCardMapper.decodeJson<List<dynamic>>(
            r['example_messages'],
            const [],
          ),
          'system_prompt': r['system_prompt'],
          'post_history_instructions': r['post_history_instructions'],
          'creator_notes': r['creator_notes'],
          'creator': r['creator'],
          'character_version': r['character_version'],
          'source': r['source'],
          'alternate_greetings': CharacterCardMapper.decodeJson<List<String>>(
            r['alternate_greetings'],
            const [],
          ),
          'group_only_greetings': CharacterCardMapper.decodeJson<List<String>>(
            r['group_only_greetings'],
            const [],
          ),
          'extensions': CharacterCardMapper.decodeJson<Map<String, dynamic>>(
            r['extensions'],
            const {},
          ),
          'creator_notes_multilingual':
              CharacterCardMapper.decodeJson<Map<String, String>>(
                r['creator_notes_multilingual'],
                const {},
              ),
        };
      }
    } catch (e) {
      // 回退到内存种子数据
    }
  }

  result ??= SeedData.characters.firstWhere(
    (c) => c['id'] == characterId,
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

  // characterBook：DB 行原样下发（种子降级路径走 map 内的键）
  final book = characterBookRaw != null
      ? CharacterCardMapper.decodeJson<Map<String, dynamic>>(
          characterBookRaw,
          const {},
        )
      : CharacterCardMapper.decodeJson<Map<String, dynamic>>(
          result['character_book'],
          const {},
        );
  body['characterBook'] = book;

  return Response.json(body: body);
}

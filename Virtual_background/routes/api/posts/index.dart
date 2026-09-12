import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/auth_service.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';

/// GET  /api/posts — 社区帖子列表
///      ?community=治愈   按社区分类过滤
///      ?following=1      只看已关注作者（需登录）
/// POST /api/posts — 发布帖子（需登录）
///      body: {title, content, community, tags[], type, characterId?, dialogue?[]}
Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _onGet(context);
    case HttpMethod.post:
      return _onPost(context);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

Future<Response> _onGet(RequestContext context) async {
  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) {
    return Response.json(body: <Map<String, dynamic>>[]);
  }
  final conn = (await db.connection)!;

  final uri = context.request.uri;
  final community = uri.queryParameters['community'];
  final onlyFollowing = uri.queryParameters['following'] == '1';
  final me = AuthService.userIdFromHeaders(context.request.headers);

  final rows = await conn.execute(Sql.named('''
SELECT p.id, p.user_id, p.type, p.title, p.content, p.community, p.tags,
       p.character_id, p.dialogue, p.created_at,
       u.nickname AS author_name, u.avatar_url AS author_avatar,
       (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id)::int AS likes,
       (SELECT COUNT(*) FROM post_comments c WHERE c.post_id = p.id)::int AS comments,
       COALESCE(EXISTS(SELECT 1 FROM post_likes l
                       WHERE l.post_id = p.id AND l.user_id = @me::uuid), false)
         AS liked_by_me
FROM community_posts p JOIN users u ON u.id = p.user_id
WHERE (@community::text IS NULL OR p.community = @community)
  AND (@only_following = false OR p.user_id IN (
        SELECT followee_id FROM follows WHERE follower_id = @me::uuid))
ORDER BY p.created_at DESC
LIMIT 100
'''), parameters: {
    'community': (community == null || community.isEmpty) ? null : community,
    'only_following': onlyFollowing,
    'me': me ?? '00000000-0000-0000-0000-000000000000',
  });

  return Response.json(
    body: rows.map((r) => _postJson(r.toColumnMap())).toList(),
  );
}

/// 关注 / 推荐两种信息流共用同一行结构
Map<String, dynamic> _postJson(Map<String, dynamic> r) => {
      'id': r['id'].toString(),
      'type': r['type'],
      'title': r['title'],
      'content': r['content'],
      'community': r['community'],
      'tags': CharacterCardMapper.decodeJson<List<dynamic>>(
          r['tags'], const []),
      'characterId': r['character_id']?.toString(),
      'dialogue': CharacterCardMapper.decodeJson<List<dynamic>>(
          r['dialogue'], const []),
      'createdAt': (r['created_at'] as DateTime).toIso8601String(),
      'author': {
        'id': r['user_id'].toString(),
        'name': r['author_name'],
        'avatarUrl': r['author_avatar'],
      },
      'likes': r['likes'],
      'likedByMe': r['liked_by_me'],
      'comments': r['comments'],
      'shares': 0,
    };

Future<Response> _onPost(RequestContext context) async {
  final userId = AuthService.userIdFromHeaders(context.request.headers);
  if (userId == null) {
    return Response.json(statusCode: 401, body: {'error': '请先登录后再发布'});
  }

  final Object? body;
  try {
    body = await context.request.json();
  } catch (_) {
    return Response(statusCode: 400, body: 'Bad Request: expected JSON');
  }
  if (body is! Map) return Response(statusCode: 400, body: 'Bad Request');

  final title = body['title']?.toString().trim() ?? '';
  if (title.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': '标题不能为空'});
  }
  final content = body['content']?.toString().trim() ?? '';
  final type = ['text', 'character_card', 'conversation'].contains(
          body['type']?.toString())
      ? body['type'].toString()
      : 'text';
  final community = body['community']?.toString().trim().isEmpty == true
      ? '综合'
      : body['community'].toString();
  final tags = (body['tags'] as List?)?.map((e) => e.toString()).toList() ??
      const <String>[];
  final dialogue = body['dialogue'] is List ? body['dialogue'] : null;

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) {
    return Response.json(statusCode: 503, body: {'error': '数据库不可用'});
  }
  final conn = (await db.connection)!;

  final rows = await conn.execute(Sql.named('''
INSERT INTO community_posts (user_id, type, title, content, community, tags, character_id, dialogue)
VALUES (@u::uuid, @t, @title, @content, @community, @tags::jsonb, @cid, @dialogue::jsonb)
RETURNING id, created_at
'''), parameters: {
    'u': userId,
    't': type,
    'title': title,
    'content': content,
    'community': community,
    'tags': jsonEncode(tags),
    'cid': (body['characterId']?.toString().isEmpty ?? true)
        ? null
        : body['characterId'].toString(),
    'dialogue': dialogue == null ? null : jsonEncode(dialogue),
  });
  final row = rows.first.toColumnMap();

  return Response.json(
    statusCode: 201,
    body: {'id': row['id'].toString(), 'createdAt': (row['created_at'] as DateTime).toIso8601String()},
  );
}

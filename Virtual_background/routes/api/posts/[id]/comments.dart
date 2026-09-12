import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/auth_service.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/path_param.dart';

/// GET  /api/posts/[id]/comments — 评论列表（按时间正序）
///      ?limit=50&offset=0  分页（前端向上滑加载更早评论）
/// POST /api/posts/[id]/comments — 发表评论（需登录，JWT 解析 user_id）
Future<Response> onRequest(RequestContext context, String id) async {
  final postId = decodePathParam(id);
  switch (context.request.method) {
    case HttpMethod.get:
      return _onGet(context, postId);
    case HttpMethod.post:
      return _onPost(context, postId);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

Future<Response> _onGet(RequestContext context, String postId) async {
  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) return Response.json(body: <Map<String, dynamic>>[]);

  final conn = (await db.connection)!;
  final uri = context.request.uri;
  final limit = int.tryParse(uri.queryParameters['limit'] ?? '50') ?? 50;
  final offset = int.tryParse(uri.queryParameters['offset'] ?? '0') ?? 0;

  try {
    final rows = await conn.execute(Sql.named('''
SELECT c.id, c.content, c.created_at, c.user_id,
       u.nickname AS author_name, u.avatar_url AS author_avatar
  FROM post_comments c JOIN users u ON u.id = c.user_id
 WHERE c.post_id = @pid::uuid
 ORDER BY c.created_at ASC
 LIMIT @limit OFFSET @offset
'''), parameters: {
      'pid': postId,
      'limit': limit,
      'offset': offset,
    });
    return Response.json(
      body: rows.map((r) {
        final m = r.toColumnMap();
        return {
          'id': m['id'].toString(),
          'postId': postId,
          'content': m['content'],
          'createdAt': (m['created_at'] as DateTime).toIso8601String(),
          'author': {
            'id': m['user_id'].toString(),
            'name': m['author_name'],
            'avatarUrl': m['author_avatar'],
          },
        };
      }).toList(),
    );
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}

Future<Response> _onPost(RequestContext context, String postId) async {
  final userId = AuthService.userIdFromHeaders(context.request.headers);
  if (userId == null) {
    return Response.json(statusCode: 401, body: {'error': '请先登录后再评论'});
  }

  Object? body;
  try {
    body = await context.request.json();
  } catch (_) {
    return Response(statusCode: 400, body: 'Bad Request: expected JSON');
  }
  if (body is! Map) return Response(statusCode: 400, body: 'Bad Request');

  final content = body['content']?.toString().trim() ?? '';
  if (content.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': '评论内容不能为空'});
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) {
    return Response.json(statusCode: 503, body: {'error': '数据库不可用'});
  }
  final conn = (await db.connection)!;

  // 校验帖子存在
  final exists = await conn.execute(
    Sql.named('SELECT 1 FROM community_posts WHERE id = @pid::uuid'),
    parameters: {'pid': postId},
  );
  if (exists.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': '帖子不存在'});
  }

  final rows = await conn.execute(Sql.named('''
INSERT INTO post_comments (post_id, user_id, content)
VALUES (@pid::uuid, @uid::uuid, @content)
RETURNING id, created_at
'''), parameters: {
      'pid': postId,
      'uid': userId,
      'content': content,
    });

  final row = rows.first.toColumnMap();
  return Response.json(
    statusCode: 201,
    body: {
      'id': row['id'].toString(),
      'postId': postId,
      'content': content,
      'createdAt': (row['created_at'] as DateTime).toIso8601String(),
      'author': {
        'id': userId,
        'name': '',
        'avatarUrl': null,
      },
    },
  );
}

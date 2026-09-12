import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/auth_service.dart';
import 'package:virtual_background/database/db.dart';

/// POST /api/posts/:id/like —— 点赞/取消点赞（切换，需登录）
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
  final userId = AuthService.userIdFromHeaders(context.request.headers);
  if (userId == null) {
    return Response.json(statusCode: 401, body: {'error': '请先登录后再点赞'});
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) {
    return Response.json(statusCode: 503, body: {'error': '数据库不可用'});
  }
  final conn = (await db.connection)!;

  final exists = await conn.execute(
    Sql.named('SELECT 1 FROM post_likes WHERE post_id = @p::uuid AND user_id = @u::uuid'),
    parameters: {'p': id, 'u': userId},
  );
  bool liked;
  if (exists.isNotEmpty) {
    await conn.execute(
      Sql.named('DELETE FROM post_likes WHERE post_id = @p::uuid AND user_id = @u::uuid'),
      parameters: {'p': id, 'u': userId},
    );
    liked = false;
  } else {
    await conn.execute(
      Sql.named('INSERT INTO post_likes (post_id, user_id) VALUES (@p::uuid, @u::uuid)'),
      parameters: {'p': id, 'u': userId},
    );
    liked = true;
  }

  final count = await conn.execute(
    Sql.named('SELECT COUNT(*)::int AS c FROM post_likes WHERE post_id = @p::uuid'),
    parameters: {'p': id},
  );
  return Response.json(body: {
    'liked': liked,
    'likes': count.first.toColumnMap()['c'],
  });
}

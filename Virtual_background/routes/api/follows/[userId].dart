import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/auth_service.dart';
import 'package:virtual_background/database/db.dart';

/// GET  /api/follows —— 我的关注列表（发现页关注栏）
/// POST /api/follows/:userId —— 关注 / 取关（切换，需登录）
Future<Response> onRequest(RequestContext context, [String? userId]) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _onGet(context);
    case HttpMethod.post:
      if (userId == null || userId.isEmpty) {
        return Response(statusCode: 400, body: 'Bad Request: missing user id');
      }
      return _onToggle(context, userId);
    default:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

Future<Response> _onGet(RequestContext context) async {
  final me = AuthService.userIdFromHeaders(context.request.headers);
  if (me == null) return Response.json(body: <Map<String, dynamic>>[]);

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) return Response.json(body: <Map<String, dynamic>>[]);
  final conn = (await db.connection)!;

  final rows = await conn.execute(Sql.named('''
SELECT u.id, u.nickname, u.avatar_url
FROM follows f JOIN users u ON u.id = f.followee_id
WHERE f.follower_id = @me::uuid
ORDER BY f.created_at DESC
'''), parameters: {'me': me});

  return Response.json(
    body: rows.map((r) {
      final m = r.toColumnMap();
      return {
        'id': m['id'].toString(),
        'name': m['nickname'],
        'avatarUrl': m['avatar_url'],
      };
    }).toList(),
  );
}

Future<Response> _onToggle(RequestContext context, String targetUserId) async {
  final me = AuthService.userIdFromHeaders(context.request.headers);
  if (me == null) {
    return Response.json(statusCode: 401, body: {'error': '请先登录'});
  }
  if (me == targetUserId) {
    return Response.json(statusCode: 400, body: {'error': '不能关注自己'});
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) {
    return Response.json(statusCode: 503, body: {'error': '数据库不可用'});
  }
  final conn = (await db.connection)!;

  final exists = await conn.execute(
    Sql.named(
        'SELECT 1 FROM follows WHERE follower_id = @me::uuid AND followee_id = @t::uuid'),
    parameters: {'me': me, 't': targetUserId},
  );
  bool following;
  if (exists.isNotEmpty) {
    await conn.execute(
      Sql.named(
          'DELETE FROM follows WHERE follower_id = @me::uuid AND followee_id = @t::uuid'),
      parameters: {'me': me, 't': targetUserId},
    );
    following = false;
  } else {
    await conn.execute(
      Sql.named(
          'INSERT INTO follows (follower_id, followee_id) VALUES (@me::uuid, @t::uuid)'),
      parameters: {'me': me, 't': targetUserId},
    );
    following = true;
  }
  return Response.json(body: {'following': following});
}

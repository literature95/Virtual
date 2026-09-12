import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/auth_service.dart';
import 'package:virtual_background/database/db.dart';

/// GET /api/follows —— 我的关注列表（见 [userId].dart 同文件的 GET 实现）
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
  final me = AuthService.userIdFromHeaders(context.request.headers);
  if (me == null) return Response.json(body: <Map<String, dynamic>>[]);

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) return Response.json(body: <Map<String, dynamic>>[]);
  final conn = (await db.connection)!;

  final rows = await conn.execute(
    Sql.named('''
SELECT u.id, u.nickname, u.avatar_url
FROM follows f JOIN users u ON u.id = f.followee_id
WHERE f.follower_id = @me::uuid
ORDER BY f.created_at DESC
'''),
    parameters: {'me': me},
  );

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

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/auth_service.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/path_param.dart';

/// GET /api/users/[id] — 用户主页（点击头像进入）
///
/// 返回：用户信息（nickname / avatar_url）、统计（postCount / followerCount /
/// followingCount）、isFollowing（当前登录用户是否关注 TA）、以及该用户的
/// 帖子列表（动态流，字段与 /api/posts 一致，便于前端复用卡片）。
/// 与账号体系通过 JWT 联动：未登录时 isFollowing = false，帖子列表不含 likedByMe。
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final userId = decodePathParam(id);
  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) {
    return Response.json(statusCode: 503, body: {'error': '数据库不可用'});
  }
  final conn = (await db.connection)!;
  final me = AuthService.userIdFromHeaders(context.request.headers);

  try {
    final uRows = await conn.execute(
      Sql.named(
          'SELECT id, nickname, avatar_url, bio FROM users WHERE id = @uid::uuid'),
      parameters: {'uid': userId},
    );
    if (uRows.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': '用户不存在'});
    }
    final u = uRows.first.toColumnMap();

    final counts = await conn.execute(Sql.named('''
SELECT
  (SELECT COUNT(*) FROM community_posts p WHERE p.user_id = @uid::uuid)::int AS post_count,
  (SELECT COUNT(*) FROM follows f WHERE f.followee_id = @uid::uuid)::int AS follower_count,
  (SELECT COUNT(*) FROM follows f WHERE f.follower_id = @uid::uuid)::int AS following_count
'''), parameters: {'uid': userId});
    final c = counts.first.toColumnMap();

    final isFollowing = me != null &&
        (await conn.execute(
              Sql.named('''
SELECT 1 FROM follows
 WHERE follower_id = @me::uuid AND followee_id = @uid::uuid
'''),
              parameters: {'me': me, 'uid': userId},
            ))
            .isNotEmpty;

    final pRows = await conn.execute(Sql.named('''
SELECT p.id, p.user_id, p.type, p.title, p.content, p.community, p.tags,
       p.character_id, p.dialogue, p.created_at,
       (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id)::int AS likes,
       (SELECT COUNT(*) FROM post_comments cc WHERE cc.post_id = p.id)::int AS comments,
       COALESCE(EXISTS(SELECT 1 FROM post_likes l
                       WHERE l.post_id = p.id AND l.user_id = @me::uuid), false)
         AS liked_by_me
  FROM community_posts p
 WHERE p.user_id = @uid::uuid
 ORDER BY p.created_at DESC
 LIMIT 50
'''), parameters: {
      'uid': userId,
      'me': me ?? '00000000-0000-0000-0000-000000000000',
    });

    final posts = pRows.map((r) {
      final m = r.toColumnMap();
      return {
        'id': m['id'].toString(),
        'type': m['type'],
        'title': m['title'],
        'content': m['content'],
        'community': m['community'],
        'tags': CharacterCardMapper.decodeJson<List<dynamic>>(m['tags'], const []),
        'characterId': m['character_id']?.toString(),
        'dialogue': CharacterCardMapper.decodeJson<List<dynamic>>(m['dialogue'], const []),
        'createdAt': (m['created_at'] as DateTime).toIso8601String(),
        'author': {
          'id': m['user_id'].toString(),
          'name': u['nickname'],
          'avatarUrl': u['avatar_url'],
        },
        'likes': m['likes'],
        'likedByMe': m['liked_by_me'],
        'comments': m['comments'],
        'shares': 0,
      };
    }).toList();

    final body = {
      'id': u['id'].toString(),
      'name': u['nickname'],
      'nickname': u['nickname'],
      'avatarUrl': u['avatar_url'],
      'bio': u['bio'],
      'postCount': c['post_count'],
      'followerCount': c['follower_count'],
      'followingCount': c['following_count'],
      'isFollowing': isFollowing,
      'posts': posts,
    };
    return Response.json(body: body);
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}

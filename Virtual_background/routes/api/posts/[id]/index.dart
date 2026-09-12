import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/auth_service.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/path_param.dart';

/// GET /api/posts/[id] — 单帖详情（动态详情页用）
///
/// 返回完整字段：author（JOIN users）、likes / likedByMe（联表聚合）、
/// comments 计数（联表聚合）、isFollowingAuthor（当前用户是否关注作者）。
/// 评论列表由 /api/posts/[id]/comments 单独提供，避免详情包体过大。
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final postId = decodePathParam(id);
  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();
  if (!db.isAvailable) {
    return Response.json(statusCode: 503, body: {'error': '数据库不可用'});
  }
  final conn = (await db.connection)!;
  final me = AuthService.userIdFromHeaders(context.request.headers);

  try {
    final rows = await conn.execute(Sql.named('''
SELECT p.id, p.user_id, p.type, p.title, p.content, p.community, p.tags,
       p.character_id, p.dialogue, p.created_at,
       u.nickname AS author_name, u.avatar_url AS author_avatar,
       (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id)::int AS likes,
       (SELECT COUNT(*) FROM post_comments c WHERE c.post_id = p.id)::int AS comments,
       COALESCE(EXISTS(SELECT 1 FROM post_likes l
                       WHERE l.post_id = p.id AND l.user_id = @me::uuid), false)
         AS liked_by_me,
       COALESCE(EXISTS(SELECT 1 FROM follows f
                       WHERE f.followee_id = p.user_id
                         AND f.follower_id = @me::uuid), false)
         AS is_following_author
  FROM community_posts p JOIN users u ON u.id = p.user_id
 WHERE p.id = @pid::uuid
'''), parameters: {
      'pid': postId,
      'me': me ?? '00000000-0000-0000-0000-000000000000',
    });

    if (rows.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': '帖子不存在'});
    }

    final r = rows.first.toColumnMap();
    final body = {
      'id': r['id'].toString(),
      'type': r['type'],
      'title': r['title'],
      'content': r['content'],
      'community': r['community'],
      'tags': CharacterCardMapper.decodeJson<List<dynamic>>(r['tags'], const []),
      'characterId': r['character_id']?.toString(),
      'dialogue': CharacterCardMapper.decodeJson<List<dynamic>>(r['dialogue'], const []),
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
      'isFollowingAuthor': r['is_following_author'],
    };
    return Response.json(body: body);
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}

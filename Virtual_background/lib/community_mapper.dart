import 'package:virtual_background/character_card_mapper.dart';

/// 社区帖子：数据库行 → 对外 JSON 的**唯一**映射入口。
///
/// 三个端点共用同一种帖子形状：
///   - `GET /api/posts`        帖子列表（routes/api/posts/index.dart）
///   - `GET /api/posts/[id]`   帖子详情（`routes/api/posts/[id]/index.dart`，多 `isFollowingAuthor`）
///   - `GET /api/users/[id]`   用户主页的帖子列表（`routes/api/users/[id]/index.dart`）
///
/// 之所以抽到这里而不是各路由内联，是因为三处各写一份曾导致**字段漂移**：
/// 历史上「列表页评论数恒为 0」就是某一处漏了聚合列，而这类错误**不会抛异常**，
/// 只表现为界面上一个数字不对，极难发现。集中一处 + 单元测试可杜绝复发。
///
/// 返回**超集**（含 `isFollowingAuthor`）—— App 的 `CommunityPost.fromJson`
/// 忽略多余字段，因此三个端点可安全共用同一份输出。
Map<String, dynamic> postJsonFromRow(
  Map<String, dynamic> r, {
  /// 作者显示名。用户主页场景下作者即主页主人，行里没有 JOIN 出的作者列，
  /// 由调用方从用户行显式传入；不传则取行内的 `author_name`。
  String? authorName,

  /// 作者头像 URL，语义同 `authorName`。
  String? authorAvatar,

  /// 当前用户是否关注了作者。仅详情接口的 SQL 会产出该列；
  /// 列表与主页场景缺省为 false。
  bool? isFollowingAuthor,
}) {
  return {
    'id': r['id'].toString(),
    'type': r['type'],
    'title': r['title'],
    'content': r['content'],
    'community': r['community'],
    'tags': CharacterCardMapper.decodeJson<List<dynamic>>(r['tags'], const []),
    'characterId': r['character_id']?.toString(),
    'dialogue':
        CharacterCardMapper.decodeJson<List<dynamic>>(r['dialogue'], const []),
    'createdAt': (r['created_at'] as DateTime).toIso8601String(),
    'author': {
      'id': r['user_id'].toString(),
      'name': authorName ?? r['author_name'],
      'avatarUrl': authorAvatar ?? r['author_avatar'],
    },
    'likes': r['likes'],
    'likedByMe': r['liked_by_me'],
    'comments': r['comments'],
    'shares': 0,
    'isFollowingAuthor':
        isFollowingAuthor ?? r['is_following_author'] ?? false,
  };
}

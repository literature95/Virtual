import 'package:dio/dio.dart';

import '../models/community_post.dart';

/// 社区（发现页）API 客户端：封装 Virtual_background /api/posts、/api/follows
///
/// 数据全部落在后端 PostgreSQL（community_posts / post_likes / follows / users），
/// 与登录账号通过 JWT Bearer token 联动。本服务不缓存任何帖子，纯透传后端返回。
class CommunityException implements Exception {
  final String message;
  CommunityException(this.message);
  @override
  String toString() => message;
}

class CommunityApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Options? _auth(String? token) =>
      token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null;

  CommunityException _wrap(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return CommunityException(data['error'].toString());
    }
    if (e.response?.statusCode == 401) {
      return CommunityException('请先登录');
    }
    return CommunityException('无法连接后端，请检查网络与后端地址');
  }

  /// 帖子列表。
  /// [community] 按社区过滤（'综合' 或不传 = 全部）；
  /// [following] = true 时只看已关注作者（需登录，未登录返回空）。
  Future<List<CommunityPost>> getPosts(
    String backend, {
    String? community,
    bool following = false,
    String? token,
  }) async {
    final q = <String, dynamic>{};
    if (following) q['following'] = '1';
    if (community != null && community.isNotEmpty && community != '综合') {
      q['community'] = community;
    }
    try {
      final r = await _dio.get(
        '$backend/api/posts',
        queryParameters: q,
        options: _auth(token),
      );
      final list = (r.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      return list.map(CommunityPost.fromJson).toList();
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// 发布帖子（需登录）。返回新建帖子。
  Future<CommunityPost> createPost(
    String backend,
    String token, {
    required String title,
    String content = '',
    String community = '综合',
    List<String> tags = const [],
    String type = 'text',
    String? characterId,
    List<Map<String, dynamic>>? dialogue,
  }) async {
    try {
      final r = await _dio.post(
        '$backend/api/posts',
        data: {
          'title': title,
          'content': content,
          'community': community,
          'tags': tags,
          'type': type,
          if (characterId != null && characterId.isNotEmpty)
            'characterId': characterId,
          if (dialogue != null) 'dialogue': dialogue,
        },
        options: _auth(token),
      );
      // 接口只回 {id, createdAt}，补全为完整帖子（含当前作者）
      final id = (r.data['id'] ?? '').toString();
      final createdAt = r.data['createdAt']?.toString();
      return CommunityPost(
        id: id,
        type: PostTypeX.fromApi(type),
        author: Creator(id: '', name: '我'),
        title: title,
        content: content,
        tags: tags,
        community: community,
        timeAgo: timeAgoFrom(DateTime.tryParse(createdAt ?? '')),
      );
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// 点赞 / 取消点赞（切换，需登录）。返回最新状态。
  Future<({bool liked, int likes})> toggleLike(
    String backend,
    String token,
    String postId,
  ) async {
    try {
      final r = await _dio.post(
        '$backend/api/posts/$postId/like',
        options: _auth(token),
      );
      final data = (r.data as Map).cast<String, dynamic>();
      return (
        liked: data['liked'] as bool? ?? false,
        likes: (data['likes'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// 我的关注列表（创作者）。未登录返回空。
  Future<List<Creator>> getFollowing(String backend, String? token) async {
    if (token == null) return const [];
    try {
      final r = await _dio.get(
        '$backend/api/follows',
        options: _auth(token),
      );
      final list = (r.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      return list.map(Creator.fromJson).toList();
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// 关注 / 取关（切换，需登录）。返回最新关注状态。
  Future<bool> toggleFollow(
    String backend,
    String token,
    String userId,
  ) async {
    try {
      final r = await _dio.post(
        '$backend/api/follows/$userId',
        options: _auth(token),
      );
      final data = (r.data as Map).cast<String, dynamic>();
      return data['following'] as bool? ?? false;
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// 单帖详情（动态详情页）。含 author / likes / likedByMe / comments 计数 /
  /// isFollowingAuthor。
  Future<CommunityPost> getPostDetail(
    String backend,
    String postId, {
    String? token,
  }) async {
    try {
      final r = await _dio.get(
        '$backend/api/posts/$postId',
        options: _auth(token),
      );
      return CommunityPost.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// 评论列表（动态详情页）。支持分页：offset 越大越早。
  Future<List<Comment>> getComments(
    String backend,
    String postId, {
    String? token,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final r = await _dio.get(
        '$backend/api/posts/$postId/comments',
        queryParameters: {'limit': limit, 'offset': offset},
        options: _auth(token),
      );
      final list = (r.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      return list.map(Comment.fromJson).toList();
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// 发表评论（需登录）。
  Future<Comment> addComment(
    String backend,
    String token,
    String postId,
    String content,
  ) async {
    try {
      final r = await _dio.post(
        '$backend/api/posts/$postId/comments',
        data: {'content': content},
        options: _auth(token),
      );
      return Comment.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// 用户主页（点击头像进入）。含统计与 TA 的帖子列表。
  Future<UserProfile> getUserProfile(
    String backend,
    String userId, {
    String? token,
  }) async {
    try {
      final r = await _dio.get(
        '$backend/api/users/$userId',
        options: _auth(token),
      );
      return UserProfile.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }
}

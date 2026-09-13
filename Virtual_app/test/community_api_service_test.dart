import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/models/community_post.dart';
import 'package:virtual/services/community_api_service.dart';

/// 可编程 Dio adapter：记录最后一次请求，并回放预设响应。
///
/// 与 `character_import_service_test.dart` 的 `_FakeAdapter` 同思路，
/// 但额外支持任意状态码与「模拟网络异常」，以便覆盖错误包装分支。
class _Rec implements HttpClientAdapter {
  _Rec({this.status = 200, this.body, this.connectionError = false});

  final int status;
  final Object? body;

  /// true 时直接抛 DioException（无 response），模拟断网
  final bool connectionError;

  /// 最后一次请求（用于断言 URL / 查询参数 / 请求头 / body）
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (connectionError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final s = body == null
        ? ''
        : (body is String ? body as String : jsonEncode(body));
    return ResponseBody.fromString(
      s,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

CommunityApiService _svc(_Rec rec) {
  final dio = Dio();
  dio.httpClientAdapter = rec;
  return CommunityApiService(dio);
}

const _backend = 'http://localhost:8080';

void main() {
  // ───────────────────────── 模型解析 ─────────────────────────

  group('CommunityPost.fromJson', () {
    test('详情接口全字段解析（含 isFollowingAuthor / likedByMe / 计数）', () {
      final p = CommunityPost.fromJson({
        'id': 'post-1',
        'type': 'character_card',
        'title': '我的新角色',
        'content': '快来看看',
        'community': '奇幻',
        'tags': ['Fantasy', 'OC'],
        'likes': 12,
        'comments': 3,
        'likedByMe': true,
        'isFollowingAuthor': true,
        'characterId': '希露妲',
        'createdAt': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toIso8601String(),
        'author': {'id': 'u-1', 'name': '作者', 'avatarUrl': '/a.png'},
      });

      expect(p.id, 'post-1');
      expect(p.type, PostType.characterCard);
      expect(p.title, '我的新角色');
      expect(p.community, '奇幻');
      expect(p.tags, ['Fantasy', 'OC']);
      expect(p.likes, 12);
      expect(p.comments, 3);
      // 这两个字段决定「点赞/关注按钮」的初始态，错一个按钮就反着亮
      expect(p.likedByMe, isTrue);
      expect(p.isFollowingAuthor, isTrue);
      expect(p.characterId, '希露妲');
      expect(p.author.name, '作者');
      expect(p.timeAgo, '5分钟前');
    });

    test('列表接口不含 isFollowingAuthor 时安全回落 false', () {
      final p = CommunityPost.fromJson({
        'id': 'post-2',
        'title': 'x',
        'author': {'id': 'u', 'name': 'n'},
      });
      expect(p.isFollowingAuthor, isFalse);
      expect(p.likedByMe, isFalse);
      expect(p.community, '综合');
      expect(p.tags, isEmpty);
      expect(p.dialogue, isNull);
    });

    test('字段缺失/为 null 不抛异常，全部走默认值', () {
      final p = CommunityPost.fromJson({'id': 'post-3'});
      expect(p.id, 'post-3');
      expect(p.title, '');
      expect(p.content, '');
      expect(p.likes, 0);
      expect(p.comments, 0);
      expect(p.likes, 0);
      expect(p.timeAgo, '');
      expect(p.author.name, '匿名用户');
    });

    test('dialogue 数组解析为 DialogueLine', () {
      final p = CommunityPost.fromJson({
        'id': 'p',
        'title': 't',
        'author': {'id': 'u', 'name': 'n'},
        'dialogue': [
          {'isCharacter': true, 'name': '希露妲', 'text': '你好'},
          {'isCharacter': false, 'name': '我', 'text': '在吗'},
        ],
      });
      expect(p.dialogue, hasLength(2));
      expect(p.dialogue!.first.isCharacter, isTrue);
      expect(p.dialogue!.first.text, '你好');
      expect(p.dialogue![1].isCharacter, isFalse);
    });

    test('copyWith 保留未指定字段（乐观更新不丢数据）', () {
      final p = CommunityPost.fromJson({
        'id': 'p',
        'title': '原标题',
        'content': '原正文',
        'community': '治愈',
        'likes': 1,
        'comments': 2,
        'author': {'id': 'u', 'name': 'n'},
      });
      final liked = p.copyWithLiked(true, 2);
      expect(liked.likedByMe, isTrue);
      expect(liked.likes, 2);
      expect(liked.title, '原标题');
      expect(liked.community, '治愈');

      final commented = p.copyWith(comments: 9);
      expect(commented.comments, 9);
      expect(commented.likes, 1);
      expect(commented.likedByMe, isFalse);
    });
  });

  group('PostTypeX.fromApi', () {
    test('后端取值映射正确', () {
      expect(PostTypeX.fromApi('text'), PostType.text);
      expect(PostTypeX.fromApi('character_card'), PostType.characterCard);
      expect(PostTypeX.fromApi('conversation'), PostType.conversationShowcase);
      expect(PostTypeX.fromApi('announcement'), PostType.announcement);
    });

    test('未知 / null / 大小写不符 → 回落 text，不抛异常', () {
      expect(PostTypeX.fromApi('unknown'), PostType.text);
      expect(PostTypeX.fromApi(null), PostType.text);
      expect(PostTypeX.fromApi('TEXT'), PostType.text);
    });
  });

  group('Comment.fromJson', () {
    test('嵌套 author 与 createdAt 解析', () {
      final c = Comment.fromJson({
        'id': 'c-1',
        'postId': 'p-1',
        'content': '说得好',
        'createdAt': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'author': {'id': 'u-2', 'name': '路人', 'avatarUrl': null},
      });
      expect(c.id, 'c-1');
      expect(c.postId, 'p-1');
      expect(c.content, '说得好');
      expect(c.author.name, '路人');
      expect(c.timeAgo, '2小时前');
    });

    test('缺 author / createdAt 时回落且 timeAgo 为空', () {
      final c = Comment.fromJson({'id': 'c', 'postId': 'p', 'content': 'x'});
      expect(c.author.name, '匿名用户');
      expect(c.createdAt, isNull);
      expect(c.timeAgo, '');
    });
  });

  group('UserProfile.fromJson', () {
    test('统计字段与内嵌 posts 解析', () {
      final u = UserProfile.fromJson({
        'id': 'u-1',
        'name': '某人',
        'bio': '简介',
        'postCount': 7,
        'followerCount': 30,
        'followingCount': 12,
        'isFollowing': true,
        'posts': [
          {'id': 'p1', 'title': 'a', 'author': {'id': 'u-1', 'name': '某人'}},
          {'id': 'p2', 'title': 'b', 'author': {'id': 'u-1', 'name': '某人'}},
        ],
      });
      expect(u.name, '某人');
      expect(u.bio, '简介');
      expect(u.postCount, 7);
      expect(u.followerCount, 30);
      expect(u.followingCount, 12);
      expect(u.isFollowing, isTrue);
      expect(u.posts, hasLength(2));
      expect(u.posts.first.title, 'a');
    });

    test('posts 缺失 → 空列表，非 null', () {
      final u = UserProfile.fromJson({'id': 'u', 'name': 'n'});
      expect(u.posts, isEmpty);
      expect(u.isFollowing, isFalse);
    });
  });

  // ───────────────────────── 请求构造 ─────────────────────────

  group('CommunityApiService 请求构造', () {
    test('getPosts：community=综合 时不传该参数（等价全部）', () async {
      final rec = _Rec(body: []);
      await _svc(rec).getPosts(_backend, community: '综合');

      expect(rec.last!.uri.path, '/api/posts');
      expect(rec.last!.uri.queryParameters.containsKey('community'), isFalse);
      expect(rec.last!.uri.queryParameters.containsKey('following'), isFalse);
    });

    test('getPosts：非综合分类才带上 community 过滤', () async {
      final rec = _Rec(body: []);
      await _svc(rec).getPosts(_backend, community: '治愈');

      expect(rec.last!.uri.queryParameters['community'], '治愈');
    });

    test('getPosts：following=true 传 following=1，并携带 Bearer 头', () async {
      final rec = _Rec(body: []);
      await _svc(rec).getPosts(_backend, following: true, token: 'tok-123');

      expect(rec.last!.uri.queryParameters['following'], '1');
      expect(rec.last!.headers['Authorization'], 'Bearer tok-123');
    });

    test('getPosts：无 token 时不带 Authorization 头', () async {
      final rec = _Rec(body: []);
      await _svc(rec).getPosts(_backend);
      expect(rec.last!.headers.containsKey('Authorization'), isFalse);
    });

    test('getPosts：解析数组为 CommunityPost 列表', () async {
      final rec = _Rec(body: [
        {'id': 'p1', 'title': 'A', 'author': {'id': 'u', 'name': 'n'}},
        {'id': 'p2', 'title': 'B', 'author': {'id': 'u', 'name': 'n'}},
      ]);
      final posts = await _svc(rec).getPosts(_backend);

      expect(posts, hasLength(2));
      expect(posts.first.title, 'A');
      expect(posts[1].title, 'B');
    });

    test('getPostDetail：URL 正确且 isFollowingAuthor 被解析', () async {
      final rec = _Rec(body: {
        'id': 'p-9',
        'title': 'T',
        'isFollowingAuthor': true,
        'author': {'id': 'u', 'name': 'n'},
      });
      final p = await _svc(rec).getPostDetail(_backend, 'p-9');

      expect(rec.last!.uri.path, '/api/posts/p-9');
      expect(p.id, 'p-9');
      expect(p.isFollowingAuthor, isTrue);
    });

    test('getComments：limit/offset 正确透传（上滑加载更早）', () async {
      final rec = _Rec(body: []);
      await _svc(rec).getComments(_backend, 'p-1', limit: 20, offset: 40);

      expect(rec.last!.uri.path, '/api/posts/p-1/comments');
      expect(rec.last!.uri.queryParameters['limit'], '20');
      expect(rec.last!.uri.queryParameters['offset'], '40');
    });

    test('addComment：POST 到评论端点并发送 {content}', () async {
      final rec = _Rec(status: 201, body: {
        'id': 'c-1',
        'postId': 'p-1',
        'content': '你好',
        'author': {'id': 'u', 'name': '我'},
      });
      final c = await _svc(rec).addComment(_backend, 'tok', 'p-1', '你好');

      expect(rec.last!.method, 'POST');
      expect(rec.last!.uri.path, '/api/posts/p-1/comments');
      expect((rec.last!.data as Map)['content'], '你好');
      expect(c.content, '你好');
    });

    test('toggleLike：解析 {liked, likes}', () async {
      final rec = _Rec(body: {'liked': true, 'likes': 42});
      final r = await _svc(rec).toggleLike(_backend, 'tok', 'p-1');

      expect(rec.last!.method, 'POST');
      expect(rec.last!.uri.path, '/api/posts/p-1/like');
      expect(r.liked, isTrue);
      expect(r.likes, 42);
    });

    test('toggleFollow：解析 {following}', () async {
      final rec = _Rec(body: {'following': true});
      final following = await _svc(rec).toggleFollow(_backend, 'tok', 'u-2');

      expect(rec.last!.uri.path, '/api/follows/u-2');
      expect(following, isTrue);
    });

    test('getFollowing：token 为 null 时不发请求直接返回空', () async {
      final rec = _Rec(body: []);
      final list = await _svc(rec).getFollowing(_backend, null);

      expect(list, isEmpty);
      expect(rec.last, isNull); // 证明没有发起网络请求
    });

    test('getUserProfile：URL 用 userId 且统计解析正确', () async {
      final rec = _Rec(body: {
        'id': 'u-5',
        'name': '张三',
        'postCount': 3,
        'followerCount': 8,
        'followingCount': 1,
        'isFollowing': false,
        'posts': [],
      });
      final u = await _svc(rec).getUserProfile(_backend, 'u-5');

      expect(rec.last!.uri.path, '/api/users/u-5');
      expect(u.name, '张三');
      expect(u.postCount, 3);
      expect(u.followerCount, 8);
      expect(u.isFollowing, isFalse);
    });
  });

  // ───────────────────────── 错误包装 ─────────────────────────

  group('CommunityApiService 错误包装', () {
    test('401 且无 error 字段 → 「请先登录」', () async {
      final rec = _Rec(status: 401, body: {'detail': 'unauthorized'});
      expect(
        () => _svc(rec).getPosts(_backend),
        throwsA(isA<CommunityException>()
            .having((e) => e.message, 'message', '请先登录')),
      );
    });

    test('后端 {error: ...} → 原样透传后端文案', () async {
      final rec = _Rec(status: 404, body: {'error': '帖子不存在'});
      expect(
        () => _svc(rec).getPostDetail(_backend, 'nope'),
        throwsA(isA<CommunityException>()
            .having((e) => e.message, 'message', '帖子不存在')),
      );
    });

    test('网络异常（无 response）→ 网络提示', () async {
      final rec = _Rec(connectionError: true);
      expect(
        () => _svc(rec).getPosts(_backend),
        throwsA(isA<CommunityException>().having(
          (e) => e.message,
          'message',
          contains('无法连接后端'),
        )),
      );
    });

    test('CommunityException.toString 即 message（UI 可直接展示）', () {
      expect(CommunityException('出错了').toString(), '出错了');
    });
  });
}

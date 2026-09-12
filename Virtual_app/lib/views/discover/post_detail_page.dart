import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/community_api_service.dart';
import '../../theme/tavo_brand.dart';

/// 动态详情页（点击帖子 / 评论进入，数据来自 /api/posts/[id] + /api/posts/[id]/comments）
///
/// 顶部：帖子详情（作者头像点主页、角色卡点角色卡主页、点赞、关注作者）；
/// 中部：评论列表（向上滑加载更多，分页）、评论输入框（登录后发表，乐观插入）。
/// 全部走真实后端 PostgreSQL，与登录账号通过 JWT 联动。
class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final CommunityApiService _api = CommunityApiService();
  CommunityPost? _post;
  List<Comment> _comments = [];
  bool _loading = true;
  bool _loadingComments = false;
  bool _hasMore = true;
  int _commentOffset = 0;
  String? _error;
  final _commentC = TextEditingController();
  final _scrollC = ScrollController();

  late AuthProvider _auth;
  late SettingsProvider _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    _auth = context.read<AuthProvider>();
    _auth.addListener(_onAuth);
    _scrollC.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _scrollC.dispose();
    _commentC.dispose();
    super.dispose();
  }

  void _onAuth() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _api.getPostDetail(
        _settings.backendBaseUrl,
        widget.postId,
        token: _auth.token,
      );
      final cs = await _api.getComments(
        _settings.backendBaseUrl,
        widget.postId,
        token: _auth.token,
      );
      if (!mounted) return;
      setState(() {
        _post = p;
        _comments = cs;
        _commentOffset = cs.length;
        _hasMore = cs.length >= 50;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// 向下滑到底部加载更早的评论（分页 offset 递增）
  Future<void> _loadMoreComments() async {
    if (_loadingComments || !_hasMore || !mounted) return;
    setState(() => _loadingComments = true);
    try {
      final cs = await _api.getComments(
        _settings.backendBaseUrl,
        widget.postId,
        token: _auth.token,
        offset: _commentOffset,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, ...cs];
        _commentOffset += cs.length;
        _hasMore = cs.length >= 50;
        _loadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
      _snack(e.toString());
    }
  }

  void _onScroll() {
    if (_scrollC.position.pixels >= _scrollC.position.maxScrollExtent - 300) {
      _loadMoreComments();
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _onToggleLike() async {
    final token = _auth.token;
    if (token == null) {
      _snack('请先登录后再操作');
      if (mounted) context.go('/login');
      return;
    }
    if (_post == null) return;
    final desired = !_post!.likedByMe;
    final optimistic = _post!.likes + (desired ? 1 : -1);
    setState(() => _post = _post!.copyWith(likedByMe: desired, likes: optimistic));
    try {
      final res = await _api.toggleLike(
        _settings.backendBaseUrl,
        token,
        widget.postId,
      );
      setState(() => _post = _post!.copyWith(likedByMe: res.liked, likes: res.likes));
    } catch (e) {
      setState(() =>
          _post = _post!.copyWith(likedByMe: !desired, likes: _post!.likes));
      _snack(e.toString());
    }
  }

  Future<void> _toggleFollowAuthor() async {
    final token = _auth.token;
    if (token == null) {
      _snack('请先登录后再关注');
      if (mounted) context.go('/login');
      return;
    }
    if (_post == null) return;
    final prev = _post!.isFollowingAuthor;
    setState(() => _post = _post!.copyWith(isFollowingAuthor: !prev));
    try {
      await _api.toggleFollow(
        _settings.backendBaseUrl,
        token,
        _post!.author.id,
      );
    } catch (e) {
      setState(() => _post = _post!.copyWith(isFollowingAuthor: prev));
      _snack(e.toString());
    }
  }

  Future<void> _submitComment() async {
    final token = _auth.token;
    if (token == null) {
      _snack('请先登录后再评论');
      if (mounted) context.go('/login');
      return;
    }
    final text = _commentC.text.trim();
    if (text.isEmpty) return;
    _commentC.clear();
    final me = _auth.user;
    final optimistic = Comment(
      id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      postId: widget.postId,
      author: Creator(id: me?.id ?? '', name: me?.nickname ?? '我'),
      content: text,
      createdAt: DateTime.now(),
    );
    // 乐观插入 + 评论数 +1
    setState(() {
      _comments = [..._comments, optimistic];
      _post = _post!.copyWith(comments: _post!.comments + 1);
    });
    try {
      final c = await _api.addComment(
        _settings.backendBaseUrl,
        token,
        widget.postId,
        text,
      );
      if (!mounted) return;
      setState(() {
        _comments = _comments.map((e) => e.id == optimistic.id ? c : e).toList();
      });
    } catch (e) {
      // 回滚
      setState(() {
        _comments = _comments.where((x) => x.id != optimistic.id).toList();
        _post = _post!.copyWith(comments: _post!.comments - 1);
      });
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('动态详情'),
        backgroundColor: scheme.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('加载失败：$_error',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _post == null
                  ? const Center(child: Text('帖子不存在'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            controller: _scrollC,
                            padding: const EdgeInsets.all(16),
                            children: [
                              _PostDetailCard(
                                post: _post!,
                                onLike: _onToggleLike,
                                onFollowAuthor: _toggleFollowAuthor,
                                onOpenAuthor: () =>
                                    context.push('/user/${_post!.author.id}'),
                                onOpenCharacter: _post!.characterId != null
                                    ? () => context.push(
                                        '/home/character/${_post!.characterId}')
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text('评论 ${_comments.length}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface)),
                              ),
                              ..._comments
                                  .map((c) => _CommentTile(comment: c)),
                              if (_loadingComments)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              if (!_hasMore && _comments.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text('没有更多评论了',
                                        style: TextStyle(
                                            color: scheme.onSurfaceVariant)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _CommentInput(
                          controller: _commentC,
                          onSubmit: _submitComment,
                        ),
                      ],
                    ),
    );
  }
}

/// 帖子详情卡片
class _PostDetailCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onFollowAuthor;
  final VoidCallback onOpenAuthor;
  final VoidCallback? onOpenCharacter;

  const _PostDetailCard({
    required this.post,
    required this.onLike,
    required this.onFollowAuthor,
    required this.onOpenAuthor,
    this.onOpenCharacter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者行（点头像进主页）
          GestureDetector(
            onTap: onOpenAuthor,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.surfaceContainerHighest,
                  backgroundImage: post.author.avatarUrl != null
                      ? NetworkImage(post.author.avatarUrl!)
                      : null,
                  child: post.author.avatarUrl == null
                      ? Text(
                          post.author.name.isNotEmpty
                              ? post.author.name[0]
                              : '?',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author.name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface)),
                      Text(post.timeAgo,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: onFollowAuthor,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(post.isFollowingAuthor ? '已关注' : '关注'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (post.community != '综合') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('#${post.community}',
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
          ],
          Text(post.title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface)),
          const SizedBox(height: 8),
          if (post.content.isNotEmpty)
            Text(post.content,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant)),
          // 角色卡入口
          if (post.characterId != null && onOpenCharacter != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onOpenCharacter,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: TavoColors.signGradientDiagonal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('查看角色卡：${post.characterId}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ],
          // 对话炫耀
          if (post.dialogue != null && post.dialogue!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: post.dialogue!
                    .map((l) => _DetailDialogueLine(line: l))
                    .toList(),
              ),
            ),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('#$t',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onLike,
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded,
                        size: 20,
                        color: post.likedByMe
                            ? TavoColors.coral
                            : scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('${post.likes}',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('${post.comments}',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailDialogueLine extends StatelessWidget {
  final DialogueLine line;
  const _DetailDialogueLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isChar = line.isCharacter;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isChar) ...[
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: const BoxDecoration(
                gradient: TavoColors.signGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                line.name.isNotEmpty ? line.name[0] : '?',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isChar ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(line.name,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isChar
                        ? scheme.surfaceContainerHighest
                        : TavoColors.violet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(line.text,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: scheme.onSurface)),
                ),
              ],
            ),
          ),
          if (!isChar) ...[
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(left: 8, top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.person_rounded,
                  size: 14, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// 评论项（点头像进用户主页）
class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = comment.author.avatarUrl;
    return GestureDetector(
      onTap: () => context.push('/user/${comment.author.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.surfaceContainerHighest,
              backgroundImage:
                  avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Text(
                      comment.author.name.isNotEmpty
                          ? comment.author.name[0]
                          : '?',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(comment.author.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface)),
                      const SizedBox(width: 8),
                      Text(comment.timeAgo,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.content,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: scheme.onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  const _CommentInput({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        color: scheme.surface,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '说点什么…',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSubmit,
            icon: const Icon(Icons.send_rounded),
            color: TavoColors.violet,
          ),
        ],
      ),
    );
  }
}

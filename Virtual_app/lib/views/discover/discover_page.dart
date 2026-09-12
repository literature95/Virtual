import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/community_api_service.dart';
import '../../theme/tavo_brand.dart';

/// 发现页 —— 社区聚合入口（真实数据，对接后端 PostgreSQL）
///
/// 数据来源：Virtual_background /api/posts、/api/follows，与登录账号通过
/// JWT Bearer token 联动，不再使用任何本地 Mock 假数据。
///
/// - 关注 Tab：横向关注列表（/api/follows 真实创作者）+ 关注作者的动态（/api/posts?following=1）
/// - 推荐 Tab：社区分类过滤（/api/posts?community=）+ 全部动态；可按社区筛选、点赞、发布
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final CommunityApiService _api = CommunityApiService();

  List<Creator> _following = [];
  List<CommunityPost> _followPosts = [];
  List<CommunityPost> _recommendPosts = [];
  bool _loading = true;
  String? _errorMsg;
  String? _activeCommunity;

  late final AuthProvider _auth;
  late final SettingsProvider _settings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _settings = context.read<SettingsProvider>();
    _auth = context.read<AuthProvider>();
    _auth.addListener(_onAuthChanged);
    _load();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 登录态变化 → 重新拉取关注相关内容（关注列表 / 关注流）
  void _onAuthChanged() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final backend = _settings.backendBaseUrl;
    final token = _auth.token;
    try {
      final results = await Future.wait([
        _api.getPosts(backend, community: _activeCommunity, token: token),
        _api.getFollowing(backend, token),
        _api.getPosts(backend, following: true, token: token),
      ]);
      if (!mounted) return;
      setState(() {
        _recommendPosts = results[0] as List<CommunityPost>;
        _following = results[1] as List<Creator>;
        _followPosts = results[2] as List<CommunityPost>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  /// 仅刷新推荐流（社区筛选切换）
  Future<void> _loadRecommendOnly() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final posts = await _api.getPosts(
        _settings.backendBaseUrl,
        community: _activeCommunity,
        token: _auth.token,
      );
      if (!mounted) return;
      setState(() {
        _recommendPosts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  void _selectCommunity(String name) {
    final next = (name == '综合') ? null : name;
    if (next == _activeCommunity) return;
    setState(() => _activeCommunity = next);
    _loadRecommendOnly();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _requireLogin() {
    _snack('请先登录后再操作');
    if (mounted) context.go('/login');
  }

  /// 点赞 / 取消点赞（乐观更新 + 失败回滚）
  Future<void> _onToggleLike(CommunityPost post) async {
    final token = _auth.token;
    if (token == null) {
      _requireLogin();
      return;
    }
    final desired = !post.likedByMe;
    final optimisticLikes = post.likes + (desired ? 1 : -1);
    _replacePost(post.id, (p) => p.copyWithLiked(desired, optimisticLikes));
    try {
      final res = await _api.toggleLike(_settings.backendBaseUrl, token, post.id);
      _replacePost(post.id, (p) => p.copyWithLiked(res.liked, res.likes));
    } catch (e) {
      // 回滚到操作前状态
      _replacePost(post.id, (p) => p.copyWithLiked(!desired, post.likes));
      _snack(e.toString());
    }
  }

  /// 关注 / 取关（切换）
  Future<void> _onToggleFollow(Creator c) async {
    final token = _auth.token;
    if (token == null) {
      _requireLogin();
      return;
    }
    final wasFollowing = _following.any((x) => x.id == c.id);
    try {
      final now = await _api.toggleFollow(_settings.backendBaseUrl, token, c.id);
      if (!mounted) return;
      setState(() {
        if (now) {
          if (!wasFollowing) _following = [c, ..._following];
        } else {
          _following = _following.where((x) => x.id != c.id).toList();
        }
      });
      // 取关后该作者动态应移出关注流
      if (!now) _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _replacePost(String id, CommunityPost Function(CommunityPost) updater) {
    if (!mounted) return;
    setState(() {
      _followPosts =
          _followPosts.map((p) => p.id == id ? updater(p) : p).toList();
      _recommendPosts =
          _recommendPosts.map((p) => p.id == id ? updater(p) : p).toList();
    });
  }

  /// 发布动态（写回后端 community_posts 表）
  Future<void> _showComposeDialog() async {
    final token = _auth.token;
    if (token == null) {
      _requireLogin();
      return;
    }
    final titleC = TextEditingController();
    final contentC = TextEditingController();
    String community = '综合';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('发布动态'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleC,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '一句话概括',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentC,
                  decoration: const InputDecoration(labelText: '内容'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: community,
                  isExpanded: true,
                  items: communityCategories
                      .map((c) => DropdownMenuItem(
                            value: c.name,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: (v) => setSt(() => community = v ?? '综合'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleC.text.trim();
                if (title.isEmpty) {
                  _snack('标题不能为空');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final p = await _api.createPost(
                    _settings.backendBaseUrl,
                    token,
                    title: title,
                    content: contentC.text.trim(),
                    community: community,
                  );
                  if (!mounted) return;
                  setState(() => _recommendPosts = [p, ..._recommendPosts]);
                  _snack('已发布到社区');
                } catch (e) {
                  _snack(e.toString());
                }
              },
              child: const Text('发布'),
            ),
          ],
        ),
      ),
    );
    titleC.dispose();
    contentC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loggedIn = _auth.isLoggedIn;
    final showError = _errorMsg != null &&
        _recommendPosts.isEmpty &&
        _followPosts.isEmpty &&
        _following.isEmpty;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: scheme.onSurface,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: TavoColors.violet,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '关注'),
            Tab(text: '推荐'),
          ],
        ),
        Expanded(
          child: showError
              ? _ErrorState(message: _errorMsg!, onRetry: _load)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _FollowingTab(
                      posts: _followPosts,
                      following: _following,
                      loggedIn: loggedIn,
                      loading: _loading,
                      onToggleFollow: _onToggleFollow,
                      onToggleLike: _onToggleLike,
                      onOpenLogin: _requireLogin,
                    ),
                    _RecommendTab(
                      posts: _recommendPosts,
                      activeCommunity: _activeCommunity,
                      loggedIn: loggedIn,
                      loading: _loading,
                      onSelectCommunity: _selectCommunity,
                      onToggleLike: _onToggleLike,
                      onCompose: _showComposeDialog,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// 关注 Tab
// ════════════════════════════════════════════════════

class _FollowingTab extends StatelessWidget {
  final List<CommunityPost> posts;
  final List<Creator> following;
  final bool loggedIn;
  final bool loading;
  final void Function(Creator) onToggleFollow;
  final void Function(CommunityPost) onToggleLike;
  final VoidCallback onOpenLogin;

  const _FollowingTab({
    required this.posts,
    required this.following,
    required this.loggedIn,
    required this.loading,
    required this.onToggleFollow,
    required this.onToggleLike,
    required this.onOpenLogin,
  });

  @override
  Widget build(BuildContext context) {
    if (!loggedIn) {
      return _LoginHint(onOpenLogin: onOpenLogin, text: '登录后查看关注的创作者动态');
    }
    return CustomScrollView(
      slivers: [
        if (following.isNotEmpty) SliverToBoxAdapter(child: _FollowingBar(
          following: following,
          onToggleFollow: onToggleFollow,
        )),
        if (loading && posts.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (posts.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('还没有关注的人发动态，去推荐里关注些创作者吧')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.separated(
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) =>
                  _PostCard(post: posts[i], onLike: () => onToggleLike(posts[i])),
            ),
          ),
      ],
    );
  }
}

/// 横向关注列表：头像 + 昵称，点击切换关注/取关
class _FollowingBar extends StatelessWidget {
  final List<Creator> following;
  final void Function(Creator) onToggleFollow;

  const _FollowingBar({
    required this.following,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 128,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: following.length + 1, // 末尾加「找更多」
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          if (i == following.length) {
            return GestureDetector(
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '找更多',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          final c = following[i];
          return GestureDetector(
            onTap: () => context.push('/user/${c.id}'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: TavoColors.signGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surfaceContainerLow,
                      image: c.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(c.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: c.avatarUrl == null
                        ? Center(
                            child: Text(
                              (c.name.isNotEmpty ? c.name.characters.first : '?'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '查看主页',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// 推荐 Tab
// ════════════════════════════════════════════════════

class _RecommendTab extends StatelessWidget {
  final List<CommunityPost> posts;
  final String? activeCommunity;
  final bool loggedIn;
  final bool loading;
  final void Function(String) onSelectCommunity;
  final void Function(CommunityPost) onToggleLike;
  final VoidCallback onCompose;

  const _RecommendTab({
    required this.posts,
    required this.activeCommunity,
    required this.loggedIn,
    required this.loading,
    required this.onSelectCommunity,
    required this.onToggleLike,
    required this.onCompose,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 发布入口（登录后可见）
        if (loggedIn)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: onCompose,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: TavoColors.signGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        '分享你的角色卡 / 对话',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // 横向社区分类列表
        SliverToBoxAdapter(child: _CommunityBar(
          active: activeCommunity,
          onSelect: onSelectCommunity,
        )),
        if (loading && posts.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (posts.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(loggedIn ? '这个社区还没有动态' : '登录后查看更多社区动态'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.separated(
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) =>
                  _PostCard(post: posts[i], onLike: () => onToggleLike(posts[i])),
            ),
          ),
      ],
    );
  }
}

/// 横向社区分类列表（点击按社区过滤）
class _CommunityBar extends StatelessWidget {
  final String? active;
  final void Function(String) onSelect;

  const _CommunityBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: communityCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final c = communityCategories[i];
          final isActive = (active ?? '综合') == c.name;
          return GestureDetector(
            onTap: () => onSelect(c.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? c.color.withValues(alpha: 0.22)
                    : c.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive ? c.color : c.color.withValues(alpha: 0.3),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.icon, size: 20, color: c.color),
                  const SizedBox(width: 8),
                  Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// 通用帖子卡片
// ════════════════════════════════════════════════════

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;

  const _PostCard({required this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    final card = switch (post.type) {
      PostType.announcement => _AnnouncementCard(post: post, onLike: onLike),
      PostType.characterCard => _CharacterPostCard(post: post, onLike: onLike),
      PostType.conversationShowcase =>
        _ConversationShowcaseCard(post: post, onLike: onLike),
      PostType.text => _TextPostCard(post: post, onLike: onLike),
    };
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: card,
    );
  }
}

/// 官方公告卡片
class _AnnouncementCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;

  const _AnnouncementCard({required this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TavoColors.violet.withValues(alpha: 0.15),
            TavoColors.coral.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: TavoColors.violet.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: TavoColors.signGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '公告',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                post.author.name,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                post.timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _InteractionBar(post: post, onLike: onLike),
        ],
      ),
    );
  }
}

/// 普通文字动态卡片
class _TextPostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;

  const _TextPostCard({required this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(post: post),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              post.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                post.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: post.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$t',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _InteractionBar(post: post, onLike: onLike),
        ],
      ),
    );
  }
}

/// 角色卡宣传帖子
class _CharacterPostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;

  const _CharacterPostCard({required this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(post: post),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: post.characterId != null
                ? () => context.push('/home/character/${post.characterId}')
                : null,
            child: Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: TavoColors.signGradientDiagonal,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.community,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.download_rounded,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            '${post.likes}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                post.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: scheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 10),
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: post.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                scheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$t',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          _InteractionBar(post: post, onLike: onLike),
        ],
      ),
    );
  }
}

/// 对话炫耀卡片
class _ConversationShowcaseCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;

  const _ConversationShowcaseCard({required this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(post: post),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              post.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                post.content,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (post.dialogue != null && post.dialogue!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: post.dialogue!
                    .map((line) => _DialogueBubble(line: line))
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: post.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                scheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$t',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          _InteractionBar(post: post, onLike: onLike),
        ],
      ),
    );
  }
}

/// 对话气泡
class _DialogueBubble extends StatelessWidget {
  final DialogueLine line;

  const _DialogueBubble({required this.line});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isChar = line.isCharacter;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isChar ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isChar) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: const BoxDecoration(
                gradient: TavoColors.signGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                line.name.characters.first,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isChar ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(
                  line.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isChar
                        ? scheme.surfaceContainerHighest
                        : TavoColors.violet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isChar ? 4 : 14),
                      topRight: Radius.circular(isChar ? 14 : 4),
                      bottomLeft: const Radius.circular(14),
                      bottomRight: const Radius.circular(14),
                    ),
                  ),
                  child: Text(
                    line.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isChar) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 8, top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.person_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 作者信息行（头像 + 名称 + 时间）
class _AuthorRow extends StatelessWidget {
  final CommunityPost post;

  const _AuthorRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: GestureDetector(
        onTap: () => context.push('/user/${post.author.id}'),
        child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              gradient: TavoColors.signGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                post.author.name.isNotEmpty
                    ? post.author.name.characters.first
                    : '?',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.author.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                post.timeAgo,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (post.type == PostType.characterCard)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TavoColors.cosmosGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: TavoColors.cosmosGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded,
                      size: 13, color: TavoColors.cosmosGreen),
                  const SizedBox(width: 3),
                  Text(
                    '角色卡',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: TavoColors.cosmosGreen,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// 互动栏（点赞 / 评论 / 分享）
class _InteractionBar extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;

  const _InteractionBar({required this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 12.5,
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: [
          _iconCount(Icons.favorite_rounded, post.likes, style,
              color: post.likedByMe ? TavoColors.coral : null, onTap: onLike),
          const SizedBox(width: 24),
          _iconCount(Icons.chat_bubble_outline_rounded, post.comments, style,
              onTap: () => context.push('/post/${post.id}')),
          const SizedBox(width: 24),
          _iconCount(Icons.share_outlined, post.shares, style),
        ],
      ),
    );
  }

  Widget _iconCount(IconData icon, int count, TextStyle style,
      {Color? color, VoidCallback? onTap}) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? style.color),
        const SizedBox(width: 5),
        Text(
          count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
          style: style,
        ),
      ],
    );
    return onTap != null
        ? GestureDetector(onTap: onTap, child: child)
        : child;
  }
}

// ════════════════════════════════════════════════════
// 通用状态组件
// ════════════════════════════════════════════════════

class _LoginHint extends StatelessWidget {
  final VoidCallback onOpenLogin;
  final String text;

  const _LoginHint({required this.onOpenLogin, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.login_rounded, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onOpenLogin,
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('加载失败：$message',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

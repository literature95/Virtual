import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/community_api_service.dart';

/// 用户主页（点击头像进入，数据来自 /api/users/[id]）
///
/// 展示用户信息、动态/关注/粉丝统计、关注/取关按钮（乐观更新 + 登录校验），
/// 以及 TA 的帖子列表（点击进入动态详情）。与账号体系通过 JWT 联动。
class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final CommunityApiService _api = CommunityApiService();
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  late final AuthProvider _auth;
  late final SettingsProvider _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    _auth = context.read<AuthProvider>();
    _auth.addListener(_onAuth);
    _load();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
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
      final p = await _api.getUserProfile(
        _settings.backendBaseUrl,
        widget.userId,
        token: _auth.token,
      );
      if (!mounted) return;
      setState(() {
        _profile = p;
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _toggleFollow() async {
    final token = _auth.token;
    if (token == null) {
      _snack('请先登录后再关注');
      if (mounted) context.go('/login');
      return;
    }
    if (_profile == null) return;
    final prev = _profile!.isFollowing;
    final prevCount = _profile!.followerCount;
    // 乐观更新
    setState(() => _profile = _profile!.copyWith(
          isFollowing: !prev,
          followerCount: prevCount + (prev ? -1 : 1),
        ));
    try {
      final now = await _api.toggleFollow(
        _settings.backendBaseUrl,
        token,
        widget.userId,
      );
      if (!mounted) return;
      setState(() => _profile = _profile!.copyWith(
            isFollowing: now,
            followerCount: prevCount + (now ? 1 : -1),
          ));
    } catch (e) {
      // 回滚
      setState(() => _profile = _profile!.copyWith(
            isFollowing: prev,
            followerCount: prevCount,
          ));
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelf = _profile != null && _profile!.id == (_auth.user?.id ?? '');
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.name ?? '用户主页'),
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
              : _profile == null
                  ? const Center(child: Text('用户不存在'))
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _ProfileHeader(
                            profile: _profile!,
                            isSelf: isSelf,
                            onToggleFollow: _toggleFollow,
                            onEdit: () => context.push('/profile/edit'),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: _profile!.posts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (_, i) =>
                                _ProfilePostCard(post: _profile!.posts[i]),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final bool isSelf;
  final VoidCallback onToggleFollow;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.profile,
    required this.isSelf,
    required this.onToggleFollow,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = profile.avatarUrl;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: scheme.surfaceContainerHighest,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(
                    profile.name.isNotEmpty ? profile.name[0] : '?',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface),
          ),
          if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                profile.bio!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('动态', profile.postCount, scheme),
              Container(width: 1, height: 28, color: scheme.outlineVariant),
              _buildStat('关注', profile.followingCount, scheme),
              Container(width: 1, height: 28, color: scheme.outlineVariant),
              _buildStat('粉丝', profile.followerCount, scheme),
            ],
          ),
          const SizedBox(height: 16),
          if (!isSelf)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onToggleFollow,
                child: Text(profile.isFollowing ? '已关注' : '关注'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑个人信息'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int n, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          children: [
            Text('$n',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      );
}

/// 用户主页下的帖子卡片（点击进入动态详情）
class _ProfilePostCard extends StatelessWidget {
  final CommunityPost post;
  const _ProfilePostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite_rounded,
                    size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${post.likes}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${post.comments}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                const Spacer(),
                Text(post.timeAgo,
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

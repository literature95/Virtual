import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/community_post.dart';
import '../../theme/tavo_brand.dart';

/// 发现页 —— 社区聚合入口
///
/// 两个 Tab：
/// - 关注：横向关注列表（头像+ID）→ 关注创作者发布的角色卡 / 动态
/// - 推荐：横向社区分类 → 热门角色卡 + 用户对话炫耀 + 官方公告
///
/// 第一版使用 Mock 假数据，后续接后端 API 时替换数据来源即可。
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 不用 Scaffold：home_shell 已提供 AppBar，避免双层 AppBar
    // 导致 TabBarView 高度约束断裂（99895px 溢出）
    return Column(
      children: [
        // TabBar 固定在顶部
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
        // TabBarView 用 Expanded 撑满剩余高度
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _FollowingTab(),
              _RecommendTab(),
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
  const _FollowingTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 顶部横向关注列表
        SliverToBoxAdapter(child: _FollowingBar()),
        // 信息流
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.separated(
            itemCount: mockFollowingPosts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _PostCard(post: mockFollowingPosts[i]),
          ),
        ),
      ],
    );
  }
}

/// 横向关注列表：头像 + ID
class _FollowingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 128,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: mockFollowing.length + 1, // 末尾加「找更多」
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          if (i == mockFollowing.length) {
            // 找更多
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
          final c = mockFollowing[i];
          return GestureDetector(
            onTap: () {},
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 渐变头像圈
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
                    ),
                    child: ClipOval(
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          c.name.characters.first,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
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
                Text(
                  c.id,
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
  const _RecommendTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 横向社区分类列表
        SliverToBoxAdapter(child: _CommunityBar()),
        // 热门角色卡 + 用户动态 + 官方公告
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.separated(
            itemCount: mockRecommendPosts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _PostCard(post: mockRecommendPosts[i]),
          ),
        ),
      ],
    );
  }
}

/// 横向社区分类列表
class _CommunityBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: mockCommunities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final c = mockCommunities[i];
          return GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: c.color.withValues(alpha: 0.3),
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
                      fontWeight: FontWeight.w600,
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
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    switch (post.type) {
      case PostType.announcement:
        return _AnnouncementCard(post: post);
      case PostType.characterCard:
        return _CharacterPostCard(post: post);
      case PostType.conversationShowcase:
        return _ConversationShowcaseCard(post: post);
    }
  }
}

/// 官方公告卡片
class _AnnouncementCard extends StatelessWidget {
  final CommunityPost post;
  const _AnnouncementCard({required this.post});

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
          _InteractionBar(post: post),
        ],
      ),
    );
  }
}

/// 角色卡宣传帖子
class _CharacterPostCard extends StatelessWidget {
  final CommunityPost post;
  const _CharacterPostCard({required this.post});

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
          // 作者行
          _AuthorRow(post: post),
          const SizedBox(height: 4),
          // 封面区
          GestureDetector(
            onTap: post.characterId != null ? () => context.go('/home') : null,
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
                  // 渐变底 + 角色名
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
                  // 标签
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
          // 正文
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
          // 标签
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
          _InteractionBar(post: post),
        ],
      ),
    );
  }
}

/// 对话炫耀卡片
class _ConversationShowcaseCard extends StatelessWidget {
  final CommunityPost post;
  const _ConversationShowcaseCard({required this.post});

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
          // 作者行
          _AuthorRow(post: post),
          const SizedBox(height: 8),
          // 标题
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
          // 对话气泡区
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
          // 标签
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
          _InteractionBar(post: post),
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
            // 角色头像气泡
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
                post.author.name.characters.first,
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
    );
  }
}

/// 互动栏（点赞 / 评论 / 分享）
class _InteractionBar extends StatelessWidget {
  final CommunityPost post;
  const _InteractionBar({required this.post});

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
          _iconCount(Icons.favorite_border_rounded, post.likes, style,
              color: TavoColors.coral),
          const SizedBox(width: 24),
          _iconCount(Icons.chat_bubble_outline_rounded, post.comments, style),
          const SizedBox(width: 24),
          _iconCount(Icons.share_outlined, post.shares, style),
        ],
      ),
    );
  }

  Widget _iconCount(IconData icon, int count, TextStyle style, {Color? color}) {
    return Row(
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
  }
}

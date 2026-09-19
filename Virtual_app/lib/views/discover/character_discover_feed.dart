import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/online_character_service.dart';
import '../../theme/tavo_brand.dart';
import '../common/character_cover_card.dart' show resolveAvatarImage;

/// 发现页 —「发现」Tab：竖向角色卡流（一次一卡，上下滑切换）
///
/// - 底栏仍由 HomeShell 提供，本页只占 Shell body
/// - 点卡片主体 → `/home/character/:id` 在线详情
/// - 右侧操作：点赞 / 收藏 / 转发（v1 本地状态；收藏同时提示可去详情加入角色库）
class CharacterDiscoverFeed extends StatefulWidget {
  const CharacterDiscoverFeed({super.key});

  @override
  State<CharacterDiscoverFeed> createState() => _CharacterDiscoverFeedState();
}

class _CharacterDiscoverFeedState extends State<CharacterDiscoverFeed> {
  final OnlineCharacterService _service = OnlineCharacterService();
  final PageController _pc = PageController();

  List<OnlineCharacter> _items = [];
  bool _loading = true;
  String? _error;
  int _index = 0;

  final Set<String> _liked = {};
  final Set<String> _faved = {};
  final Map<String, int> _shares = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchCharacters(backend);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        if (_index >= list.length) _index = list.isEmpty ? 0 : list.length - 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无在线角色卡，去角色库导入或后台发布吧'));
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pc,
          scrollDirection: Axis.vertical,
          itemCount: _items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => _CharacterFeedCard(
            character: _items[i],
            liked: _liked.contains(_items[i].id),
            faved: _faved.contains(_items[i].id),
            shares: _shares[_items[i].id] ?? 0,
            onTapCard: () =>
                context.push('/home/character/${Uri.encodeComponent(_items[i].id)}'),
            onLike: () => setState(() {
              final id = _items[i].id;
              if (!_liked.remove(id)) _liked.add(id);
            }),
            onFav: () {
              setState(() {
                final id = _items[i].id;
                if (!_faved.remove(id)) _faved.add(id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _faved.contains(_items[i].id)
                        ? '已收藏「${_items[i].name}」，可在详情页加入角色库'
                        : '已取消收藏',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            onShare: () {
              setState(() {
                final id = _items[i].id;
                _shares[id] = (_shares[id] ?? 0) + 1;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('转发链接已复制（演示）')),
              );
            },
          ),
        ),
        // 右侧页码点
        Positioned(
          right: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _items.length && i < 8; i++)
                  Container(
                    width: 4,
                    height: i == _index ? 12 : 4,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: i == _index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CharacterFeedCard extends StatelessWidget {
  final OnlineCharacter character;
  final bool liked;
  final bool faved;
  final int shares;
  final VoidCallback onTapCard;
  final VoidCallback onLike;
  final VoidCallback onFav;
  final VoidCallback onShare;

  const _CharacterFeedCard({
    required this.character,
    required this.liked,
    required this.faved,
    required this.shares,
    required this.onTapCard,
    required this.onLike,
    required this.onFav,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = resolveAvatarImage(character.avatarUrl);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTapCard,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 立绘 / 品牌占位
          if (avatar != null)
            Image(
              image: avatar,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _FeedPlaceholder(),
            )
          else
            const _FeedPlaceholder(),
          // 底部信息层
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x66000000),
                  Color(0xE6000000),
                ],
                stops: [0.45, 0.7, 1],
              ),
            ),
          ),
          // 左下信息
          Positioned(
            left: 16,
            right: 78,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (character.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: character.tags
                        .take(4)
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (character.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    character.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '查看角色详情 →',
                  style: TextStyle(
                    color: TavoColors.textHighlightPurple,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 右侧操作轨
          Positioned(
            right: 12,
            bottom: 36,
            child: Column(
              children: [
                _FeedAction(
                  icon: Icons.favorite_rounded,
                  active: liked,
                  activeColor: TavoColors.coral,
                  label: '${1000 + (character.id.hashCode % 800) + (liked ? 1 : 0)}',
                  onTap: onLike,
                ),
                const SizedBox(height: 16),
                _FeedAction(
                  icon: Icons.bookmark_rounded,
                  active: faved,
                  activeColor: TavoColors.amber,
                  label: '${200 + (character.id.hashCode % 300) + (faved ? 1 : 0)}',
                  onTap: onFav,
                ),
                const SizedBox(height: 16),
                _FeedAction(
                  icon: Icons.share_rounded,
                  active: false,
                  activeColor: scheme.primary,
                  label: '${50 + (character.id.hashCode % 40) + shares}',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TavoColors.violet.withValues(alpha: 0.45),
            TavoColors.cosmosBg,
            TavoColors.amber.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 72,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _FeedAction extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final String label;
  final VoidCallback onTap;

  const _FeedAction({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(
                color: active
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              icon,
              color: active ? activeColor : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

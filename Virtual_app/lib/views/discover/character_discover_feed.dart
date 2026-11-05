import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/app_image_cache.dart';
import '../../services/online_character_service.dart';
import '../../theme/tavo_brand.dart';
import '../../utils/random_order.dart';
import '../common/cached_app_image.dart';

/// 发现页 —「发现」Tab：竖向角色卡流（一次一卡，上下滑切换）
///
/// - 底栏仍由 HomeShell 提供，本页只占 Shell body
/// - 点卡片主体 → `/home/character/:id` 在线详情
/// - 右侧操作：点赞 / 转发（v1 本地状态）
/// - 排序：进入页面保持后端顺序；**只有下拉刷新**才随机重排（避免滚动中途跳卡）
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

  /// 客户端分批呈现：后端 `/api/characters` 不分页、一次返回全部，
  /// 这里先只渲染前 [_pageSize] 张，滑到接近末尾再追加一批，
  /// 避免首帧就为全部卡片建 widget / 触发图片解码。
  static const int _pageSize = 12;
  int _visibleCount = _pageSize;

  final Set<String> _liked = {};
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

  int get _renderedCount =>
      _visibleCount < _items.length ? _visibleCount : _items.length;

  /// 只预取**下一张**（并发上限由 [AppImagePreloader] 控制为 2）；
  /// 不再一次预取多张，避免和首张抢带宽。
  void _preloadAround(int index) {
    if (!mounted || _items.isEmpty) return;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = AppImageCache.decodeWidthFor(width, dpr);
    final indices =
        lookaheadIndices(index, _renderedCount, lookahead: 1);
    AppImagePreloader.preload(
      context,
      [for (final i in indices) _items[i].avatarUrl],
      decodeWidth: decodeWidth,
    );
  }

  /// 滑到本批末尾前 2 张时追加下一批（每批 12 张）
  void _ensureBatchFor(int index) {
    if (index < _renderedCount - 2 || _renderedCount >= _items.length) return;
    final next = _visibleCount + _pageSize;
    setState(() {
      _visibleCount = next > _items.length ? _items.length : next;
    });
  }

  /// [shuffle] 仅在**下拉刷新**时为 true：
  /// - 进入页面（initState / 首次加载）保持后端顺序；
  /// - 刷新时随机重排并回到第一张，形成「换一批」。
  Future<void> _load({bool shuffle = false}) async {
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    setState(() {
      // 刷新时保留当前卡片流，等新顺序拿到后再整体替换（RefreshIndicator 自己转圈）
      if (!shuffle) _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchCharacters(backend);
      if (!mounted) return;
      final ordered = shuffle ? shuffledOrder(list, Random()) : list;
      setState(() {
        _items = ordered;
        _loading = false;
        // 每次加载/刷新都从第一页开始，首批只渲染 12 张
        _visibleCount = _pageSize;
        if (shuffle) {
          _index = 0;
        } else if (_index >= ordered.length) {
          _index = ordered.isEmpty ? 0 : ordered.length - 1;
        }
      });
      if (shuffle && _pc.hasClients) {
        _pc.jumpToPage(0);
      }
      _preloadAround(_index);
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
      // 列表未就绪：先给骨架，不白屏空等
      return const _FeedSkeleton();
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

    // 下拉刷新 = 唯一触发随机重排的时机；进入页面/翻页都不重排
    return RefreshIndicator(
      onRefresh: () => _load(shuffle: true),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            // 保留翻页吸附，同时允许在第一张继续下拉 → 触发刷新
            physics:
                const PageScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            itemCount: _renderedCount,
            onPageChanged: (i) {
              setState(() => _index = i);
              _ensureBatchFor(i);
              _preloadAround(i);
            },
            itemBuilder: (context, i) => _CharacterFeedCard(
              character: _items[i],
              liked: _liked.contains(_items[i].id),
              shares: _shares[_items[i].id] ?? 0,
              onTapCard: () => context.push(
                  '/home/character/${Uri.encodeComponent(_items[i].id)}'),
              onLike: () => setState(() {
                final id = _items[i].id;
                if (!_liked.remove(id)) _liked.add(id);
              }),
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
      ),
    );
  }
}

class _CharacterFeedCard extends StatelessWidget {
  final OnlineCharacter character;
  final bool liked;
  final int shares;
  final VoidCallback onTapCard;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _CharacterFeedCard({
    required this.character,
    required this.liked,
    required this.shares,
    required this.onTapCard,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTapCard,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 立绘 / 品牌占位（全屏卡：按屏宽 × DPR 解码，详情页才解原图）
          if ((character.avatarUrl ?? '').isNotEmpty)
            CachedAppImage(
              path: character.avatarUrl,
              fit: BoxFit.cover,
              placeholderColor: TavoColors.cosmosElev,
              fallback: const _FeedPlaceholder(),
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

/// 首屏骨架：角色卡列表未返回时的占位（深色底 + 图片区 + 文字条）
///
/// 进入发现页后立即出现，替代原来的空白等待；列表到达后整屏替换为卡片流。
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TavoColors.cosmosBg, TavoColors.cosmosElev],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片区骨架：大号圆角块
          Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // 底部文字骨架
          Positioned(
            left: 16,
            right: 78,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _bar(150, 22),
                const SizedBox(height: 10),
                _bar(220, 12),
                const SizedBox(height: 8),
                _bar(180, 12),
              ],
            ),
          ),
          // 加载态提示（不遮挡卡片）
          const Positioned(
            top: 16,
            right: 16,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
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

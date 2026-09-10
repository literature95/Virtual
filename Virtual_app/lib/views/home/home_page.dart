import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/banner_item.dart';
import '../../providers/settings_provider.dart';
import '../../services/banner_service.dart';
import '../../services/online_character_service.dart';
import '../../theme/tavo_brand.dart';
import '../common/character_cover_card.dart';
import 'banner_carousel.dart';

/// 首页 —— 在线角色卡广场：
/// 后端 /api/characters 拉取 + 分类过滤 + 搜索
/// 左上角菜单/右上角搜索由 HomeShell 按路由条件渲染。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  /// AppBar 右上角搜索图标 → 展开页内搜索框的跨组件通知
  static final ValueNotifier<bool> searchVisible = ValueNotifier(false);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final OnlineCharacterService _service = OnlineCharacterService();
  final BannerService _bannerService = BannerService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<OnlineCharacter>? _characters;

  /// 轮播位；为空时首页不渲染这一块（见 build 里的 sliver 判断）
  List<BannerItem> _banners = const [];
  String? _error;
  String _query = '';
  bool _searchVisible = false;

  /// 正在导入的在线角色 ID（卡片显示 loading 并屏蔽点击）
  String? _busyId;

  @override
  void initState() {
    super.initState();
    HomePage.searchVisible.addListener(_onSearchToggle);
    _load();
  }

  void _onSearchToggle() {
    if (mounted) setState(() => _searchVisible = HomePage.searchVisible.value);
  }

  Future<void> _load() async {
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    _loadBanners(backend);
    try {
      final list = await _service.fetchCharacters(backend);
      if (!mounted) return;
      setState(() {
        _characters = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法连接后端 $backend');
    }
  }

  /// 轮播独立拉取：失败只导致这一块不显示，绝不影响角色列表。
  ///
  /// 不 await —— 它不应该拖慢或阻塞主列表的首屏数据。
  Future<void> _loadBanners(String backend) async {
    final list = await _bannerService.fetchBanners(backend);
    if (!mounted || list.isEmpty) return;
    setState(() => _banners = list);
  }

  /// 主分类聚合：每个角色**只归入其 tags 的第一项（主分类）**，
  /// 因此同一张卡在首页只出现一次 —— 避免按全部 tag 拆分导致一张卡
  /// 在「治愈 / 日常 / 温柔 / 深夜 / OC」等五六个区块里反复出现。
  ///
  /// 顺序按角色首次出现的主分类排列，稳定可预期。
  Map<String, List<OnlineCharacter>> get _categoryMap {
    final map = <String, List<OnlineCharacter>>{};
    for (final c in _characters ?? const <OnlineCharacter>[]) {
      final primary = c.tags.isNotEmpty ? c.tags.first : '其他';
      map.putIfAbsent(primary, () => []).add(c);
    }
    return map;
  }

  /// 仅按搜索词过滤；分类筛选交给 [CategoryCharactersPage]
  List<OnlineCharacter> get _filtered {
    final all = _characters ?? const <OnlineCharacter>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
    }).toList();
  }

  /// 竖版封面卡列数：宽屏（内容限宽 560）3 列，否则 2 列
  int get _gridColumns => MediaQuery.of(context).size.width >= 720 ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: () async => _load(),
      child: CustomScrollView(
        slivers: [
          // 搜索框（右上角搜索图标点击展开）
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _searchVisible
                  ? Padding(
                      key: const ValueKey('search'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: TextStyle(color: scheme.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '搜索角色名或描述…',
                          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                          prefixIcon: Icon(Icons.search,
                              size: 20, color: scheme.onSurfaceVariant),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close,
                                size: 18, color: scheme.onSurfaceVariant),
                            onPressed: () {
                              _searchCtrl.clear();
                              HomePage.searchVisible.value = false;
                              setState(() => _query = '');
                            },
                          ),
                          filled: true,
                          fillColor: scheme.surfaceContainer,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ),

          // 轮播图（横版运营位）—— 在分类 chips 之上，拿到数据才占位
          // 不加 top padding：轮播紧贴 AppBar，铺满屏宽的沉浸式首屏
          if (_banners.isNotEmpty)
            SliverToBoxAdapter(
              child: BannerCarousel(
                items: _banners,
                // 宽高比 1.58:1，宽度铺满、高度自适应
                aspectRatio: 1.58,
                onTap: _openBanner,
              ),
            ),

          // 分类区块 or 搜索结果
          if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _errorView(context),
            )
          else if (_characters == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: TavoColors.violet),
              ),
            )
          else if (_query.trim().isNotEmpty)
            _searchResultGrid()
          else
            ..._categorySections(scheme),
        ],
      ),
    );
  }

  /// 首页分类区块：每个主分类一个标题行 + 竖向 2 列网格（一排两个、取 4 张）+ 「更多」入口
  List<Widget> _categorySections(ColorScheme scheme) {
    final map = _categoryMap;
    if (map.isEmpty) {
      return [SliverFillRemaining(hasScrollBody: false, child: _emptyView())];
    }

    final sections = <Widget>[];
    var i = 0;
    for (final entry in map.entries) {
      final category = entry.key;
      final items = entry.value.take(4).toList();
      if (items.isEmpty) continue;

      sections.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              i == 0 ? 16 : 24,
              16,
              12,
            ),
            child: Row(
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    // 跟随主题：浅色主题下白底白字会完全不可见
                    color: scheme.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go(
                    '/home/category/${Uri.encodeComponent(category)}',
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '更多',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      sections.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              // 竖向 2 列网格：一排两个竖版封面卡，take(4) 即 2 行。
              // 比例 0.62 与全局网格一致，卡片不随屏宽拉伸失真。
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final c = items[index];
                return CharacterCoverCard(
                  name: c.name,
                  description: c.description,
                  tags: const [], // 区块标题已是分类，卡片不再重复显示标签
                  avatarUrl: c.avatarUrl,
                  busy: _busyId == c.id,
                  onTap: () => _openCharacter(context, c),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      );
      i++;
    }
    return sections;
  }

  /// 搜索命中结果：全网格展示
  Widget _searchResultGrid() {
    final items = _filtered;
    if (items.isEmpty) {
      return SliverFillRemaining(hasScrollBody: false, child: _emptyView());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final c = items[i];
            return CharacterCoverCard(
              name: c.name,
              description: c.description,
              tags: c.tags,
              avatarUrl: c.avatarUrl,
              busy: _busyId == c.id,
              onTap: () => _openCharacter(context, c),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TavoBrand.emptyIllustration(Icons.cloud_off_outlined, size: 64),
            const SizedBox(height: 18),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Text(
              '请在「我的 → API接入」检查后端地址，或确认后端已启动',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 20),
            TavoBrand.gradientButton(
              onPressed: _load,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              child: const Text('重新加载', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TavoBrand.emptyIllustration(Icons.auto_awesome_outlined, size: 64),
          const SizedBox(height: 18),
          Text(
            '没有匹配的角色',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// 点击轮播：找到关联角色后**复用封面卡同一条闭环**（导入 → 直达对话）
  ///
  /// 落差处理：banner 指向的角色不一定在列表数据里（后端列表端点可能未返回，
  /// 或该运营位指向的角色尚未上线），这种情况下单独拉一次详情，
  /// 拉不到才提示——不要静默无反应，也不要让整页崩。
  Future<void> _openBanner(BannerItem banner) async {
    final characterId = banner.characterId;
    if (characterId == null || characterId.isEmpty) return;

    OnlineCharacter? target;
    for (final c in _characters ?? const <OnlineCharacter>[]) {
      if (c.id == characterId) {
        target = c;
        break;
      }
    }

    if (target == null) {
      final backend = context.read<SettingsProvider>().backendBaseUrl;
      try {
        target = await _service.fetchCharacter(backend, characterId);
      } catch (_) {
        target = null;
      }
      if (!mounted) return;
    }

    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${banner.title}」暂时无法打开')),
      );
      return;
    }
    _openCharacter(context, target);
  }

  /// 点击角色卡 → 跳转到角色卡详情页（不再直接进对话）
  void _openCharacter(BuildContext context, OnlineCharacter c) {
    context.push('/home/character/${Uri.encodeComponent(c.id)}');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

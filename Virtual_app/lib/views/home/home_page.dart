import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/banner_item.dart';
import '../../models/character.dart';
import '../../providers/chat_provider.dart';
import '../../providers/character_provider.dart';
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
  String _selectedCategory = '全部';
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

  List<String> get _categories {
    final set = <String>{'全部'};
    for (final c in _characters ?? const <OnlineCharacter>[]) {
      set.addAll(c.tags);
    }
    return set.toList();
  }

  List<OnlineCharacter> get _filtered {
    final all = _characters ?? const <OnlineCharacter>[];
    return all.where((c) {
      final catOk =
          _selectedCategory == '全部' || c.tags.contains(_selectedCategory);
      final q = _query.trim().toLowerCase();
      final qOk = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
      return catOk && qOk;
    }).toList();
  }

  /// 竖版封面卡列数：宽屏（内容限宽 560）3 列，否则 2 列
  int get _gridColumns =>
      MediaQuery.of(context).size.width >= 720 ? 3 : 2;

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
          if (_banners.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: BannerCarousel(
                  items: _banners,
                  height: 150,
                  onTap: _openBanner,
                ),
              ),
            ),

          // 分类过滤 chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children:
                    _categories.map((c) => _categoryChip(c, scheme)).toList(),
              ),
            ),
          ),

          // 角色卡列表
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
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyView(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  // 竖版封面卡：窄屏 2 列，宽屏（内容限宽 560）3 列。
                  // 比例 0.62 固定，卡片不再像旧横版那样随屏宽拉伸失真。
                  crossAxisCount: _gridColumns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final c = _filtered[i];
                    return CharacterCoverCard(
                      name: c.name,
                      description: c.description,
                      tags: c.tags,
                      avatarUrl: c.avatarUrl,
                      busy: _busyId == c.id,
                      onTap: () => _openCharacter(context, c),
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, ColorScheme scheme) {
    final selected = label == _selectedCategory;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? TavoColors.signGradient : null,
            color: selected ? null : scheme.surfaceContainer,
            border: Border.all(
              color: selected ? Colors.transparent : scheme.outline,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
          ),
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
    await _openCharacter(context, target);
  }

  /// 打开角色：确保本地有这张卡 → 进入（或续聊）对话。
  ///
  /// 三个必须同时成立的点，缺一个闭环就断：
  /// 1. **走详情接口** —— 列表接口省略了 exampleMessages / personality 等核心
  ///    人设，直接拿列表项建卡会得到「只有名字和头像」的空壳角色。
  /// 2. **幂等** —— 用后端角色 ID（存进 `extensions['sourceId']`）查重，
  ///    重复点击同一张卡不会在本地堆出 N 个同名副本。
  /// 3. **直达** —— 导入完直接建会话并跳转 `/chat/:id`，不停留在首页让用户
  ///    自己切到「角色」Tab 去找；已聊过的角色回到原对话，不新建空会话。
  Future<void> _openCharacter(BuildContext context, OnlineCharacter c) async {
    if (_busyId != null) return;

    final messenger = ScaffoldMessenger.of(context);
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    final characters = context.read<CharacterProvider>();
    final chats = context.read<ChatProvider>();

    setState(() => _busyId = c.id);
    try {
      final local = await _ensureLocalCharacter(characters, backend, c);
      if (!mounted) return;

      final conv = chats.latestConversationOf(local.id) ??
          await chats.createConversation(
            characterId: local.id,
            title: local.name,
          );
      if (!mounted) return;
      context.go('/chat/${conv.id}');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('导入「${c.name}」失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// 保证本地存在该在线角色对应的 [Character]：已导入则复用，否则拉取详情后建卡
  Future<Character> _ensureLocalCharacter(
    CharacterProvider characters,
    String backend,
    OnlineCharacter c,
  ) async {
    final existing = characters.findBySourceId(c.id);
    if (existing != null) return existing;

    final full = await _service.fetchCharacter(backend, c.id);
    return characters.createCharacter(
      name: full.name,
      nickname: full.nickname,
      description: full.description,
      personality: full.personality,
      scenario: full.scenario,
      firstMessage: full.firstMessage,
      avatarPath: full.avatarUrl,
      creatorNotes: full.creatorNotes,
      systemPrompt: full.systemPrompt,
      postHistoryInstructions: full.postHistoryInstructions,
      creator: full.creator,
      characterVersion: full.characterVersion,
      source: full.source,
      tags: full.tags,
      alternateGreetings: full.alternateGreetings,
      exampleMessages: full.exampleMessages,
      groupOnlyGreetings: full.groupOnlyGreetings,
      creatorNotesMultilingual: full.creatorNotesMultilingual,
      extensions: full.importExtensions,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

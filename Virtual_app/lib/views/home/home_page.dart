import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/online_character_service.dart';
import '../../theme/tavo_brand.dart';
import '../common/character_photo_card.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();

  List<OnlineCharacter>? _characters;
  String? _error;
  String _selectedCategory = '全部';
  String _query = '';
  bool _searchVisible = false;

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
    final backend =
        context.read<SettingsProvider>().backendBaseUrl;
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
      final catOk = _selectedCategory == '全部' ||
          c.tags.contains(_selectedCategory);
      final q = _query.trim().toLowerCase();
      final qOk = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
      return catOk && qOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: TavoColors.violet,
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
                        style: const TextStyle(
                            color: TavoColors.cosmosText, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '搜索角色名或描述…',
                          hintStyle: const TextStyle(
                              color: TavoColors.cosmosTextFaint),
                          prefixIcon: const Icon(Icons.search,
                              size: 20, color: TavoColors.cosmosTextFaint),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: TavoColors.cosmosTextDim),
                            onPressed: () {
                              _searchCtrl.clear();
                              HomePage.searchVisible.value = false;
                              setState(() => _query = '');
                            },
                          ),
                          filled: true,
                          fillColor: TavoColors.cosmosElev,
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

          // 分类过滤 chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _categories.map(_categoryChip).toList(),
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
              sliver: SliverList.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) {
                  final c = _filtered[i];
                  return CharacterPhotoCard(
                    name: c.name,
                    description: c.description,
                    tags: c.tags,
                    avatarUrl: c.avatarUrl,
                    onTap: () => _openCharacter(context, c),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label) {
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
            color: selected ? null : TavoColors.cosmosElev,
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : TavoColors.cosmosTextDim,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context) {
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
              style: const TextStyle(
                  color: TavoColors.cosmosTextDim, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            const Text(
              '请在「我的 → API接入」检查后端地址，或确认后端已启动',
              textAlign: TextAlign.center,
              style: TextStyle(color: TavoColors.cosmosTextFaint, fontSize: 12),
            ),
            const SizedBox(height: 20),
            TavoBrand.gradientButton(
              onPressed: _load,
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              child: const Text('重新加载', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TavoBrand.emptyIllustration(Icons.auto_awesome_outlined, size: 64),
          const SizedBox(height: 18),
          const Text(
            '没有匹配的角色',
            style: TextStyle(color: TavoColors.cosmosTextDim, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// 打开角色：从后端在线卡导入本地并进入创建流程。
  /// 目前最小版本：先跳到本地角色列表（后续接入"一键导入"）。
  void _openCharacter(BuildContext context, OnlineCharacter c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: TavoColors.cosmosElev,
        content: Text(
          '「${c.name}」在线角色卡（导入功能开发中）',
          style: const TextStyle(color: TavoColors.cosmosText),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

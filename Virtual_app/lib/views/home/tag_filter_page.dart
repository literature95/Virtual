import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/app_image_cache.dart';
import '../../services/online_character_service.dart';
import '../../theme/tavo_brand.dart';
import '../common/cached_app_image.dart';
import '../common/character_cover_card.dart';
import 'tag_filter_data.dart';

/// 标签筛选页（首页顶栏「分类」按钮 → `push` 进入）
///
/// 布局参考用户给的图：
/// - 顶部：返回箭头 + 标题 + 右侧「搜索」按钮；
/// - 左侧竖排四组标签页：热门标签 / 主题 / 角色 / 情节；
/// - 右侧三列 chip 网格；
/// - 点「搜索」按所选标签筛选，同组并集、跨组交集，结果复用首页封面卡。
///
/// 路由约定：本页是 ShellRoute 内的顶级路由，入口必须 `context.push`，
/// 因此有返回箭头；系统返回键走同一条 pop 链路回到首页，不会退出 App。
class TagFilterPage extends StatefulWidget {
  const TagFilterPage({super.key});

  @override
  State<TagFilterPage> createState() => _TagFilterPageState();
}

class _TagFilterPageState extends State<TagFilterPage> {
  final OnlineCharacterService _service = OnlineCharacterService();

  List<OnlineCharacter>? _all;
  String? _error;
  List<TagFilterGroup> _groups = const [];
  int _groupIndex = 0;

  /// 组标题 → 已选标签（同组并集）
  final Map<String, Set<String>> _selected = {};

  /// 是否已进入「筛选结果」态
  bool _showResults = false;
  List<OnlineCharacter> _results = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    try {
      final list = await _service.fetchCharacters(backend);
      if (!mounted) return;
      setState(() {
        _all = list;
        _groups = buildTagFilterGroups(list);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法连接后端 $backend');
    }
  }

  int get _selectedCount =>
      _selected.values.fold(0, (sum, set) => sum + set.length);

  void _toggle(String group, String tag) {
    setState(() {
      final set = _selected.putIfAbsent(group, () => <String>{});
      if (!set.remove(tag)) set.add(tag);
    });
  }

  void _search() {
    if (_selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择至少一个标签')),
      );
      return;
    }
    final all = _all ?? const <OnlineCharacter>[];
    setState(() {
      _results =
          all.where((c) => characterMatchesGroups(c, _selected)).toList();
      _showResults = true;
    });
  }

  void _backToFilters() => setState(() => _showResults = false);

  /// 结果网格缩略图解码宽度（卡宽 × DPR；网格左右 16 内边距、列间 12 间距）
  int? _resultDecodeWidth(int columns) {
    final screen = MediaQuery.sizeOf(context).width;
    final cardWidth = (screen - 32 - 12 * (columns - 1)) / columns;
    return AppImageCache.decodeWidthFor(
      cardWidth,
      MediaQuery.devicePixelRatioOf(context),
    );
  }

  /// 预取「即将进入视口」的少量结果封面（并发上限由 AppImagePreloader 控制）
  void _preloadAround(int index, int columns) {
    if (!mounted || _results.isEmpty) return;
    final indices = lookaheadIndices(index, _results.length, lookahead: 2);
    AppImagePreloader.preload(
      context,
      [for (final i in indices) _results[i].avatarUrl],
      decodeWidth: _resultDecodeWidth(columns),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          // 规则：有返回箭头 → 系统/点按返回都必须回上一级（首页），不退出 App
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          _showResults ? '筛选结果' : '标签筛选',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _showResults
                ? TextButton(
                    onPressed: _backToFilters,
                    child: const Text('重新筛选'),
                  )
                : _searchButton(),
          ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  /// 右上角「搜索」：纯放大镜图标按钮（无文字、无渐变底），点击行为不变。
  /// IconButton 默认 48×48 热区，满足 ≥40dp。
  Widget _searchButton() {
    return IconButton(
      tooltip: '搜索',
      onPressed: _search,
      icon: Icon(Icons.search_rounded,
          size: 22, color: Theme.of(context).colorScheme.onSurface),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TavoBrand.emptyIllustration(Icons.cloud_off_outlined, size: 64),
              const SizedBox(height: 18),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 13.5),
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
    if (_all == null) {
      return const Center(
        child: CircularProgressIndicator(color: TavoColors.violet),
      );
    }
    return _showResults ? _resultView(scheme) : _filterView(scheme);
  }

  // ── 筛选面板：左竖排组 + 右三列 chip ─────────────────────────────

  Widget _filterView(ColorScheme scheme) {
    if (_groups.isEmpty) {
      return Center(
        child: Text(
          '暂无标签数据，先刷新首页角色列表吧',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    final group = _groups[_groupIndex];
    final selected = _selected[group.title] ?? const <String>{};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左侧竖排四组
        Container(
          width: 96,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
            border: Border(
              right: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _groups.length,
            itemBuilder: (context, i) {
              final g = _groups[i];
              final active = i == _groupIndex;
              final count = (_selected[g.title] ?? const <String>{}).length;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _groupIndex = i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        width: 3,
                        color:
                            active ? scheme.primary : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color:
                                active ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // 右侧 chip 网格（三列）
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Text(
                  group.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: group.tags.isEmpty
                    ? Center(
                        child: Text(
                          '这一组暂无可用标签',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.6,
                        ),
                        itemCount: group.tags.length,
                        itemBuilder: (context, i) {
                          final tag = group.tags[i];
                          return _chip(
                            scheme: scheme,
                            label: tag,
                            selected: selected.contains(tag),
                            onTap: () => _toggle(group.title, tag),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required ColorScheme scheme,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? TavoColors.violet
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? TavoColors.violet : scheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 筛选结果：复用首页封面卡 ─────────────────────────────────────

  Widget _resultView(ColorScheme scheme) {
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TavoBrand.emptyIllustration(Icons.search_off_rounded, size: 64),
              const SizedBox(height: 18),
              Text(
                '没有符合所选标签的角色卡',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '试试少选几个标签，或换一组组合再搜一次。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: _backToFilters,
                child: const Text('返回筛选'),
              ),
            ],
          ),
        ),
      );
    }

    final columns = MediaQuery.of(context).size.width >= 720 ? 3 : 2;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                '命中 ${_results.length} 张',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (_selectedCount > 0)
                Text(
                  '已选 $_selectedCount 个标签',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final c = _results[i];
              _preloadAround(i, columns);
              return CharacterCoverCard(
                name: c.name,
                description: c.description,
                tags: c.tags,
                avatarUrl: c.avatarUrl,
                onTap: () => context
                    .push('/home/character/${Uri.encodeComponent(c.id)}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

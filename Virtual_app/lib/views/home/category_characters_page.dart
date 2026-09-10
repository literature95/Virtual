import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/online_character_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/tavo_brand.dart';
import '../common/character_cover_card.dart';

/// 角色卡搜索筛选页
///
/// 从后端拉全量角色，提供多维度筛选：搜索关键词 + 标签横向筛选 +
/// 点赞/收藏/转发数量筛选，下方网格展示匹配的角色卡。
/// 入口：
///   - 首页分类区「更多 >」按钮（预选中该分类）
///   - 首页 AppBar 搜索图标（无预选分类）
///
/// 互动数（点赞/收藏/转发）后端 /api/characters 暂不下发，按 characterId
/// hash 本地生成稳定 mock，与详情页互动条同源，后续后端补字段时替换即可。
class CategoryCharactersPage extends StatefulWidget {
  /// 预选中的分类 tag；为空表示不预选（从搜索入口进入）
  final String? category;

  const CategoryCharactersPage({
    super.key,
    this.category,
  });

  @override
  State<CategoryCharactersPage> createState() => _CategoryCharactersPageState();
}

class _CategoryCharactersPageState extends State<CategoryCharactersPage> {
  final OnlineCharacterService _service = OnlineCharacterService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<OnlineCharacter>? _all;
  String? _error;
  String? _busyId;
  String _query = '';

  /// 当前选中的标签集（可多选，空集 = 不限）
  final Set<String> _selectedTags = {};

  /// 互动数筛选项
  _MetricFilter _likesFilter = _MetricFilter.none;
  _MetricFilter _savesFilter = _MetricFilter.none;
  _MetricFilter _sharesFilter = _MetricFilter.none;

  @override
  void initState() {
    super.initState();
    if (widget.category != null && widget.category!.isNotEmpty) {
      _selectedTags.add(widget.category!);
    }
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    try {
      final list = await _service.fetchCharacters(backend);
      if (!mounted) return;
      setState(() {
        _all = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e, backend));
    }
  }

  String _friendlyError(Object e, String backend) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused') ||
        s.contains('Connection timed out')) {
      return '无法连接后端 $backend';
    }
    if (s.contains('404')) return '角色卡不存在或已下架';
    if (s.contains('5')) {
      return '后端服务暂时不可用，请稍后重试';
    }
    return '加载失败，请稍后重试';
  }

  /// 从所有角色卡 tags 并集中按出现频次排序，取前 12 个
  List<String> get _allTags {
    final all = _all ?? const <OnlineCharacter>[];
    final freq = <String, int>{};
    for (final c in all) {
      for (final t in c.tags) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    final entries = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// 按 characterId hash 生成稳定的互动数 mock
  int _likesOf(OnlineCharacter c) => 120 + (c.id.hashCode.abs() % 5) * 87;
  int _savesOf(OnlineCharacter c) => 56 + (c.id.hashCode.abs() % 7) * 23;
  int _sharesOf(OnlineCharacter c) => 18 + (c.id.hashCode.abs() % 3) * 14;

  /// 应用全部筛选条件后的角色卡列表
  List<OnlineCharacter> get _filtered {
    final all = _all ?? const <OnlineCharacter>[];
    final q = _query.trim().toLowerCase();
    return all.where((c) {
      // 关键词
      if (q.isNotEmpty) {
        final name = c.name.toLowerCase();
        final desc = c.description.toLowerCase();
        if (!name.contains(q) && !desc.contains(q)) return false;
      }
      // 标签（AND：必须包含所有选中的）
      if (_selectedTags.isNotEmpty) {
        for (final t in _selectedTags) {
          if (!c.tags.contains(t)) return false;
        }
      }
      // 互动数
      if (!_likesFilter.applies(_likesOf(c))) return false;
      if (!_savesFilter.applies(_savesOf(c))) return false;
      if (!_sharesFilter.applies(_sharesOf(c))) return false;
      return true;
    }).toList();
  }

  int get _gridColumns => MediaQuery.of(context).size.width >= 720 ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        // 返回按钮
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        // 标题区改为搜索输入框 + 「搜索」按钮（用户要求一体化）
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: widget.category == null,
                onSubmitted: (_) => setState(() {}),
                style: TextStyle(color: scheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.category != null
                      ? '#${widget.category}'
                      : '搜索角色名或描述…',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.search,
                      size: 20, color: scheme.onSurfaceVariant),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close,
                              size: 18, color: scheme.onSurfaceVariant),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(width: 8),
            // 「搜索」按钮
            TavoBrand.gradientButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() => _query = _searchCtrl.text);
              },
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: const Text(
                '搜索',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        // 给 title 留足宽度，避免搜索框被挤压
        titleSpacing: 8,
      ),
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: () async => _load(),
        child: CustomScrollView(
          slivers: [
            _buildTagChips(scheme),
            _buildMetricFilters(scheme),
            _buildResultList(scheme),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 标签横向筛选条 + 下拉箭头（点箭头弹 bottom sheet 选全部标签）
  // ════════════════════════════════════════════════════

  Widget _buildTagChips(ColorScheme scheme) {
    final tags = _allTags;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Row(
          children: [
            // 左侧：横向 chips（全部可滚动）
            Expanded(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final tag = tags[i];
                    final selected = _selectedTags.contains(tag);
                    return _tagChip(
                      tag: tag,
                      selected: selected,
                      scheme: scheme,
                      onTap: () => _toggleTag(tag),
                    );
                  },
                ),
              ),
            ),
            // 右侧：下拉箭头按钮（点开 bottom sheet 全选面板）
            if (tags.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: _tagDropdownButton(scheme),
              )
            else
              const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _tagDropdownButton(ColorScheme scheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showTagBottomSheet(scheme),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedTags.isNotEmpty)
                Text(
                  '${_selectedTags.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TavoColors.violet,
                  ),
                )
              else
                Icon(
                  Icons.apps_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagChip({
    required String tag,
    required bool selected,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? TavoColors.violet
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? TavoColors.violet : scheme.outlineVariant,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          tag,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  /// 从底部弹出的标签全选面板（3 列网格 + 清除 + 确定）
  void _showTagBottomSheet(ColorScheme scheme) {
    // 临时备份，确定才写回
    Set<String> tempSelected = Set<String>.from(_selectedTags);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final tags = _allTags;
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    // 头部：下拉箭头 + 「标签」标题
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 24,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '标签',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          if (tempSelected.isNotEmpty)
                            Text(
                              '已选 ${tempSelected.length} 项',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: scheme.outlineVariant,
                    ),
                    // 中部：3 列标签网格
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.6,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: tags.length,
                        itemBuilder: (_, i) {
                          final tag = tags[i];
                          final selected = tempSelected.contains(tag);
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                if (selected) {
                                  tempSelected.remove(tag);
                                } else {
                                  tempSelected.add(tag);
                                }
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? TavoColors.violet
                                    : scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? TavoColors.violet
                                      : scheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 底部：「清除」 + 「确定」
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        children: [
                          // 清除
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () {
                                  setSheetState(() {
                                    tempSelected.clear();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: scheme.outlineVariant),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text('清除'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 确定
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 44,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.signGradient,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedTags
                                        ..clear()
                                        ..addAll(tempSelected);
                                    });
                                    Navigator.of(ctx).pop();
                                  },
                                  child: const Text(
                                    '确定',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════════════════════
  // 互动数筛选条：点赞 / 收藏 / 转发
  // ════════════════════════════════════════════════════

  Widget _buildMetricFilters(ColorScheme scheme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: _MetricDropdown(
                label: '点赞',
                icon: Icons.favorite_outline_rounded,
                value: _likesFilter,
                scheme: scheme,
                onChanged: (v) => setState(() => _likesFilter = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricDropdown(
                label: '收藏',
                icon: Icons.bookmark_outline_rounded,
                value: _savesFilter,
                scheme: scheme,
                onChanged: (v) => setState(() => _savesFilter = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricDropdown(
                label: '转发',
                icon: Icons.repeat_rounded,
                value: _sharesFilter,
                scheme: scheme,
                onChanged: (v) => setState(() => _sharesFilter = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 结果列表
  // ════════════════════════════════════════════════════

  Widget _buildResultList(ColorScheme scheme) {
    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _errorView(scheme),
      );
    }
    if (_all == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: TavoColors.violet),
        ),
      );
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _emptyView(scheme),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final c = filtered[i];
            return CharacterCoverCard(
              name: c.name,
              description: c.description,
              tags: c.tags,
              avatarUrl: c.avatarUrl,
              busy: _busyId == c.id,
              onTap: () => _openCharacter(context, c),
            );
          },
          childCount: filtered.length,
        ),
      ),
    );
  }

  Widget _errorView(ColorScheme scheme) {
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

  Widget _emptyView(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TavoBrand.emptyIllustration(Icons.search_off_rounded, size: 64),
          const SizedBox(height: 18),
          Text(
            '没有符合条件的角色卡',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
          if (_selectedTags.isNotEmpty ||
              _likesFilter != _MetricFilter.none ||
              _savesFilter != _MetricFilter.none ||
              _sharesFilter != _MetricFilter.none) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedTags.clear();
                  _likesFilter = _MetricFilter.none;
                  _savesFilter = _MetricFilter.none;
                  _sharesFilter = _MetricFilter.none;
                  _searchCtrl.clear();
                  _query = '';
                });
              },
              child: const Text('清除全部筛选'),
            ),
          ],
        ],
      ),
    );
  }

  /// 点击角色卡 → 跳转角色卡详情页
  void _openCharacter(BuildContext context, OnlineCharacter c) {
    context.push('/home/character/${Uri.encodeComponent(c.id)}');
  }
}

// ════════════════════════════════════════════════════
// 私有子组件
// ════════════════════════════════════════════════════

/// 互动数筛选项：不限 / 100+ / 500+ / 1k+ / 5k+
enum _MetricFilter {
  none('不限', 0),
  hundred('100+', 100),
  fiveHundred('500+', 500),
  oneK('1k+', 1000),
  fiveK('5k+', 5000);

  final String label;
  final int threshold;
  const _MetricFilter(this.label, this.threshold);

  bool applies(int value) {
    if (this == _MetricFilter.none) return true;
    return value >= threshold;
  }
}

class _MetricDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final _MetricFilter value;
  final ValueChanged<_MetricFilter> onChanged;
  final ColorScheme scheme;

  const _MetricDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: DropdownButton<_MetricFilter>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        isDense: true,
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            size: 18, color: scheme.onSurfaceVariant),
        style: TextStyle(
          fontSize: 12.5,
          color: scheme.onSurface,
        ),
        items: _MetricFilter.values
            .map((f) => DropdownMenuItem(
                  value: f,
                  child: Text('$label ${f.label}'),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

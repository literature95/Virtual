import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/character.dart';
import '../../models/conversation.dart';
import '../../models/lorebook.dart';
import '../../providers/character_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/app_image_cache.dart';
import '../../services/character_publish_service.dart';
import '../../utils/multi_select.dart';
import '../common/character_cover_card.dart';
import 'character_import_flow.dart';

/// 「角色」Tab —— 底部导航合并后的单入口页
///
/// 顶部分段切换：
///  - **角色**：角色库。三列卡片，展示立绘 / 名称 / 该角色最近一条对话内容。
///    **新建 / 文件导入 / URL 导入**的角色自动入架；首页在线卡需在详情页
///    点「加入角色库」才会出现。
///    **点卡片 = 直接进入对话**（有历史会话则续聊）；长按出菜单（详情 / 移出）。
///  - **历史**：会话历史。与首页一致的三列卡片网格（复用
///    [CharacterCoverCard]），长按仍可置顶 / 删除。在这里发起的会话
///    只出现在历史分段，不会回流进角色库。
///
/// 右上角 **⋮ 三点菜单**：角色管理 / 上传角色 / 创建角色
/// （新建 / 文件导入 / URL 导入三选一），创建与上传均只进**本地**角色库；
/// 上传是显式发布到后端数据库。
class CharacterTabPage extends StatefulWidget {
  const CharacterTabPage({super.key});

  @override
  State<CharacterTabPage> createState() => _CharacterTabPageState();
}

class _CharacterTabPageState extends State<CharacterTabPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  /// 多选模式（长按任一卡片进入）。仅对当前分段生效，切换分段自动退出。
  bool _selecting = false;
  MultiSelectState _selection = const MultiSelectState();
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.index != _lastTabIndex) {
        _lastTabIndex = _tab.index;
        _exitSelection();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chars = context.watch<CharacterProvider>();
    final chatProvider = context.watch<ChatProvider>();

    return PopScope(
      // 多选态拦截系统返回：先退出多选，再允许退页面
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _exitSelection();
      },
      child: Scaffold(
        appBar:
            _selecting ? _selectionAppBar(scheme) : _normalAppBar(scheme),
        body: TabBarView(
          controller: _tab,
          children: [
            _ShelfView(
              items: chars.shelfCharacters,
              selecting: _selecting,
              selection: _selection,
              onToggleSelect: _toggleSelection,
              onLongPress: _beginSelection,
            ),
            _HistoryView(
              items: sortedConversations(chatProvider.conversations),
              characters: chars.characters,
              selecting: _selecting,
              selection: _selection,
              onToggleSelect: _toggleSelection,
              onLongPress: _beginSelection,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _normalAppBar(ColorScheme scheme) {
    return AppBar(
      // ── 单行顶部：左「角色|历史」分段 + 右「搜索 / ⋮」──
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      // 分段条自带 8+8 padding 与边框，需要比默认 56 略高才不会挤压
      toolbarHeight: 58,
      title: _segmentBar(scheme),
      actions: [
        IconButton(
          tooltip: '搜索角色',
          onPressed: () => context.push('/home/search'),
          icon: Icon(Icons.search_rounded, color: scheme.onSurface),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: scheme.onSurface),
          tooltip: '更多操作',
          onSelected: (value) {
            switch (value) {
              case 'manage':
                context.push('/character/manage');
                break;
              case 'upload':
                _showPublishSheet();
                break;
              case 'create':
                _showCreateSheet();
                break;
            }
          },
          itemBuilder: (_) => [
            _menuItem(Icons.view_list_outlined, '角色管理', 'manage'),
            _menuItem(Icons.cloud_upload_outlined, '上传角色', 'upload'),
            _menuItem(Icons.add, '创建角色', 'create'),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// 多选操作栏：已选 N 项 + 全选 / 置顶 / 删除 / 取消
  PreferredSizeWidget _selectionAppBar(ColorScheme scheme) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      toolbarHeight: 58,
      title: Text(
        '已选 ${_selection.count} 项',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      actions: [
        _barButton('全选', _selectAll),
        _barButton('置顶', _pinSelected),
        _barButton('删除', _deleteSelected, color: scheme.error),
        _barButton('取消', _exitSelection),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _barButton(String label, VoidCallback onPressed, {Color? color}) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  /// 当前分段全部条目的 id（全选与批量操作都以它为准）
  List<String> _activeItemIds() {
    if (_tab.index == 0) {
      return context
          .read<CharacterProvider>()
          .shelfCharacters
          .map((c) => c.id)
          .toList();
    }
    return context
        .read<ChatProvider>()
        .conversations
        .map((c) => c.id)
        .toList();
  }

  void _beginSelection(String id) {
    setState(() {
      _selecting = true;
      _selection = MultiSelectState({id});
    });
  }

  void _toggleSelection(String id) {
    setState(() => _selection = _selection.toggle(id));
  }

  void _exitSelection() {
    if (!_selecting) return;
    setState(() {
      _selecting = false;
      _selection = const MultiSelectState();
    });
  }

  void _selectAll() {
    setState(() => _selection = _selection.selectAll(_activeItemIds()));
  }

  Future<void> _pinSelected() async {
    final ids = _selection.selected;
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_tab.index == 0) {
      final chars = context.read<CharacterProvider>();
      var applied = 0;
      for (final id in ids) {
        final c = chars.getCharacter(id);
        if (c == null) continue; // 已删除/失效的条目忽略
        if (!c.isPinned) {
          await chars.updateCharacter(c.copyWith(isPinned: true));
        }
        applied++;
      }
      _exitSelection();
      messenger.showSnackBar(SnackBar(
        content: Text(applied == ids.length
            ? '已置顶 $applied 个角色'
            : '已置顶 $applied 项，${ids.length - applied} 项已失效，已忽略'),
      ));
    } else {
      final chat = context.read<ChatProvider>();
      var applied = 0;
      for (final id in ids) {
        if (chat.conversations.any((c) => c.id == id)) {
          chat.pinConversation(id, true);
          applied++;
        }
      }
      _exitSelection();
      messenger.showSnackBar(SnackBar(
        content: Text(applied == ids.length
            ? '已置顶 $applied 条对话'
            : '已置顶 $applied 项，${ids.length - applied} 项已失效，已忽略'),
      ));
    }
  }

  Future<void> _deleteSelected() async {
    final ids = _selection.selected;
    if (ids.isEmpty) return;
    final isShelf = _tab.index == 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isShelf ? '删除角色' : '删除对话'),
        content: Text(isShelf
            ? '要从本地删除所选的 ${ids.length} 个角色吗？\n角色卡数据将被移除，此操作不可撤销。'
            : '要删除所选的 ${ids.length} 条对话记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child:
                Text('删除', style: TextStyle(color: Theme.of(dialogCtx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (isShelf) {
      final chars = context.read<CharacterProvider>();
      for (final id in ids) {
        chars.deleteCharacter(id);
      }
    } else {
      final chat = context.read<ChatProvider>();
      for (final id in ids) {
        chat.deleteConversation(id);
      }
    }
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 ${ids.length} ${isShelf ? '个角色' : '条对话'}')),
    );
  }

  PopupMenuItem<String> _menuItem(IconData icon, String label, String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  /// 右上角 `+`：三选一创建入口，全部只落**本地**角色库（不上传后端）
  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '创建角色卡',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: const Text('新建角色'),
              subtitle: const Text('从头开始，创建一个角色'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.push('/character/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('从文件导入角色卡'),
              subtitle: const Text('支持 JSON 或 PNG 文件，自动识别格式'),
              onTap: () {
                Navigator.pop(sheetCtx);
                CharacterImportFlow.importFromFile(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('从 URL 导入角色卡'),
              subtitle: const Text('粘贴社区角色站的文件直链，自动识别导入'),
              onTap: () {
                Navigator.pop(sheetCtx);
                CharacterImportFlow.importFromUrl(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 右上角上传：选一张本地角色卡发布到后端数据库（POST /api/characters）
  void _showPublishSheet() {
    final chars = context.read<CharacterProvider>().characters;
    if (chars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地还没有角色卡，先创建或导入一张吧')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '选择要上传到后端的角色卡',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: chars.length,
                itemBuilder: (_, i) {
                  final c = chars[i];
                  final avatar = AppImageCache.providerFor(
                    c.avatarPath,
                    decodeWidth: 160,
                  );
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar,
                      child:
                          avatar == null ? Text(c.name.characters.first) : null,
                    ),
                    title: Text(c.name),
                    subtitle: Text(
                      [
                        if (c.characterVersion?.isNotEmpty ?? false)
                          'v${c.characterVersion}',
                        if (c.creator?.isNotEmpty ?? false) 'by ${c.creator}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _publishCard(sheetCtx, c),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 发布单张卡：世界书随卡上送，成功后关掉菜单并提示结果
  Future<void> _publishCard(BuildContext sheetCtx, Character c) async {
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    final navigator = Navigator.of(sheetCtx);
    final messenger = ScaffoldMessenger.of(sheetCtx);

    // 世界书随卡上送（本地按 lorebookId 关联的那本）
    Lorebook? book;
    if (c.lorebookId != null) {
      for (final lb in AppDatabase.instance.getLorebooks()) {
        if (lb.id == c.lorebookId) {
          book = lb;
          break;
        }
      }
    }

    // 加载态：关不掉的转圈，发布完成/失败后再关
    showDialog<void>(
      context: sheetCtx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await CharacterPublishService()
          .publish(c, backend: backend, lorebook: book);
      navigator.pop(); // loading
      navigator.pop(); // sheet
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '已${result.created ? '上传' : '覆盖更新'}「${c.name}」到后端'
            '（${result.id} v${result.characterVersion}）',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      navigator.pop(); // loading
      messenger.showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
  }

  /// 顶部分段切换（角色 / 历史）—— 放在 AppBar 内，占满左侧可达区
  Widget _segmentBar(ColorScheme scheme) {
    return Row(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _segmentItem(
              scheme: scheme,
              index: i,
              label: ['角色', '历史'][i],
            ),
          ),
        ],
      ],
    );
  }

  Widget _segmentItem({
    required ColorScheme scheme,
    required int index,
    required String label,
  }) {
    final selected = _tab.index == index;
    return GestureDetector(
      onTap: () {
        _tab.animateTo(index);
        setState(() {});
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 角色库 ────────────────────────────────────────────────

class _ShelfView extends StatelessWidget {
  final List<Character> items;
  final bool selecting;
  final MultiSelectState selection;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onLongPress;

  const _ShelfView({
    required this.items,
    required this.selecting,
    required this.selection,
    required this.onToggleSelect,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chat = context.watch<ChatProvider>();

    if (items.isEmpty) {
      return _emptyShelf(context, scheme);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final c = items[i];
        final preview =
            (chat.latestConversationOf(c.id)?.lastMessagePreview ?? '').trim();
        return CharacterCoverCard(
          style: CharacterCoverCardStyle.below,
          name: c.name,
          description: preview.isEmpty ? '点按开始对话' : preview,
          avatarUrl: c.avatarPath,
          selectionMode: selecting,
          selected: selection.contains(c.id),
          // 多选态：点卡片 = 切换选中；平时点卡片 = 开始/继续对话
          onTap: selecting
              ? () => onToggleSelect(c.id)
              : () => openOrStartChat(context, c),
          onLongPress: () => onLongPress(c.id),
        );
      },
    );
  }

  /// 空角色库：明确告知「需从角色卡详情页加入」
  Widget _emptyShelf(BuildContext context, ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories_outlined,
                  size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 18),
              Text(
                '角色库还是空的',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '去「首页」找到喜欢的角色卡，\n进入详情页点「加入角色库」即可收录到这里。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: const Text('去发现角色'),
              ),
            ],
          ),
        ),
      );

}

/// 打开角色对话：有历史会话就续聊，否则新建一条空会话。
///
/// 角色库与历史两处共用。用 `chat.latestConversationOf` 而不是无脑新建 ——
/// 否则重复点同一张卡会攒出一串空对话。
///
/// 路由与 Messenger 都在 `await` 之前取出：既避免
/// `use_build_context_synchronously` 告警，也保证失败时还能弹出提示。
Future<void> openOrStartChat(BuildContext context, Character c) async {
  final chat = context.read<ChatProvider>();
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final existing = chat.latestConversationOf(c.id);
    if (existing != null) {
      router.push('/chat/${existing.id}');
      return;
    }
    final conv = await chat.createConversation(characterId: c.id);
    router.push('/chat/${conv.id}');
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('无法打开对话：$e')),
    );
  }
}

// ── 历史（会话列表复用）──────────────────────────────────────

class _HistoryView extends StatelessWidget {
  final List<Conversation> items;
  final List<Character> characters;
  final bool selecting;
  final MultiSelectState selection;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onLongPress;

  const _HistoryView({
    required this.items,
    required this.characters,
    required this.selecting,
    required this.selection,
    required this.onToggleSelect,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _HistoryEmpty();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final conv = items[i];
        final char = _characterOf(characters, conv.characterId);
        return CharacterCoverCard(
          // 与「角色」分段统一：图片在上、标题与描述在图下
          style: CharacterCoverCardStyle.below,
          name: conv.title,
          description: conv.lastMessagePreview?.isNotEmpty == true
              ? conv.lastMessagePreview!
              : (conv.lastMessageAt != null
                  ? _formatTimeFrom(conv.lastMessageAt!)
                  : '开始新对话'),
          avatarUrl: char?.avatarPath,
          selectionMode: selecting,
          selected: selection.contains(conv.id),
          onTap: selecting
              ? () => onToggleSelect(conv.id)
              : () => context.push('/chat/${conv.id}'),
          onLongPress: () => onLongPress(conv.id),
        );
      },
    );
  }

  Character? _characterOf(List<Character> all, String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// 会话排序：置顶优先，其次按最近消息 / 更新时间倒序
///
/// 纯函数，页面与「历史」分段共用；多选模式的「全选」也按同一顺序取 id。
List<Conversation> sortedConversations(List<Conversation> all) {
  final list = List<Conversation>.from(all);
  list.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final ta = a.lastMessageAt ?? a.updatedAt;
    final tb = b.lastMessageAt ?? b.updatedAt;
    return tb.compareTo(ta);
  });
  return list;
}

// ── 历史空态 ───────────────────────────────────────────────

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined,
                size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 18),
            Text('还没有对话记录',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text('点「角色」分段挑一张卡，开始第一段对话吧。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// 相对时间格式化（历史卡片缺 lastMessagePreview 时用）
String _formatTimeFrom(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return '${time.month}/${time.day}';
}

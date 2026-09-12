import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../models/conversation.dart';
import '../../providers/character_provider.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_list_page.dart' show ConversationListView;
import '../common/character_cover_card.dart' show resolveAvatarImage;

/// 「角色」Tab —— 底部导航合并后的单入口页
///
/// 顶部分段切换：
///  - **角色**：角色库。三列卡片，展示立绘 / 名称 / 该角色最近一条对话内容。
///    角色库**默认空白** —— 只有用户在角色卡详情页点「加入角色库」才会出现。
///  - **历史**：会话历史（复用 [ConversationListView]）。在这里发起的会话
///    只出现在历史分段，不会回流进角色库。
///  - **收藏**：预留分段位（复用角色卡既有 `isFavorite` 字段）。
///
/// 右上角 `+`：新建角色卡。
class CharacterTabPage extends StatefulWidget {
  const CharacterTabPage({super.key});

  @override
  State<CharacterTabPage> createState() => _CharacterTabPageState();
}

class _CharacterTabPageState extends State<CharacterTabPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _query = '';
  bool _searchVisible = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        // ── 单行顶部：左「角色|历史|收藏」分段 + 右「搜索/加号」 ──
        // 不再单独放标题「角色」——它与第一个分段标签重复。
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        // 分段条自带 8+8 padding 与边框，需要比默认 56 略高才不会挤压
        toolbarHeight: 58,
        title: _segmentBar(scheme),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            tooltip: _searchVisible ? '关闭搜索' : '搜索',
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchCtrl.clear();
                  _query = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建角色卡',
            onPressed: () => context.push('/character/new'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: _searchVisible
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '搜索角色 / 对话…',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              )
            : null,
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ShelfView(query: _query),
          _HistoryView(query: _query),
          _FavoriteView(query: _query),
        ],
      ),
    );
  }

  /// 顶部分段切换（角色 / 历史 / 收藏）—— 放在 AppBar 内，占满左侧可达区
  Widget _segmentBar(ColorScheme scheme) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _segmentItem(
              scheme: scheme,
              index: i,
              label: ['角色', '历史', '收藏'][i],
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
  final String query;
  const _ShelfView({required this.query});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chars = context.watch<CharacterProvider>();
    final chat = context.watch<ChatProvider>();

    var shelf = chars.shelfCharacters;
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      shelf = shelf
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }

    if (shelf.isEmpty) {
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
      itemCount: shelf.length,
      itemBuilder: (_, i) => _ShelfCard(
        character: shelf[i],
        lastMessage: chat.latestConversationOf(shelf[i].id)?.lastMessagePreview,
        onOpen: () => context.push(
            '/home/character/${Uri.encodeComponent(shelf[i].id)}'),
        onChat: () => _openOrStartChat(context, shelf[i]),
        onRemove: () => chars.removeFromShelf(shelf[i].id),
      ),
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

  /// 点卡片正文：有历史会话就续聊，否则新建
  Future<void> _openOrStartChat(BuildContext context, Character c) async {
    final chat = context.read<ChatProvider>();
    final existing = chat.latestConversationOf(c.id);
    if (existing != null) {
      context.go('/chat/${existing.id}');
      return;
    }
    final conv = await chat.createConversation(characterId: c.id);
    if (context.mounted) context.go('/chat/${conv.id}');
  }
}

/// 角色库单卡：立绘 + 名称 + 最近对话内容
class _ShelfCard extends StatelessWidget {
  final Character character;
  final String? lastMessage;
  final VoidCallback onOpen;
  final VoidCallback onChat;
  final VoidCallback onRemove;

  const _ShelfCard({
    required this.character,
    required this.lastMessage,
    required this.onOpen,
    required this.onChat,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = resolveAvatarImage(character.avatarPath);
    final preview = (lastMessage ?? '').trim();

    return InkWell(
      onTap: onOpen,
      onLongPress: () => _menu(context, scheme),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 立绘（竖版 3:4）
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  color: scheme.surfaceContainerHigh,
                  child: img != null
                      ? Image(image: img, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            character.name.isNotEmpty
                                ? character.name.characters.first
                                : '?',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          // 名称
          Text(
            character.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          // 最近对话内容
          GestureDetector(
            onTap: onChat,
            child: Text(
              preview.isEmpty ? '未开始对话' : preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: preview.isEmpty
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _menu(BuildContext context, ColorScheme scheme) {
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
                character.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('开始 / 继续对话'),
              onTap: () {
                Navigator.pop(sheetCtx);
                onChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看角色卡详情'),
              onTap: () {
                Navigator.pop(sheetCtx);
                onOpen();
              },
            ),
            ListTile(
              leading: Icon(Icons.bookmark_remove_outlined,
                  color: scheme.error),
              title: Text('移出角色库', style: TextStyle(color: scheme.error)),
              onTap: () {
                Navigator.pop(sheetCtx);
                onRemove();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 历史（会话列表复用）──────────────────────────────────────

class _HistoryView extends StatefulWidget {
  final String query;
  const _HistoryView({required this.query});

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  List<Conversation> _sorted(List<Conversation> all) {
    final q = widget.query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<Conversation>.from(all)
        : all
            .where((c) =>
                c.title.toLowerCase().contains(q) ||
                (c.lastMessagePreview ?? '').toLowerCase().contains(q))
            .toList();
    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final ta = a.lastMessageAt ?? a.updatedAt;
      final tb = b.lastMessageAt ?? b.updatedAt;
      return tb.compareTo(ta);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return ConversationListView(
      query: widget.query,
      sorted: _sorted,
      onShowMenu: _showMenu,
    );
  }

  void _showMenu(BuildContext context, Conversation conv) {
    final chat = context.read<ChatProvider>();
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
              child: Text(conv.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: Icon(conv.isPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin),
              title: Text(conv.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                Navigator.pop(sheetCtx);
                chat.pinConversation(conv.id, !conv.isPinned);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(sheetCtx).colorScheme.error),
              title: Text('删除',
                  style: TextStyle(
                      color: Theme.of(sheetCtx).colorScheme.error)),
              onTap: () {
                Navigator.pop(sheetCtx);
                chat.deleteConversation(conv.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 收藏（占位）──────────────────────────────────────────────

class _FavoriteView extends StatelessWidget {
  final String query;
  const _FavoriteView({required this.query});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chars = context.watch<CharacterProvider>();
    var favs = chars.favorites;
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      favs = favs.where((c) => c.name.toLowerCase().contains(q)).toList();
    }

    if (favs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_border,
                  size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 18),
              Text('还没有收藏的角色',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface)),
              const SizedBox(height: 8),
              Text('在角色卡上点亮星标后会出现在这里。',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.62,
      ),
      itemCount: favs.length,
      itemBuilder: (_, i) => _ShelfCard(
        character: favs[i],
        lastMessage:
            context.read<ChatProvider>().latestConversationOf(favs[i].id)?.lastMessagePreview,
        onOpen: () =>
            context.push('/home/character/${Uri.encodeComponent(favs[i].id)}'),
        onChat: () {
          final chat = context.read<ChatProvider>();
          final existing = chat.latestConversationOf(favs[i].id);
          if (existing != null) {
            context.go('/chat/${existing.id}');
          } else {
            chat.createConversation(characterId: favs[i].id).then((c) {
              if (context.mounted) context.go('/chat/${c.id}');
            });
          }
        },
        onRemove: () => context.read<CharacterProvider>().toggleFavorite(favs[i].id),
      ),
    );
  }
}

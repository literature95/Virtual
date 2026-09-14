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
import '../../services/character_publish_service.dart';
import '../chat/chat_list_page.dart' show ConversationListView;
import '../common/character_cover_card.dart' show resolveAvatarImage;
import 'character_import_flow.dart';

/// 「角色」Tab —— 底部导航合并后的单入口页
///
/// 顶部分段切换：
///  - **角色**：角色库。三列卡片，展示立绘 / 名称 / 该角色最近一条对话内容。
///    **新建 / 文件导入 / URL 导入**的角色自动入架；首页在线卡需在详情页
///    点「加入角色库」才会出现。
///    **点卡片 = 直接进入对话**（有历史会话则续聊）；长按出菜单（详情 / 移出）。
///  - **历史**：会话历史（复用 [ConversationListView]）。在这里发起的会话
///    只出现在历史分段，不会回流进角色库。
///  - **收藏**：预留分段位（复用角色卡既有 `isFavorite` 字段）。
///
/// 右上角 `+`：三选一创建（新建 / 文件导入 / URL 导入），均只进**本地**角色库。
/// 右上角上传：把本地角色卡显式发布到后端数据库。
class CharacterTabPage extends StatefulWidget {
  const CharacterTabPage({super.key});

  @override
  State<CharacterTabPage> createState() => _CharacterTabPageState();
}

class _CharacterTabPageState extends State<CharacterTabPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        // ── 单行顶部：左「角色|历史|收藏」分段 + 右「上传/加号」 ──
        // 不再单独放标题「角色」——它与第一个分段标签重复。
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        // 分段条自带 8+8 padding 与边框，需要比默认 56 略高才不会挤压
        toolbarHeight: 58,
        title: _segmentBar(scheme),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_list_outlined),
            tooltip: '管理全部角色（含未入架的本地卡）',
            onPressed: () => context.push('/character/manage'),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: '上传到后端',
            onPressed: _showPublishSheet,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建角色卡',
            onPressed: _showCreateSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _ShelfView(query: ''),
          _HistoryView(query: ''),
          _FavoriteView(query: ''),
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
                  final avatar = resolveAvatarImage(c.avatarPath);
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
        onDelete: (c) => _confirmDelete(context, chars, c),
      ),
    );
  }

  /// 彻底删除确认框：与「移出角色库」明确区分——删除会从本地移除角色卡
  void _confirmDelete(
      BuildContext context, CharacterProvider chars, Character character) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('彻底删除角色'),
        content: Text(
          '确定要从本地删除角色「${character.name}」吗？\n角色卡数据将被移除，此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              chars.deleteCharacter(character.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
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
  Future<void> _openOrStartChat(BuildContext context, Character c) =>
      openOrStartChat(context, c);
}

/// 打开角色对话：有历史会话就续聊，否则新建一条空会话。
///
/// 角色库与收藏两处共用。用 `chat.latestConversationOf` 而不是无脑新建 ——
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

/// 角色库单卡：立绘 + 名称 + 最近对话内容
///
/// **点击整卡 = 进入对话**（用户要求「角色库里点角色卡就是对话」）。
/// 此前 `onTap` 绑的是「查看角色卡详情」，只有最后一行 11px 的预览文字
/// 才绑了对话 —— 点按区极小，实际几乎点不到。
/// 现在：「查看角色卡详情」「移出角色库」都在长按菜单里。
class _ShelfCard extends StatelessWidget {
  final Character character;
  final String? lastMessage;
  final VoidCallback onOpen;
  final VoidCallback onChat;

  /// 菜单里的「轻移除」动作：角色库=移出角色库，收藏页=取消收藏
  final VoidCallback onRemove;
  final String removeLabel;

  /// 菜单里的「彻底删除」动作（带确认）；null 则不显示该项
  final void Function(Character character)? onDelete;

  const _ShelfCard({
    required this.character,
    required this.lastMessage,
    required this.onOpen,
    required this.onChat,
    required this.onRemove,
    this.removeLabel = '移出角色库',
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = resolveAvatarImage(character.avatarPath);
    final preview = (lastMessage ?? '').trim();

    return InkWell(
      // 整卡直达对话（有历史会话续聊，否则新建）
      onTap: onChat,
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
          // 最近对话内容（点按由整卡接管，不再单独嵌套手势）
          Text(
            preview.isEmpty ? '点按开始对话' : preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: preview.isEmpty
                  ? scheme.primary.withValues(alpha: 0.85)
                  : scheme.onSurfaceVariant,
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
            // 整卡点击已是「进入对话」，菜单里改把详情放第一位
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看角色卡详情'),
              onTap: () {
                Navigator.pop(sheetCtx);
                onOpen();
              },
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
              leading: Icon(Icons.bookmark_remove_outlined,
                  color: scheme.error),
              title: Text(removeLabel, style: TextStyle(color: scheme.error)),
              onTap: () {
                Navigator.pop(sheetCtx);
                onRemove();
              },
            ),
            if (onDelete != null)
              ListTile(
                leading:
                    Icon(Icons.delete_forever_outlined, color: scheme.error),
                title: Text('彻底删除角色',
                    style: TextStyle(color: scheme.error)),
                subtitle: Text('从本地删除角色卡，不可恢复',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onDelete!(character);
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
        onChat: () => openOrStartChat(context, favs[i]),
        onRemove: () => context.read<CharacterProvider>().toggleFavorite(favs[i].id),
        removeLabel: '取消收藏',
      ),
    );
  }
}

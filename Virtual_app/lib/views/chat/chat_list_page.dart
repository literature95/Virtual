import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../models/character.dart';
import '../../models/conversation.dart';
import '../../providers/chat_provider.dart';
import '../../providers/character_provider.dart';
import '../../theme/tavo_brand.dart';

/// 开始一段新聊天：
/// 1. 若无角色，引导先创建角色；
/// 2. 否则弹出角色选择，选完即创建会话并进入聊天页。
Future<void> _startNewChat(BuildContext context) async {
  final characters = context.read<CharacterProvider>().characters;
  if (characters.isEmpty) {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('先创建一个角色'),
        content: const Text('开始聊天前，请先创建一个角色卡。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去创建角色'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) context.go('/character/new');
    return;
  }

  final chat = context.read<ChatProvider>();
  final chosen = await showModalBottomSheet<Character>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CharacterPicker(characters: characters),
  );
  if (chosen != null && context.mounted) {
    final conv = await chat.createConversation(characterId: chosen.id);
    if (context.mounted) context.go('/chat/${conv.id}');
  }
}

/// 会话列表页：搜索 + 置顶排序 + 长按菜单（重命名/置顶/删除）
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _searchVisible = false;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  /// 置顶排前 + 过滤
  List<Conversation> _sorted(List<Conversation> all) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<Conversation>.from(all)
        : all.where((c) => c.title.toLowerCase().contains(q)).toList();
    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final at = a.lastMessageAt ?? a.updatedAt;
      final bt = b.lastMessageAt ?? b.updatedAt;
      return bt.compareTo(at);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: TavoBrand.logo(size: 34),
        ),
        title: _searchVisible
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '搜索对话…',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : TavoBrand.gradientText('Virtual', fontSize: 22),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
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
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final conversations = _sorted(chatProvider.conversations);
          if (chatProvider.conversations.isEmpty) {
            return const _EmptyState();
          }
          if (conversations.isEmpty) {
            return const Center(
              child: Text(
                '没有匹配的对话',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(conv.title.characters.first),
                ),
                title: Text(conv.title),
                subtitle: Text(
                  conv.lastMessageAt != null
                      ? _formatTime(conv.lastMessageAt!)
                      : '开始新对话',
                ),
                trailing:
                    conv.isPinned ? const Icon(Icons.push_pin, size: 16) : null,
                onTap: () => context.go('/chat/${conv.id}'),
                onLongPress: () => _showConversationMenu(context, conv),
              );
            },
          );
        },
      ),
      floatingActionButton: TavoBrand.fab(
        onPressed: () => _startNewChat(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 长按菜单：重命名 / 置顶 / 删除
  void _showConversationMenu(BuildContext context, Conversation conv) {
    final chat = context.read<ChatProvider>();
    showModalBottomSheet(
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
                conv.title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _renameDialog(context, chat, conv);
              },
            ),
            ListTile(
              leading: Icon(
                conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(conv.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                Navigator.pop(sheetCtx);
                chat.pinConversation(conv.id, !conv.isPinned);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDelete(context, chat, conv);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameDialog(
      BuildContext context, ChatProvider chat, Conversation conv) {
    final ctrl = TextEditingController(text: conv.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入新名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              chat.renameConversation(conv.id, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, ChatProvider chat, Conversation conv) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除「${conv.title}」吗？所有聊天记录将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              chat.deleteConversation(conv.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 官方空状态插画
            Image.asset(
              'assets/images/empty_state_conversation.png',
              width: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.chat_bubble_outline_outlined,
                size: 64,
                color: Colors.grey[350],
              ),
            ),
            const SizedBox(height: 20),
            // 创建聊天按钮
            OutlinedButton.icon(
              onPressed: () => _startNewChat(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('创建聊天', style: TextStyle(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[600],
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 选择角色的底部抽屉
class _CharacterPicker extends StatelessWidget {
  final List<Character> characters;

  const _CharacterPicker({required this.characters});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '选择角色开始聊天',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: characters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = characters[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(c.name.characters.first)),
                  title: Text(c.name),
                  subtitle: c.description != null && c.description!.isNotEmpty
                      ? Text(
                          c.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

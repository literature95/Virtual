import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../models/character.dart';
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

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: TavoBrand.logo(size: 34),
        ),
        title: TavoBrand.gradientText('Virtual', fontSize: 22),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 搜索
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          if (chatProvider.conversations.isEmpty) {
            return const _EmptyState();
          }
          return ListView.builder(
            itemCount: chatProvider.conversations.length,
            itemBuilder: (context, index) {
              final conv = chatProvider.conversations[index];
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
                trailing: conv.isPinned
                    ? const Icon(Icons.push_pin, size: 16)
                    : null,
                onTap: () => context.go('/chat/${conv.id}'),
                onLongPress: () {
                  // TODO: 长按菜单
                },
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

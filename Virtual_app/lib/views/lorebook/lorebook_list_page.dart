import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/lorebook.dart';

class LorebookListPage extends StatefulWidget {
  const LorebookListPage({super.key});

  @override
  State<LorebookListPage> createState() => _LorebookListPageState();
}

class _LorebookListPageState extends State<LorebookListPage> {
  List<Lorebook> _lorebooks = [];

  @override
  void initState() {
    super.initState();
    _loadLorebooks();
  }

  void _loadLorebooks() {
    final db = context.read<AppDatabase>();
    setState(() {
      _lorebooks = db.getLorebooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lorebook 管理'),
      ),
      body: _lorebooks.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lorebooks.length,
              itemBuilder: (context, index) {
                final lorebook = _lorebooks[index];
                return _LorebookTile(
                  lorebook: lorebook,
                  onTap: () => context.push('/lorebook/${lorebook.id}/edit'),
                  onDelete: () => _confirmDelete(lorebook),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createLorebook(),
        icon: const Icon(Icons.add),
        label: const Text('新建 Lorebook'),
      ),
    );
  }

  Future<void> _createLorebook() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建 Lorebook'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Lorebook 名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final db = context.read<AppDatabase>();
      final now = DateTime.now();
      final lorebook = Lorebook(
        id: db.newUuid(),
        name: result,
        entries: [],
        createdAt: now,
        updatedAt: now,
      );
      await db.saveLorebook(lorebook);
      _loadLorebooks();
      if (mounted) {
        context.push('/lorebook/${lorebook.id}/edit');
      }
    }
  }

  void _confirmDelete(Lorebook lorebook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 Lorebook'),
        content: Text(
            '确定要删除「${lorebook.name}」吗？其中的 ${lorebook.entries.length} 个条目也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = context.read<AppDatabase>();
              await db.deleteLorebook(lorebook.id);
              _loadLorebooks();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _LorebookTile extends StatelessWidget {
  final Lorebook lorebook;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LorebookTile({
    required this.lorebook,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final enabledCount = lorebook.entries.where((e) => e.enabled).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: lorebook.enabled
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.book,
            color: lorebook.enabled
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(lorebook.name)),
            if (!lorebook.enabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('已禁用', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
        subtitle: Text('${lorebook.entries.length} 个条目（$enabledCount 个启用）'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              tooltip: '删除',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有 Lorebook',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '创建一个 Lorebook 来管理世界知识和角色设定',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

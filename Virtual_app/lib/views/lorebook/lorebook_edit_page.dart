import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/lorebook.dart';

class LorebookEditPage extends StatefulWidget {
  final String lorebookId;

  const LorebookEditPage({super.key, required this.lorebookId});

  @override
  State<LorebookEditPage> createState() => _LorebookEditPageState();
}

class _LorebookEditPageState extends State<LorebookEditPage> {
  Lorebook? _lorebook;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLorebook();
  }

  void _loadLorebook() {
    final db = context.read<AppDatabase>();
    final lorebooks = db.getLorebooks();
    try {
      _lorebook = lorebooks.firstWhere((l) => l.id == widget.lorebookId);
    } catch (_) {
      _lorebook = null;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveLorebook() async {
    if (_lorebook == null) return;
    final db = context.read<AppDatabase>();
    final updated = _lorebook!.copyWith(updatedAt: DateTime.now());
    await db.saveLorebook(updated);
    _lorebook = updated;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _addEntry() async {
    if (_lorebook == null) return;
    final entry = await _showEntryDialog(null);
    if (entry != null) {
      final entries = List<LorebookEntry>.from(_lorebook!.entries)..add(entry);
      setState(() {
        _lorebook = _lorebook!.copyWith(entries: entries);
      });
      await _saveLorebook();
    }
  }

  Future<void> _editEntry(int index) async {
    if (_lorebook == null) return;
    final entry = await _showEntryDialog(_lorebook!.entries[index]);
    if (entry != null) {
      final entries = List<LorebookEntry>.from(_lorebook!.entries);
      entries[index] = entry;
      setState(() {
        _lorebook = _lorebook!.copyWith(entries: entries);
      });
      await _saveLorebook();
    }
  }

  void _deleteEntry(int index) {
    if (_lorebook == null) return;
    final entries = List<LorebookEntry>.from(_lorebook!.entries)
      ..removeAt(index);
    setState(() {
      _lorebook = _lorebook!.copyWith(entries: entries);
    });
    _saveLorebook();
  }

  void _moveEntry(int index, bool up) {
    if (_lorebook == null) return;
    final newIndex = up ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= _lorebook!.entries.length) return;
    final entries = List<LorebookEntry>.from(_lorebook!.entries);
    final item = entries.removeAt(index);
    entries.insert(newIndex, item);
    setState(() {
      _lorebook = _lorebook!.copyWith(entries: entries);
    });
    _saveLorebook();
  }

  Future<LorebookEntry?> _showEntryDialog(LorebookEntry? existing) async {
    final keyController = TextEditingController(text: existing?.key ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    final secondaryKeysController = TextEditingController(
      text: existing?.secondaryKeys.join(', ') ?? '',
    );
    LorebookEntryMatchStrategy strategy =
        existing?.matchStrategy ?? LorebookEntryMatchStrategy.partial;
    LorebookEntryPosition position =
        existing?.position ?? LorebookEntryPosition.bottom;
    bool caseSensitive = existing?.caseSensitive ?? false;

    final result = await showDialog<LorebookEntry>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '添加条目' : '编辑条目'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: keyController,
                    decoration: const InputDecoration(
                      labelText: '关键词 *',
                      border: OutlineInputBorder(),
                      hintText: '触发关键词，多个用逗号分隔',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: secondaryKeysController,
                    decoration: const InputDecoration(
                      labelText: '附加关键词（可选）',
                      border: OutlineInputBorder(),
                      hintText: '必须同时匹配的关键词',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    minLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: '注入内容 *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      hintText: '匹配后注入到提示词的内容',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LorebookEntryMatchStrategy>(
                    initialValue: strategy,
                    decoration: const InputDecoration(
                      labelText: '匹配策略',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: LorebookEntryMatchStrategy.partial,
                        child: Text('部分匹配'),
                      ),
                      DropdownMenuItem(
                        value: LorebookEntryMatchStrategy.exact,
                        child: Text('精确匹配'),
                      ),
                      DropdownMenuItem(
                        value: LorebookEntryMatchStrategy.regex,
                        child: Text('正则匹配'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => strategy = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LorebookEntryPosition>(
                    initialValue: position,
                    decoration: const InputDecoration(
                      labelText: '注入位置',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: LorebookEntryPosition.top, child: Text('最前')),
                      DropdownMenuItem(
                          value: LorebookEntryPosition.bottom,
                          child: Text('最后')),
                      DropdownMenuItem(
                          value: LorebookEntryPosition.beforeSystem,
                          child: Text('系统提示前')),
                      DropdownMenuItem(
                          value: LorebookEntryPosition.afterSystem,
                          child: Text('系统提示后')),
                      DropdownMenuItem(
                          value: LorebookEntryPosition.beforeUser,
                          child: Text('用户消息前')),
                      DropdownMenuItem(
                          value: LorebookEntryPosition.afterUser,
                          child: Text('用户消息后')),
                      DropdownMenuItem(
                          value: LorebookEntryPosition.beforeAssistant,
                          child: Text('助手回复前')),
                      DropdownMenuItem(
                          value: LorebookEntryPosition.afterAssistant,
                          child: Text('助手回复后')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => position = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('大小写敏感'),
                    value: caseSensitive,
                    onChanged: (v) => setDialogState(() => caseSensitive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final key = keyController.text.trim();
                final content = contentController.text.trim();
                if (key.isEmpty || content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写关键词和注入内容')),
                  );
                  return;
                }
                final secondaryKeys = secondaryKeysController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                Navigator.pop(
                  context,
                  (existing ??
                          LorebookEntry(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            key: '',
                            content: '',
                          ))
                      .copyWith(
                    key: key,
                    secondaryKeys: secondaryKeys,
                    content: content,
                    matchStrategy: strategy,
                    position: position,
                    caseSensitive: caseSensitive,
                  ),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_lorebook == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('未找到')),
        body: const Center(child: Text('Lorebook 不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_lorebook!.name),
        actions: [
          Switch(
            value: _lorebook!.enabled,
            onChanged: (v) {
              setState(() {
                _lorebook = _lorebook!.copyWith(enabled: v);
              });
              _saveLorebook();
            },
          ),
        ],
      ),
      body: _lorebook!.entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_add_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('还没有条目',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('添加条目来匹配关键词并注入内容',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lorebook!.entries.length,
              itemBuilder: (context, index) {
                final entry = _lorebook!.entries[index];
                return _EntryTile(
                  entry: entry,
                  index: index,
                  total: _lorebook!.entries.length,
                  onEdit: () => _editEntry(index),
                  onDelete: () => _deleteEntry(index),
                  onMoveUp: index > 0 ? () => _moveEntry(index, true) : null,
                  onMoveDown: index < _lorebook!.entries.length - 1
                      ? () => _moveEntry(index, false)
                      : null,
                  onToggle: () {
                    final entries =
                        List<LorebookEntry>.from(_lorebook!.entries);
                    entries[index] = entry.copyWith(enabled: !entry.enabled);
                    setState(() {
                      _lorebook = _lorebook!.copyWith(entries: entries);
                    });
                    _saveLorebook();
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('添加条目'),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final LorebookEntry entry;
  final int index;
  final int total;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onToggle;

  const _EntryTile({
    required this.entry,
    required this.index,
    required this.total,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.drag_handle, size: 20),
              onPressed: null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_upward,
                    size: 16,
                    color: onMoveUp != null ? null : Colors.grey[300],
                  ),
                  onPressed: onMoveUp,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    size: 16,
                    color: onMoveDown != null ? null : Colors.grey[300],
                  ),
                  onPressed: onMoveDown,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
        title: Text(
          entry.key,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: entry.enabled ? null : TextDecoration.lineThrough,
            color: entry.enabled ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          entry.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: entry.enabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: entry.enabled,
              onChanged: (_) => onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

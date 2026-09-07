import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/preset.dart';
import '../../services/preset_service.dart';

class PresetEditPage extends StatefulWidget {
  final String presetId;

  const PresetEditPage({super.key, required this.presetId});

  @override
  State<PresetEditPage> createState() => _PresetEditPageState();
}

class _PresetEditPageState extends State<PresetEditPage> {
  Preset? _preset;
  bool _isLoading = true;
  final _presetService = PresetService();

  @override
  void initState() {
    super.initState();
    _loadPreset();
  }

  void _loadPreset() {
    final db = context.read<AppDatabase>();
    if (widget.presetId.isEmpty) {
      _preset = _presetService.createDefaultPreset();
      db.savePreset(_preset!);
    } else {
      final presets = db.getPresets();
      try {
        _preset = presets.firstWhere((p) => p.id == widget.presetId);
      } catch (_) {
        _preset = null;
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _savePreset() async {
    if (_preset == null) return;
    final db = context.read<AppDatabase>();
    final updated = _preset!.copyWith(updatedAt: DateTime.now());
    await db.savePreset(updated);
    _preset = updated;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _addEntry() async {
    if (_preset == null) return;
    final entry = await _showEntryDialog(null);
    if (entry != null) {
      final entries = List<PresetEntry>.from(_preset!.entries)..add(entry);
      setState(() {
        _preset = _preset!.copyWith(entries: entries);
      });
      await _savePreset();
    }
  }

  Future<void> _editEntry(int index) async {
    if (_preset == null) return;
    final entry = await _showEntryDialog(_preset!.entries[index]);
    if (entry != null) {
      final entries = List<PresetEntry>.from(_preset!.entries);
      entries[index] = entry;
      setState(() {
        _preset = _preset!.copyWith(entries: entries);
      });
      await _savePreset();
    }
  }

  void _deleteEntry(int index) {
    if (_preset == null) return;
    final entries = List<PresetEntry>.from(_preset!.entries)..removeAt(index);
    setState(() {
      _preset = _preset!.copyWith(entries: entries);
    });
    _savePreset();
  }

  void _toggleEntry(int index) {
    if (_preset == null) return;
    final entries = List<PresetEntry>.from(_preset!.entries);
    final entry = entries[index];
    entries[index] = entry.copyWith(enabled: !entry.enabled);
    setState(() {
      _preset = _preset!.copyWith(entries: entries);
    });
    _savePreset();
  }

  void _moveEntry(int index, bool up) {
    if (_preset == null) return;
    final newIndex = up ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= _preset!.entries.length) return;
    final entries = List<PresetEntry>.from(_preset!.entries);
    final item = entries.removeAt(index);
    entries.insert(newIndex, item);
    setState(() {
      _preset = _preset!.copyWith(entries: entries);
    });
    _savePreset();
  }

  void _reorder(int oldIndex, int newIndex) {
    if (_preset == null) return;
    final entries = List<PresetEntry>.from(_preset!.entries);
    final item = entries.removeAt(oldIndex);
    entries.insert(newIndex, item);
    // Update order values
    for (int i = 0; i < entries.length; i++) {
      entries[i] = entries[i].copyWith(order: i);
    }
    setState(() {
      _preset = _preset!.copyWith(entries: entries);
    });
    _savePreset();
  }

  void _showPreview() {
    if (_preset == null) return;
    final merged = _presetService.mergePrompt(_preset!);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('预览合并结果'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(merged.isEmpty ? '(无内容)' : merged),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<PresetEntry?> _showEntryDialog(PresetEntry? existing) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    PresetEntryType type = existing?.type ?? PresetEntryType.systemPrompt;
    PresetEntryRole role = existing?.role ?? PresetEntryRole.system;
    PresetEntryPosition position =
        existing?.position ?? PresetEntryPosition.bottom;
    bool enabled = existing?.enabled ?? true;

    final result = await showDialog<PresetEntry>(
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
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: '标签名 *',
                      border: OutlineInputBorder(),
                      hintText: '例如：System Prompt, Jailbreak',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PresetEntryType>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: '类型',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: PresetEntryType.systemPrompt,
                          child: Text('系统提示')),
                      DropdownMenuItem(
                          value: PresetEntryType.jailbreak,
                          child: Text('越狱提示')),
                      DropdownMenuItem(
                          value: PresetEntryType.userMessage,
                          child: Text('用户消息')),
                      DropdownMenuItem(
                          value: PresetEntryType.assistantMessage,
                          child: Text('助手消息')),
                      DropdownMenuItem(
                          value: PresetEntryType.tool, child: Text('工具')),
                      DropdownMenuItem(
                          value: PresetEntryType.custom, child: Text('自定义')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          type = v;
                          // Auto-set role based on type
                          switch (v) {
                            case PresetEntryType.systemPrompt:
                            case PresetEntryType.jailbreak:
                              role = PresetEntryRole.system;
                              break;
                            case PresetEntryType.userMessage:
                              role = PresetEntryRole.user;
                              break;
                            case PresetEntryType.assistantMessage:
                              role = PresetEntryRole.assistant;
                              break;
                            default:
                              break;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PresetEntryRole>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: '角色',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: PresetEntryRole.system, child: Text('system')),
                      DropdownMenuItem(
                          value: PresetEntryRole.user, child: Text('user')),
                      DropdownMenuItem(
                          value: PresetEntryRole.assistant,
                          child: Text('assistant')),
                      DropdownMenuItem(
                          value: PresetEntryRole.tool, child: Text('tool')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => role = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PresetEntryPosition>(
                    initialValue: position,
                    decoration: const InputDecoration(
                      labelText: '位置',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: PresetEntryPosition.top, child: Text('最前')),
                      DropdownMenuItem(
                          value: PresetEntryPosition.bottom, child: Text('最后')),
                      DropdownMenuItem(
                          value: PresetEntryPosition.beforeSystem,
                          child: Text('系统提示前')),
                      DropdownMenuItem(
                          value: PresetEntryPosition.afterSystem,
                          child: Text('系统提示后')),
                      DropdownMenuItem(
                          value: PresetEntryPosition.beforeFirstUser,
                          child: Text('首次用户前')),
                      DropdownMenuItem(
                          value: PresetEntryPosition.beforeLastUser,
                          child: Text('最后用户前')),
                      DropdownMenuItem(
                          value: PresetEntryPosition.afterLastUser,
                          child: Text('最后用户后')),
                      DropdownMenuItem(
                          value: PresetEntryPosition.beforeAssistant,
                          child: Text('助手回复前')),
                      DropdownMenuItem(
                          value: PresetEntryPosition.afterAssistant,
                          child: Text('助手回复后')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => position = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 8,
                    minLines: 4,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: '内容 *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      hintText: '提示词内容，支持 {{char}}, {{user}} 等宏变量',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('启用'),
                    value: enabled,
                    onChanged: (v) => setDialogState(() => enabled = v),
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
                if (labelController.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  PresetEntry(
                    id: existing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    label: labelController.text.trim(),
                    type: type,
                    role: role,
                    position: position,
                    content: contentController.text,
                    enabled: enabled,
                    order: existing?.order ?? 0,
                    insertOnce: existing?.insertOnce ?? false,
                    condition: existing?.condition,
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

    if (_preset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('预设不存在')),
        body: const Center(child: Text('找不到该预设')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_preset!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _showPreview,
            tooltip: '预览',
          ),
        ],
      ),
      body: _preset!.entries.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_list_bulleted,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无条目',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('点击下方按钮添加条目', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _preset!.entries.length,
              onReorderItem: _reorder,
              itemBuilder: (context, index) {
                final entry = _preset!.entries[index];
                return _EntryTile(
                  key: ValueKey(entry.id),
                  entry: entry,
                  index: index,
                  total: _preset!.entries.length,
                  onTap: () => _editEntry(index),
                  onDelete: () => _deleteEntry(index),
                  onToggle: () => _toggleEntry(index),
                  onMoveUp: index > 0 ? () => _moveEntry(index, true) : null,
                  onMoveDown: index < _preset!.entries.length - 1
                      ? () => _moveEntry(index, false)
                      : null,
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
  final PresetEntry entry;
  final int index;
  final int total;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _EntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.total,
    required this.onTap,
    required this.onDelete,
    required this.onToggle,
    this.onMoveUp,
    this.onMoveDown,
  });

  Color _roleColor() {
    switch (entry.role) {
      case PresetEntryRole.system:
        return Colors.blue;
      case PresetEntryRole.user:
        return Colors.green;
      case PresetEntryRole.assistant:
        return Colors.orange;
      case PresetEntryRole.tool:
        return Colors.purple;
    }
  }

  String _positionLabel() {
    switch (entry.position) {
      case PresetEntryPosition.top:
        return '最前';
      case PresetEntryPosition.bottom:
        return '最后';
      case PresetEntryPosition.beforeSystem:
        return '系统前';
      case PresetEntryPosition.afterSystem:
        return '系统后';
      case PresetEntryPosition.beforeFirstUser:
        return '首用户前';
      case PresetEntryPosition.beforeLastUser:
        return '末用户前';
      case PresetEntryPosition.afterLastUser:
        return '末用户后';
      case PresetEntryPosition.beforeAssistant:
        return '助手前';
      case PresetEntryPosition.afterAssistant:
        return '助手后';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          Icons.drag_handle,
          color: Colors.grey,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _roleColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.role.name,
                style: TextStyle(
                  color: _roleColor(),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.label,
                style: TextStyle(
                  decoration: entry.enabled ? null : TextDecoration.lineThrough,
                  color: entry.enabled ? null : Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              _positionLabel(),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                entry.enabled ? Icons.visibility : Icons.visibility_off,
                size: 20,
              ),
              onPressed: onToggle,
              tooltip: entry.enabled ? '禁用' : '启用',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onTap();
                    break;
                  case 'moveUp':
                    onMoveUp?.call();
                    break;
                  case 'moveDown':
                    onMoveDown?.call();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                if (onMoveUp != null)
                  const PopupMenuItem(value: 'moveUp', child: Text('上移')),
                if (onMoveDown != null)
                  const PopupMenuItem(value: 'moveDown', child: Text('下移')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

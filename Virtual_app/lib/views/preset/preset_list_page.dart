import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/preset.dart';
import '../../services/preset_service.dart';

class PresetListPage extends StatefulWidget {
  const PresetListPage({super.key});

  @override
  State<PresetListPage> createState() => _PresetListPageState();
}

class _PresetListPageState extends State<PresetListPage> {
  List<Preset> _presets = [];
  final _presetService = PresetService();

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  void _loadPresets() {
    final db = context.read<AppDatabase>();
    setState(() {
      _presets = db.getPresets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预设管理'),
      ),
      body: _presets.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _presets.length,
              itemBuilder: (context, index) {
                final preset = _presets[index];
                return _PresetTile(
                  preset: preset,
                  onTap: () => context.push('/preset/${preset.id}/edit'),
                  onDelete: () => _confirmDelete(preset),
                  onDuplicate: () => _duplicatePreset(preset),
                  onToggleActive: () => _toggleActive(preset),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createPreset(),
        icon: const Icon(Icons.add),
        label: const Text('新建预设'),
      ),
    );
  }

  Future<void> _createPreset() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建预设'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '预设名称',
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
    if (result != null && result.isNotEmpty) {
      final db = context.read<AppDatabase>();
      final preset = _presetService.createDefaultPreset(name: result);
      await db.savePreset(preset);
      _loadPresets();
    }
  }

  Future<void> _duplicatePreset(Preset preset) async {
    final db = context.read<AppDatabase>();
    final duplicate = _presetService.duplicatePreset(preset);
    await db.savePreset(duplicate);
    _loadPresets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制')),
      );
    }
  }

  Future<void> _toggleActive(Preset preset) async {
    final db = context.read<AppDatabase>();
    final updated = preset.copyWith(
      isActive: !preset.isActive,
      updatedAt: DateTime.now(),
    );
    await db.savePreset(updated);
    _loadPresets();
  }

  Future<void> _confirmDelete(Preset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定要删除「${preset.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = context.read<AppDatabase>();
      await db.deletePreset(preset.id);
      _loadPresets();
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('暂无预设', style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 8),
          Text('点击下方按钮创建预设', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final Preset preset;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleActive;

  const _PresetTile({
    required this.preset,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          preset.isActive ? Icons.star : Icons.star_outline,
          color: preset.isActive ? Colors.amber : Colors.grey,
        ),
        title: Text(
          preset.name,
          style: TextStyle(
            fontWeight: preset.isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '${preset.entries.length} 个条目${preset.description.isNotEmpty ? ' · ${preset.description}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onTap();
                break;
              case 'duplicate':
                onDuplicate();
                break;
              case 'active':
                onToggleActive();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'duplicate', child: Text('复制')),
            PopupMenuItem(
              value: 'active',
              child: Text(preset.isActive ? '取消激活' : '设为激活'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

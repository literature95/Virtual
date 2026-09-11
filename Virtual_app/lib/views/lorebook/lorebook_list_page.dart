import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/lorebook.dart';
import '../../services/lorebook_import_service.dart';
import '../../utils/file_saver.dart';

/// 世界书（Lorebook）列表
///
/// **项目约定：世界书以 JSON 为唯一格式**（角色卡则是 PNG）。
/// 导入支持三种 JSON 形态：SillyTavern World Info（`entries` 为对象）、
/// CCv3 `character_book`（`entries` 为数组）、本 App 自身导出的 JSON；
/// 导出统一为 SillyTavern World Info 形态（互操作性最好）。
class LorebookListPage extends StatefulWidget {
  const LorebookListPage({super.key});

  @override
  State<LorebookListPage> createState() => _LorebookListPageState();
}

class _LorebookListPageState extends State<LorebookListPage> {
  List<Lorebook> _lorebooks = [];
  bool _busy = false;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: '从 JSON 导入世界书',
            onPressed: _busy ? null : _importLorebook,
          ),
        ],
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
                  onExport: () => _exportLorebook(lorebook),
                  onDelete: () => _confirmDelete(lorebook),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLorebook,
        icon: const Icon(Icons.add),
        label: const Text('新建 Lorebook'),
      ),
    );
  }

  /// 从 JSON 文件导入世界书
  ///
  /// 与角色卡一样走**字节**而非路径：Web 上没有文件系统，`dart:io File`
  /// 不可用。`file_picker` 的 `withData: true` 让各端都回填 bytes。
  Future<void> _importLorebook() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
        dialogTitle: '选择世界书 JSON',
      );
    } catch (e) {
      _snack('无法打开文件选择器: $e');
      return;
    }
    final file = (picked == null || picked.files.isEmpty)
        ? null
        : picked.files.first;
    if (file == null) return; // 用户取消

    final bytes = file.bytes ?? await file.xFile.readAsBytes();

    setState(() => _busy = true);
    try {
      final result = LorebookImportService().importFromBytes(
        bytes,
        sourceName: file.name,
      );
      await context.read<AppDatabase>().saveLorebook(result.lorebook);
      if (!mounted) return;
      _loadLorebooks();
      final warnings = result.warnings;
      _snack(
        '已导入「${result.lorebook.name}」（${result.summary}）'
        '${warnings.isEmpty ? '' : '\n提示：${warnings.join('；')}'}',
      );
    } catch (e) {
      if (mounted) _snack('导入失败: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 导出世界书 JSON（SillyTavern World Info 形态）
  Future<void> _exportLorebook(Lorebook lorebook) async {
    try {
      final json = const JsonEncoder.withIndent('  ')
          .convert(lorebook.toWorldInfo());
      final path = await saveBytesToFile(
        utf8.encode(json),
        fileName: '${_sanitize(lorebook.name)}.json',
        mimeType: 'application/json',
        allowedExtensions: const ['json'],
        dialogTitle: '导出世界书',
      );
      if (!mounted) return;
      _snack(path == null ? '已取消导出' : '已导出世界书 → $path');
    } catch (e) {
      if (mounted) _snack('导出失败: $e');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _sanitize(String name) {
    final cleaned =
        name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (cleaned.isEmpty) return 'lorebook';
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
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
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const _LorebookTile({
    required this.lorebook,
    required this.onTap,
    required this.onExport,
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
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) {
            if (value == 'export') onExport();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'export',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.file_upload),
                title: Text('导出 JSON'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ),
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
            '新建，或从 JSON 导入（SillyTavern / CCv3 character_book）',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/app_database.dart';
import '../../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  BackupService? _backupService;
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_backupService == null) {
      final db = context.read<AppDatabase>();
      _backupService = BackupService(db);
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    try {
      final data = await _backupService!.exportAll();
      final stats = _backupService!.getDataStats(data);
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据备份'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExportSection(),
          const SizedBox(height: 16),
          _buildImportSection(),
          const SizedBox(height: 16),
          _buildStatsSection(),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.backup_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '导出数据',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '将所有数据导出为 JSON 文件，可用于备份或迁移到其他设备。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exportData,
                icon: const Icon(Icons.download_outlined),
                label: const Text('导出备份'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restore_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '导入数据',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '从 JSON 备份文件恢复数据。注意：导入将覆盖当前数据。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _importData,
                icon: const Icon(Icons.upload_outlined),
                label: const Text('导入备份'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final total = _stats.values.fold<int>(0, (sum, v) => sum + v);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '数据统计',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '共 $total 条',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatItem('角色', _stats['characters'] ?? 0),
            _buildStatItem('对话', _stats['conversations'] ?? 0),
            _buildStatItem('端点', _stats['endpoints'] ?? 0),
            _buildStatItem('世界书', _stats['lorebooks'] ?? 0),
            _buildStatItem('预设', _stats['presets'] ?? 0),
            _buildStatItem('正则规则', _stats['regex_rules'] ?? 0),
            _buildStatItem('主题', _stats['themes'] ?? 0),
            _buildStatItem('人格', _stats['personas'] ?? 0),
            _buildStatItem('插件', _stats['plugins'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存备份文件',
        fileName: 'tav_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在导出...'),
          duration: Duration(seconds: 1),
        ),
      );

      await _backupService!.exportToFile(result);

      if (!mounted) return;
      final size = await _backupService!.getBackupSize();
      final sizeStr = _formatSize(size);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出成功 ($sizeStr)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法读取文件'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Parse and show stats before importing
      final data = await _backupService!.parseBackupFile(filePath);
      final stats = _backupService!.getDataStats(data);
      final total = stats.values.fold<int>(0, (sum, v) => sum + v);

      if (!mounted) return;

      // Confirm import
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: const Text('确认导入'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('导入备份将覆盖当前所有数据，此操作不可撤销。'),
              const SizedBox(height: 12),
              Text('备份包含 $total 条数据：'),
              const SizedBox(height: 8),
              for (final entry in stats.entries.where((e) => e.value > 0))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_labelFor(entry.key)),
                      Text('${entry.value}'),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在导入...'),
          duration: Duration(seconds: 1),
        ),
      );

      await _backupService!.importAll(data);
      await _loadStats();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导入成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _labelFor(String key) {
    switch (key) {
      case 'characters':
        return '角色';
      case 'conversations':
        return '对话';
      case 'endpoints':
        return '端点';
      case 'lorebooks':
        return '世界书';
      case 'presets':
        return '预设';
      case 'regex_rules':
        return '正则规则';
      case 'themes':
        return '主题';
      case 'personas':
        return '人格';
      case 'plugins':
        return '插件';
      default:
        return key;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

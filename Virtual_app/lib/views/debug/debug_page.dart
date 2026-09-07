import 'package:flutter/material.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  String _cacheSize = '计算中...';
  final String _mcpStatus = '未连接';

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    setState(() {
      _cacheSize = '12.3 MB';
    });
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _cacheSize = '0 MB';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _exportLogs() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志导出中...')),
    );
  }

  void _resetAllData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置所有数据'),
        content: const Text('此操作不可撤销，确定要重置所有应用数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据已重置')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _forceSync() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('强制同步中...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试'),
      ),
      body: ListView(
        children: [
          _buildSection(context, '应用信息', [
            ListTile(
              title: const Text('应用版本'),
              trailing: const Text('1.0.0'),
            ),
            ListTile(
              title: const Text('构建模式'),
              trailing: const Text('Debug'),
            ),
          ]),
          _buildSection(context, '存储', [
            ListTile(
              title: const Text('缓存大小'),
              trailing: Text(_cacheSize),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('清除缓存'),
              onTap: _clearCache,
            ),
          ]),
          _buildSection(context, '日志', [
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('导出日志'),
              onTap: _exportLogs,
            ),
          ]),
          _buildSection(context, 'MCP 服务', [
            ListTile(
              title: const Text('状态'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _mcpStatus == '已连接' ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_mcpStatus),
                ],
              ),
            ),
          ]),
          _buildSection(context, '快捷操作', [
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('重置所有数据'),
              onTap: _resetAllData,
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('强制同步'),
              onTap: _forceSync,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: children),
        ),
      ],
    );
  }
}

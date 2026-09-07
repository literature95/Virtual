import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/plugin_service.dart';

class PluginListPage extends StatefulWidget {
  const PluginListPage({super.key});

  @override
  State<PluginListPage> createState() => _PluginListPageState();
}

class _PluginListPageState extends State<PluginListPage> {
  final PluginService _pluginService = PluginService();

  @override
  void initState() {
    super.initState();
    _pluginService.initialize();
  }

  Future<void> _installFromJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final bytes = await File(path).readAsBytes();
        final content = utf8.decode(bytes);
        final json = jsonDecode(content) as Map<String, dynamic>;
        final plugin = PluginInfo.fromJson(json);
        await _pluginService.installPlugin(plugin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已安装插件: ${plugin.name}')),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('安装失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugins = _pluginService.plugins;

    return Scaffold(
      appBar: AppBar(
        title: const Text('插件管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '从 JSON 安装',
            onPressed: _installFromJson,
          ),
        ],
      ),
      body: plugins.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.extension_off, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    '暂无插件',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角按钮从 JSON 文件安装',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: plugins.length,
              itemBuilder: (context, index) {
                final plugin = plugins[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(plugin.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plugin.description),
                        const SizedBox(height: 4),
                        Text(
                          'v${plugin.version}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: plugin.enabled,
                          onChanged: (v) async {
                            await _pluginService.togglePlugin(plugin.id, v);
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('确认卸载'),
                                content: Text('确定要卸载插件 ${plugin.name} 吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('卸载'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await _pluginService.uninstallPlugin(plugin.id);
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

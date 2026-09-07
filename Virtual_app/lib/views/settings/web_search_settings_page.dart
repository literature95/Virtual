import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../services/web_search_service.dart';

class WebSearchSettingsPage extends StatefulWidget {
  const WebSearchSettingsPage({super.key});

  @override
  State<WebSearchSettingsPage> createState() => _WebSearchSettingsPageState();
}

class _WebSearchSettingsPageState extends State<WebSearchSettingsPage> {
  late TextEditingController _apiKeyController;
  late double _maxResults;
  late String _searchDepth;
  bool _testing = false;
  String? _testResult;
  late WebSearchService _searchService;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _maxResults = 5;
    _searchDepth = 'basic';
    _searchService = WebSearchService(Dio());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网络搜索设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildApiKeySection(),
          const SizedBox(height: 16),
          _buildMaxResultsSection(),
          const SizedBox(height: 16),
          _buildSearchDepthSection(),
          const SizedBox(height: 16),
          _buildTestSection(),
        ],
      ),
    );
  }

  Widget _buildApiKeySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tavily API Key',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入 Tavily API Key',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaxResultsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最大结果数',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('1'),
                Expanded(
                  child: Slider(
                    value: _maxResults,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: _maxResults.toInt().toString(),
                    onChanged: (value) {
                      setState(() => _maxResults = value);
                    },
                  ),
                ),
                const Text('10'),
                const SizedBox(width: 8),
                Text(_maxResults.toInt().toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchDepthSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '搜索深度',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _searchDepth,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'basic', child: Text('基础')),
                DropdownMenuItem(value: 'advanced', child: Text('高级')),
              ],
              onChanged: (value) {
                setState(() => _searchDepth = value!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '测试',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '点击测试按钮，使用 "hello world" 验证搜索配置是否正常。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _testing ? null : _testSearch,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_testing ? '测试中...' : '测试搜索'),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_testResult!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testSearch() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final config = WebSearchConfig(
        apiKey: _apiKeyController.text,
        maxResults: _maxResults.toInt(),
        searchDepth: _searchDepth,
      );
      final result =
          await _searchService.searchForPrompt('hello world', config);
      setState(() {
        _testResult = result;
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '测试失败: $e';
        _testing = false;
      });
    }
  }

  void _saveSettings() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络搜索设置已保存')),
      );
      Navigator.pop(context);
    }
  }
}

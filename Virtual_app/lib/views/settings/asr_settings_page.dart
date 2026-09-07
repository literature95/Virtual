import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/asr_service.dart';

class AsrSettingsPage extends StatefulWidget {
  const AsrSettingsPage({super.key});

  @override
  State<AsrSettingsPage> createState() => _AsrSettingsPageState();
}

class _AsrSettingsPageState extends State<AsrSettingsPage> {
  late ASRPlatform _platform;
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late String _language;
  bool _testing = false;
  late ASRService _asrService;

  @override
  void initState() {
    super.initState();
    _platform = ASRPlatform.system;
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _language = 'zh';
    _asrService = ASRService();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASR 设置'),
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
          _buildPlatformSection(),
          const SizedBox(height: 16),
          _buildApiKeySection(),
          const SizedBox(height: 16),
          _buildBaseUrlSection(),
          const SizedBox(height: 16),
          _buildLanguageSection(),
          const SizedBox(height: 16),
          _buildTestSection(),
        ],
      ),
    );
  }

  Widget _buildPlatformSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ASR 平台',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ASRPlatform>(
              initialValue: _platform,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: ASRPlatform.system,
                  child: Text('系统语音识别'),
                ),
                DropdownMenuItem(
                  value: ASRPlatform.openai,
                  child: Text('OpenAI Whisper'),
                ),
                DropdownMenuItem(
                  value: ASRPlatform.google,
                  child: Text('Google Speech-to-Text'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _platform = value!;
                  _updateBaseUrl();
                });
              },
            ),
          ],
        ),
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
              'API Key',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入 API Key',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseUrlSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Base URL',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入 API 地址',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '识别语言',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'zh',
                  child: Text('中文'),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text('英文'),
                ),
                DropdownMenuItem(
                  value: 'ja',
                  child: Text('日文'),
                ),
                DropdownMenuItem(
                  value: 'ko',
                  child: Text('韩文'),
                ),
              ],
              onChanged: (value) {
                setState(() => _language = value!);
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
              '点击测试按钮，验证语音识别是否正常工作。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _testing ? null : _testAsr,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mic),
                label: Text(_testing ? '测试中...' : '测试语音识别'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateBaseUrl() {
    switch (_platform) {
      case ASRPlatform.openai:
        _baseUrlController.text = 'https://api.openai.com';
        break;
      case ASRPlatform.google:
        _baseUrlController.text = 'https://speech.googleapis.com';
        break;
      case ASRPlatform.system:
      case ASRPlatform.plugin:
        _baseUrlController.text = '';
        break;
    }
  }

  Future<void> _testAsr() async {
    setState(() => _testing = true);
    try {
      final config = ASRConfig(
        platform: _platform,
        apiKey:
            _apiKeyController.text.isNotEmpty ? _apiKeyController.text : null,
        baseUrl:
            _baseUrlController.text.isNotEmpty ? _baseUrlController.text : null,
        language: _language,
      );

      await _asrService.startListening(
        onResult: (text) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('识别结果: $text')),
            );
          }
        },
        onEnd: () {
          setState(() => _testing = false);
        },
        config: config,
      );
    } catch (e) {
      setState(() => _testing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别测试失败: $e')),
        );
      }
    }
  }

  void _saveSettings() {
    context.read<SettingsProvider>().setAsrConfig(
          platform: _platform,
          apiKey: _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
          baseUrl: _baseUrlController.text.trim().isEmpty
              ? null
              : _baseUrlController.text.trim(),
          language: _language,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ASR 设置已保存')),
      );
      Navigator.pop(context);
    }
  }
}

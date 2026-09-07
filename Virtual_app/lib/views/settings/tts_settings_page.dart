import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/tts_service.dart';

class TtsSettingsPage extends StatefulWidget {
  const TtsSettingsPage({super.key});

  @override
  State<TtsSettingsPage> createState() => _TtsSettingsPageState();
}

class _TtsSettingsPageState extends State<TtsSettingsPage> {
  late TTSPlatform _platform;
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _voiceIdController;
  late double _speed;
  late double _pitch;
  late String _selectedVoice;
  List<Map<String, String>> _voices = [];
  bool _loadingVoices = false;
  bool _testing = false;
  late TTSService _ttsService;

  @override
  void initState() {
    super.initState();
    _platform = TTSPlatform.flutterTts;
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _voiceIdController = TextEditingController();
    _speed = 1.0;
    _pitch = 1.0;
    _selectedVoice = '';
    _ttsService = TTSService(Dio());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _voiceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TTS 设置'),
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
          _buildVoiceSection(),
          const SizedBox(height: 16),
          _buildSpeedPitchSection(),
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
              'TTS 平台',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<TTSPlatform>(
              initialValue: _platform,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: TTSPlatform.flutterTts,
                  child: Text('系统 TTS'),
                ),
                DropdownMenuItem(
                  value: TTSPlatform.elevenlabs,
                  child: Text('ElevenLabs'),
                ),
                DropdownMenuItem(
                  value: TTSPlatform.openai,
                  child: Text('OpenAI'),
                ),
                DropdownMenuItem(
                  value: TTSPlatform.googleGemini,
                  child: Text('Google Gemini'),
                ),
                DropdownMenuItem(
                  value: TTSPlatform.minimax,
                  child: Text('MiniMax'),
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

  Widget _buildVoiceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '音色选择',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_platform != TTSPlatform.flutterTts)
                  TextButton(
                    onPressed: _loadVoices,
                    child: _loadingVoices
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('加载音色'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_voices.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedVoice.isNotEmpty ? _selectedVoice : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _voices.map((v) {
                  return DropdownMenuItem(
                    value: v['id'],
                    child: Text(v['name'] ?? v['id'] ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVoice = value ?? '';
                    _voiceIdController.text = value ?? '';
                  });
                },
              )
            else
              TextField(
                controller: _voiceIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入音色 ID',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedPitchSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '语速和音调',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('语速'),
                Expanded(
                  child: Slider(
                    value: _speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: _speed.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() => _speed = value);
                    },
                  ),
                ),
                Text(_speed.toStringAsFixed(1)),
              ],
            ),
            Row(
              children: [
                const Text('音调'),
                Expanded(
                  child: Slider(
                    value: _pitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: _pitch.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() => _pitch = value);
                    },
                  ),
                ),
                Text(_pitch.toStringAsFixed(1)),
              ],
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
              '点击测试按钮，验证 TTS 配置是否正常工作。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _testing ? null : _testTts,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_testing ? '测试中...' : '测试 TTS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateBaseUrl() {
    switch (_platform) {
      case TTSPlatform.elevenlabs:
        _baseUrlController.text = 'https://api.elevenlabs.io';
        break;
      case TTSPlatform.openai:
        _baseUrlController.text = 'https://api.openai.com';
        break;
      case TTSPlatform.googleGemini:
        _baseUrlController.text = 'https://generativelanguage.googleapis.com';
        break;
      case TTSPlatform.minimax:
        _baseUrlController.text = 'https://api.minimax.chat';
        break;
      case TTSPlatform.flutterTts:
        _baseUrlController.text = '';
        break;
    }
  }

  Future<void> _loadVoices() async {
    setState(() => _loadingVoices = true);
    try {
      final voices = await _ttsService.getVoices(
        _platform,
        _apiKeyController.text,
        _baseUrlController.text,
      );
      setState(() {
        _voices = voices;
        _loadingVoices = false;
      });
    } catch (e) {
      setState(() => _loadingVoices = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载音色失败: $e')),
        );
      }
    }
  }

  Future<void> _testTts() async {
    setState(() => _testing = true);
    try {
      final config = TTSConfig(
        platform: _platform,
        apiKey: _apiKeyController.text,
        baseUrl: _baseUrlController.text,
        voiceId:
            _voiceIdController.text.isNotEmpty ? _voiceIdController.text : null,
        speed: _speed,
        pitch: _pitch,
      );
      await _ttsService.speak('你好，这是一段测试语音。', config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TTS 测试成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS 测试失败: $e')),
        );
      }
    } finally {
      setState(() => _testing = false);
    }
  }

  void _saveSettings() {
    context.read<SettingsProvider>().setTtsConfig(
          platform: _platform,
          apiKey: _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
          baseUrl: _baseUrlController.text.trim().isEmpty
              ? null
              : _baseUrlController.text.trim(),
          voiceId: _voiceIdController.text.trim().isEmpty
              ? null
              : _voiceIdController.text.trim(),
          speed: _speed,
          pitch: _pitch,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TTS 设置已保存')),
      );
      Navigator.pop(context);
    }
  }
}

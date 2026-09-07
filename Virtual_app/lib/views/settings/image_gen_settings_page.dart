import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../services/image_generation_service.dart';

class ImageGenSettingsPage extends StatefulWidget {
  const ImageGenSettingsPage({super.key});

  @override
  State<ImageGenSettingsPage> createState() => _ImageGenSettingsPageState();
}

class _ImageGenSettingsPageState extends State<ImageGenSettingsPage> {
  late ImageGenerationPlatform _platform;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late double _width;
  late double _height;
  bool _testing = false;
  String? _testResult;
  Uint8List? _testImage;
  late ImageGenerationService _imageService;

  @override
  void initState() {
    super.initState();
    _platform = ImageGenerationPlatform.openai;
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _width = 1024;
    _height = 1024;
    _imageService = ImageGenerationService(Dio());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图像生成设置'),
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
          _buildModelSection(),
          const SizedBox(height: 16),
          _buildSizeSection(),
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
              '图像生成平台',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ImageGenerationPlatform>(
              initialValue: _platform,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: ImageGenerationPlatform.openai,
                  child: Text('OpenAI (DALL-E)'),
                ),
                DropdownMenuItem(
                  value: ImageGenerationPlatform.gemini,
                  child: Text('Google Gemini'),
                ),
                DropdownMenuItem(
                  value: ImageGenerationPlatform.novelai,
                  child: Text('NovelAI'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _platform = value!;
                  _updateModel();
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

  Widget _buildModelSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '模型',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '留空使用默认模型',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '图像尺寸',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('宽'),
                Expanded(
                  child: Slider(
                    value: _width,
                    min: 512,
                    max: 2048,
                    divisions: 12,
                    label: _width.toInt().toString(),
                    onChanged: (value) {
                      setState(() => _width = value);
                    },
                  ),
                ),
                Text(_width.toInt().toString()),
              ],
            ),
            Row(
              children: [
                const Text('高'),
                Expanded(
                  child: Slider(
                    value: _height,
                    min: 512,
                    max: 2048,
                    divisions: 12,
                    label: _height.toInt().toString(),
                    onChanged: (value) {
                      setState(() => _height = value);
                    },
                  ),
                ),
                Text(_height.toInt().toString()),
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
              '点击测试按钮，生成一张测试图片验证配置。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _testing ? null : _testGenerate,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_testing ? '生成中...' : '测试生成'),
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
            if (_testImage != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_testImage!, height: 200),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _updateModel() {
    switch (_platform) {
      case ImageGenerationPlatform.openai:
        _modelController.text = 'dall-e-3';
        break;
      case ImageGenerationPlatform.gemini:
        _modelController.text = 'gemini-2.0-flash-exp-image-generation';
        break;
      case ImageGenerationPlatform.novelai:
        _modelController.text = 'nai-diffusion-3';
        break;
    }
  }

  Future<void> _testGenerate() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _testImage = null;
    });
    try {
      final config = ImageGenConfig(
        platform: _platform,
        apiKey: _apiKeyController.text,
        baseUrl: _platform == ImageGenerationPlatform.gemini
            ? 'https://generativelanguage.googleapis.com'
            : 'https://api.openai.com',
        model: _modelController.text.isNotEmpty ? _modelController.text : null,
        width: _width.toInt(),
        height: _height.toInt(),
      );
      final result = await _imageService.generate(
        'A cute cat wearing a tiny hat, watercolor style',
        config,
      );
      setState(() {
        if (result.error != null) {
          _testResult = '生成失败: ${result.error}';
        } else {
          _testResult = '生成成功！';
          if (result.imageBytes != null) {
            _testImage = Uint8List.fromList(result.imageBytes!);
          }
        }
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
        const SnackBar(content: Text('图像生成设置已保存')),
      );
      Navigator.pop(context);
    }
  }
}

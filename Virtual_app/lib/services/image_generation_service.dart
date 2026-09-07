import 'dart:convert';
import 'package:dio/dio.dart';

enum ImageGenerationPlatform { novelai, gemini, openai }

class ImageGenConfig {
  final ImageGenerationPlatform platform;
  final String apiKey;
  final String baseUrl;
  final String? model;
  final int width;
  final int height;
  final String? negativePrompt;

  const ImageGenConfig({
    required this.platform,
    required this.apiKey,
    required this.baseUrl,
    this.model,
    this.width = 1024,
    this.height = 1024,
    this.negativePrompt,
  });
}

class ImageGenerationResult {
  final String? imageUrl;
  final List<int>? imageBytes;
  final String? error;

  const ImageGenerationResult({this.imageUrl, this.imageBytes, this.error});
}

class ImageGenerationService {
  final Dio _dio;
  ImageGenerationService(this._dio);

  Future<ImageGenerationResult> generate(String prompt, ImageGenConfig config) async {
    switch (config.platform) {
      case ImageGenerationPlatform.novelai:
        return _generateNovelAI(prompt, config);
      case ImageGenerationPlatform.gemini:
        return _generateGemini(prompt, config);
      case ImageGenerationPlatform.openai:
        return _generateOpenAI(prompt, config);
    }
  }

  Future<ImageGenerationResult> _generateNovelAI(String prompt, ImageGenConfig config) async {
    try {
      final response = await _dio.post(
        '${config.baseUrl}/v1/generation/gpt-image-1',
        data: {
          'action': 'generate',
          'model': 'nai-diffusion-3',
          'parameters': {
            'prompt': prompt,
            'width': config.width,
            'height': config.height,
            'negative_prompt': config.negativePrompt ?? '',
            'steps': 28,
            'scale': 7.5,
          },
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${config.apiKey}', 'Content-Type': 'application/json'},
          responseType: ResponseType.bytes,
        ),
      );
      return ImageGenerationResult(imageBytes: response.data);
    } catch (e) {
      return ImageGenerationResult(error: e.toString());
    }
  }

  Future<ImageGenerationResult> _generateGemini(String prompt, ImageGenConfig config) async {
    try {
      final model = config.model ?? 'gemini-2.0-flash-exp-image-generation';
      final response = await _dio.post(
        '${config.baseUrl}/v1beta/models/$model:generateContent',
        data: {
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'responseModalities': ['TEXT', 'IMAGE']},
        },
        options: Options(headers: {'x-goog-api-key': config.apiKey}),
      );
      final candidates = response.data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']['parts'] as List?;
        if (parts != null) {
          for (final part in parts) {
            if (part['inlineData'] != null) {
              final bytes = base64Decode(part['inlineData']['data']);
              return ImageGenerationResult(imageBytes: bytes);
            }
          }
        }
      }
      return const ImageGenerationResult(error: 'No image generated');
    } catch (e) {
      return ImageGenerationResult(error: e.toString());
    }
  }

  Future<ImageGenerationResult> _generateOpenAI(String prompt, ImageGenConfig config) async {
    try {
      final response = await _dio.post(
        '${config.baseUrl}/v1/images/generations',
        data: {
          'model': config.model ?? 'dall-e-3',
          'prompt': prompt,
          'n': 1,
          'size': '${config.width}x${config.height}',
        },
        options: Options(headers: {'Authorization': 'Bearer ${config.apiKey}'}),
      );
      final data = response.data['data'] as List;
      if (data.isNotEmpty) {
        return ImageGenerationResult(imageUrl: data[0]['url'] as String?);
      }
      return const ImageGenerationResult(error: 'No image generated');
    } catch (e) {
      return ImageGenerationResult(error: e.toString());
    }
  }
}

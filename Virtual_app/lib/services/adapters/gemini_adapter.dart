import 'dart:convert';
import 'package:dio/dio.dart';

import '../../models/conversation.dart';
import '../../models/endpoint.dart';
import 'llm_adapter.dart';

class GeminiAdapter implements LLMAdapter {
  final Dio _dio;
  final LlmEndpoint endpoint;

  GeminiAdapter(this.endpoint)
      : _dio = Dio(BaseOptions(
          baseUrl: endpoint.baseUrl,
          queryParameters: {'key': endpoint.apiKey},
          headers: {
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
        ));

  @override
  String get protocol => 'gemini';

  Map<String, dynamic> _convertToGeminiFormat(
    List<Map<String, dynamic>> messages,
    String systemPrompt,
  ) {
    final contents = <Map<String, dynamic>>[];
    final systemInstructions = <Map<String, dynamic>>[];

    for (final msg in messages) {
      final role = msg['role'] as String?;
      final content = msg['content'] as String? ?? '';

      if (role == 'system') {
        systemInstructions.add({
          'parts': [{'text': content}],
        });
        continue;
      }

      final geminiRole = role == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': geminiRole,
        'parts': [{'text': content}],
      });
    }

    if (systemPrompt.isNotEmpty && systemInstructions.isEmpty) {
      systemInstructions.add({
        'parts': [{'text': systemPrompt}],
      });
    }

    return {
      'contents': contents,
      if (systemInstructions.isNotEmpty)
        'systemInstruction': {
          'parts': [
            for (final inst in systemInstructions)
              {'text': inst['parts'][0]['text']},
          ],
        },
    };
  }

  @override
  Stream<ChatChunk> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async* {
    final geminiFormat = _convertToGeminiFormat(messages, settings.systemPrompt ?? '');

    final body = <String, dynamic>{
      ...geminiFormat,
      'generationConfig': {
        'temperature': settings.temperature,
        'topP': settings.topP,
        if (settings.maxTokens != null) 'maxOutputTokens': settings.maxTokens,
        if (settings.stopSequences.isNotEmpty) 'stopSequences': settings.stopSequences,
      },
    };

    try {
      final response = await _dio.post(
        '/models/$model:streamGenerateContent?alt=sse',
        data: jsonEncode(body),
        options: Options(responseType: ResponseType.stream),
      );

      final stream = response.data.stream as Stream<List<int>>;
      String? buffer;

      await for (final line in stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (!trimmed.startsWith('data:')) {
          if (buffer != null) {
            buffer = '$buffer$trimmed';
            continue;
          }
          continue;
        }

        final data = trimmed.substring(5).trim();
        if (data.isEmpty) continue;

        try {
          final json = jsonDecode(data);
          yield* _parseSseChunk(json);
        } catch (_) {
          buffer = data;
          continue;
        }
        buffer = null;
      }

      yield const ChatChunk(isFinal: true);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Stream<ChatChunk> _parseSseChunk(Map<String, dynamic> json) async* {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return;

    for (final candidate in candidates) {
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List? ?? [];

      for (final part in parts) {
        final text = part['text'] as String? ?? '';
        final thought = part['thought'] as bool? ?? false;

        if (thought) {
          yield ChatChunk(reasoning: text);
        } else {
          yield ChatChunk(content: text);
        }
      }

      final finishReason = candidate['finishReason'] as String?;
      if (finishReason != null) {
        yield ChatChunk(
          finishReason: finishReason,
          isFinal: true,
        );
      }
    }

    final usageMetadata = json['usageMetadata'] as Map<String, dynamic>?;
    if (usageMetadata != null) {
      yield ChatChunk(
        promptTokens: usageMetadata['promptTokenCount'] as int?,
        completionTokens: usageMetadata['candidatesTokenCount'] as int?,
      );
    }
  }

  @override
  Future<ChatResponse> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async {
    final geminiFormat = _convertToGeminiFormat(messages, settings.systemPrompt ?? '');

    final body = <String, dynamic>{
      ...geminiFormat,
      'generationConfig': {
        'temperature': settings.temperature,
        'topP': settings.topP,
        if (settings.maxTokens != null) 'maxOutputTokens': settings.maxTokens,
        if (settings.stopSequences.isNotEmpty) 'stopSequences': settings.stopSequences,
      },
    };

    try {
      final response = await _dio.post(
        '/models/$model:generateContent',
        data: jsonEncode(body),
      );

      final data = response.data;
      final candidates = data['candidates'] as List? ?? [];
      final usageMetadata = data['usageMetadata'] as Map<String, dynamic>?;

      String textContent = '';
      String reasoningContent = '';

      if (candidates.isNotEmpty) {
        final candidate = candidates[0];
        final content = candidate['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List? ?? [];

        for (final part in parts) {
          final text = part['text'] as String? ?? '';
          final thought = part['thought'] as bool? ?? false;

          if (thought) {
            reasoningContent += text;
          } else {
            textContent += text;
          }
        }
      }

      return ChatResponse(
        content: textContent,
        reasoning: reasoningContent.isNotEmpty ? reasoningContent : null,
        promptTokens: usageMetadata?['promptTokenCount'] as int?,
        completionTokens: usageMetadata?['candidatesTokenCount'] as int?,
        finishReason: candidates.isNotEmpty
            ? candidates[0]['finishReason'] as String?
            : null,
      );
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    if (e.response?.data != null) {
      try {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final error = data['error'];
          if (error is Map<String, dynamic>) {
            return error['message']?.toString() ?? e.message ?? 'Unknown error';
          }
          return data['message']?.toString() ?? e.message ?? 'Unknown error';
        }
        return data.toString();
      } catch (_) {}
    }
    return e.message ?? 'Network error';
  }
}

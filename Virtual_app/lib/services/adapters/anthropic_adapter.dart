import 'dart:convert';
import 'package:dio/dio.dart';

import '../../models/conversation.dart';
import '../../models/endpoint.dart';
import 'llm_adapter.dart';

class AnthropicAdapter implements LLMAdapter {
  final Dio _dio;
  final LlmEndpoint endpoint;

  AnthropicAdapter(this.endpoint)
      : _dio = Dio(BaseOptions(
          baseUrl: endpoint.baseUrl,
          headers: {
            'x-api-key': endpoint.apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
        ));

  @override
  String get protocol => 'anthropic';

  List<Map<String, dynamic>> _convertMessages(
    List<Map<String, dynamic>> messages,
    String systemPrompt,
  ) {
    final systemMessages = <Map<String, dynamic>>[];
    final userAssistantMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      final role = msg['role'] as String?;
      if (role == 'system') {
        systemMessages.add({
          'type': 'text',
          'text': msg['content'] as String? ?? '',
        });
      } else {
        userAssistantMessages.add(msg);
      }
    }

    if (systemPrompt.isNotEmpty && systemMessages.isEmpty) {
      systemMessages.add({
        'type': 'text',
        'text': systemPrompt,
      });
    }

    return [
      if (systemMessages.isNotEmpty)
        {
          'role': 'user',
          'content': [
            for (final s in systemMessages)
              {'type': 'text', 'text': s['text']},
          ],
        },
      ...userAssistantMessages,
    ];
  }

  @override
  Stream<ChatChunk> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async* {
    final convertedMessages = _convertMessages(messages, settings.systemPrompt ?? '');
    final systemContent = settings.systemPrompt ?? '';

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': settings.maxTokens ?? 4096,
      'messages': convertedMessages,
      'stream': true,
      if (systemContent.isNotEmpty)
        'system': [
          {'type': 'text', 'text': systemContent},
        ],
      'temperature': settings.temperature,
      'top_p': settings.topP,
      if (settings.stopSequences.isNotEmpty) 'stop_sequences': settings.stopSequences,
    };

    try {
      final response = await _dio.post(
        '/messages',
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
          yield* _parseSseEvent(json);
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

  Stream<ChatChunk> _parseSseEvent(Map<String, dynamic> event) async* {
    final type = event['type'] as String?;

    switch (type) {
      case 'message_start':
        final message = event['message'] as Map<String, dynamic>?;
        final usage = message?['usage'] as Map<String, dynamic>?;
        if (usage != null) {
          yield ChatChunk(
            promptTokens: usage['input_tokens'] as int?,
          );
        }
        break;

      case 'content_block_start':
        break;

      case 'content_block_delta':
        final delta = event['delta'] as Map<String, dynamic>?;
        if (delta != null) {
          final deltaType = delta['type'] as String?;
          if (deltaType == 'text_delta') {
            yield ChatChunk(content: delta['text'] as String? ?? '');
          } else if (deltaType == 'thinking_delta') {
            yield ChatChunk(reasoning: delta['thinking'] as String? ?? '');
          }
        }
        break;

      case 'content_block_stop':
        break;

      case 'message_delta':
        final delta = event['delta'] as Map<String, dynamic>?;
        final usage = event['usage'] as Map<String, dynamic>?;
        final stopReason = delta?['stop_reason'] as String?;

        yield ChatChunk(
          finishReason: stopReason,
          isFinal: stopReason != null,
          completionTokens: usage?['output_tokens'] as int?,
        );
        break;

      case 'message_stop':
        yield const ChatChunk(isFinal: true);
        break;

      case 'error':
        final error = event['error'] as Map<String, dynamic>?;
        throw Exception(error?['message']?.toString() ?? 'Anthropic API error');
    }
  }

  @override
  Future<ChatResponse> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async {
    final convertedMessages = _convertMessages(messages, settings.systemPrompt ?? '');
    final systemContent = settings.systemPrompt ?? '';

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': settings.maxTokens ?? 4096,
      'messages': convertedMessages,
      if (systemContent.isNotEmpty)
        'system': [
          {'type': 'text', 'text': systemContent},
        ],
      'temperature': settings.temperature,
      'top_p': settings.topP,
      if (settings.stopSequences.isNotEmpty) 'stop_sequences': settings.stopSequences,
    };

    try {
      final response = await _dio.post(
        '/messages',
        data: jsonEncode(body),
      );

      final data = response.data;
      final content = data['content'] as List? ?? [];
      final usage = data['usage'] as Map<String, dynamic>?;

      String textContent = '';
      String reasoningContent = '';

      for (final block in content) {
        final blockType = block['type'] as String?;
        if (blockType == 'text') {
          textContent += block['text'] as String? ?? '';
        } else if (blockType == 'thinking') {
          reasoningContent += block['thinking'] as String? ?? '';
        }
      }

      return ChatResponse(
        content: textContent,
        reasoning: reasoningContent.isNotEmpty ? reasoningContent : null,
        promptTokens: usage?['input_tokens'] as int?,
        completionTokens: usage?['output_tokens'] as int?,
        finishReason: data['stop_reason'] as String?,
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

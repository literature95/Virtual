import 'dart:convert';
import 'package:dio/dio.dart';

import '../../models/conversation.dart';
import '../../models/endpoint.dart';
import 'llm_adapter.dart';

class OpenAIAdapter implements LLMAdapter {
  final Dio _dio;
  final LlmEndpoint endpoint;

  OpenAIAdapter(this.endpoint)
      : _dio = Dio(BaseOptions(
          baseUrl: endpoint.baseUrl,
          headers: {
            'Authorization': 'Bearer ${endpoint.apiKey}',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
        ));

  @override
  String get protocol => 'openai';

  @override
  Stream<ChatChunk> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async* {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
      'stream_options': {'include_usage': true},
      'temperature': settings.temperature,
      'top_p': settings.topP,
      if (settings.maxTokens != null) 'max_tokens': settings.maxTokens,
      if (settings.frequencyPenalty != 0)
        'frequency_penalty': settings.frequencyPenalty,
      if (settings.presencePenalty != 0)
        'presence_penalty': settings.presencePenalty,
      if (settings.stopSequences.isNotEmpty) 'stop': settings.stopSequences,
      ...endpoint.customParams,
    };

    try {
      final response = await _dio.post(
        '/chat/completions',
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
        if (data == '[DONE]') break;

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
    final usage = json['usage'];
    int? promptTokens;
    int? completionTokens;
    if (usage != null) {
      promptTokens = usage['prompt_tokens'] as int?;
      completionTokens = usage['completion_tokens'] as int?;
    }

    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      if (usage != null) {
        yield ChatChunk(
          promptTokens: promptTokens,
          completionTokens: completionTokens,
        );
      }
      return;
    }

    for (final choice in choices) {
      final delta = choice['delta'] as Map<String, dynamic>?;
      final finishReason = choice['finish_reason'] as String?;

      if (delta == null) {
        if (finishReason != null) {
          yield ChatChunk(
            isFinal: true,
            finishReason: finishReason,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
          );
        }
        continue;
      }

      final content = delta['content'] as String? ?? '';
      final reasoning = delta['reasoning_content'] as String? ??
          delta['reasoning'] as String? ??
          delta['thinking'] as String? ??
          '';

      yield ChatChunk(
        content: content,
        reasoning: reasoning,
        finishReason: finishReason,
        isFinal: finishReason != null && finishReason != 'null',
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );
    }
  }

  @override
  Future<ChatResponse> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': settings.temperature,
      'top_p': settings.topP,
      if (settings.maxTokens != null) 'max_tokens': settings.maxTokens,
      if (settings.frequencyPenalty != 0)
        'frequency_penalty': settings.frequencyPenalty,
      if (settings.presencePenalty != 0)
        'presence_penalty': settings.presencePenalty,
      if (settings.stopSequences.isNotEmpty) 'stop': settings.stopSequences,
      ...endpoint.customParams,
    };

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: jsonEncode(body),
      );

      final data = response.data;
      final choices = data['choices'] as List? ?? [];
      if (choices.isEmpty) {
        return const ChatResponse(content: '');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final usage = data['usage'] as Map<String, dynamic>?;

      return ChatResponse(
        content: message?['content']?.toString() ?? '',
        reasoning: message?['reasoning_content']?.toString() ??
            message?['reasoning']?.toString(),
        promptTokens: usage?['prompt_tokens'] as int?,
        completionTokens: usage?['completion_tokens'] as int?,
        finishReason: choices[0]['finish_reason'] as String?,
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

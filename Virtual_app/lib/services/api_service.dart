import '../models/endpoint.dart';
import '../models/conversation.dart';
import 'adapters/llm_adapter.dart';
import 'adapters/openai_adapter.dart';
import 'adapters/anthropic_adapter.dart';
import 'adapters/gemini_adapter.dart';
// 本地模型适配器：nobodywho 仅 io 平台（Android/iOS/桌面）有实现，
// web 默认选 stub，保证 `flutter build web` 可编译（其无 web 实现）。
import 'adapters/nobodywho_adapter_stub.dart'
    if (dart.library.io) 'adapters/nobodywho_adapter.dart';

class StreamChatChunk {
  final String content;
  final String reasoning;
  final bool isFinal;
  final String? finishReason;
  final int? promptTokens;
  final int? completionTokens;

  const StreamChatChunk({
    this.content = '',
    this.reasoning = '',
    this.isFinal = false,
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
  });
}

class ChatCompletionResponse {
  final String content;
  final String? reasoning;
  final int? promptTokens;
  final int? completionTokens;
  final String? finishReason;

  const ChatCompletionResponse({
    required this.content,
    this.reasoning,
    this.promptTokens,
    this.completionTokens,
    this.finishReason,
  });
}

abstract class LlmApiAdapter {
  Stream<StreamChatChunk> chatCompletionsStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  });

  Future<ChatCompletionResponse> chatCompletions({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  });
}

class _LLMAdapterWrapper implements LlmApiAdapter {
  final LLMAdapter _adapter;

  _LLMAdapterWrapper(this._adapter);

  @override
  Stream<StreamChatChunk> chatCompletionsStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async* {
    await for (final chunk in _adapter.chatStream(
      model: model,
      messages: messages,
      settings: settings,
    )) {
      yield StreamChatChunk(
        content: chunk.content,
        reasoning: chunk.reasoning,
        isFinal: chunk.isFinal,
        finishReason: chunk.finishReason,
        promptTokens: chunk.promptTokens,
        completionTokens: chunk.completionTokens,
      );
    }
  }

  @override
  Future<ChatCompletionResponse> chatCompletions({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async {
    final response = await _adapter.chat(
      model: model,
      messages: messages,
      settings: settings,
    );
    return ChatCompletionResponse(
      content: response.content,
      reasoning: response.reasoning,
      promptTokens: response.promptTokens,
      completionTokens: response.completionTokens,
      finishReason: response.finishReason,
    );
  }
}

class OpenAiCompatibleAdapter extends _LLMAdapterWrapper {
  OpenAiCompatibleAdapter(LlmEndpoint endpoint)
      : super(OpenAIAdapter(endpoint));
}

class AnthropicApiAdapter extends _LLMAdapterWrapper {
  AnthropicApiAdapter(LlmEndpoint endpoint) : super(AnthropicAdapter(endpoint));
}

class GeminiApiAdapter extends _LLMAdapterWrapper {
  GeminiApiAdapter(LlmEndpoint endpoint) : super(GeminiAdapter(endpoint));
}

/// 部署型（本地模型）端点 → nobodywho 适配器（web 下为 stub）
class NobodyWhoApiAdapter extends _LLMAdapterWrapper {
  NobodyWhoApiAdapter(LlmEndpoint endpoint)
      : super(NobodyWhoAdapter(endpoint));
}

class ApiService {
  final Map<String, LlmApiAdapter> _adapterCache = {};

  LlmApiAdapter getAdapter(LlmEndpoint endpoint) {
    final cacheKey = endpoint.id;
    if (_adapterCache.containsKey(cacheKey)) {
      return _adapterCache[cacheKey]!;
    }

    final adapter = _createAdapter(endpoint);
    _adapterCache[cacheKey] = adapter;
    return adapter;
  }

  LlmApiAdapter _createAdapter(LlmEndpoint endpoint) {
    // 部署型端点：本地模型，独立于 platform 字段分发（保持接入型三适配器不动）
    if (endpoint.mode == EndpointMode.deploy) {
      return NobodyWhoApiAdapter(endpoint);
    }
    switch (endpoint.platform.toLowerCase()) {
      case 'openai':
      case 'deepseek':
      case 'qwen':
      case 'moonshot':
      case 'glm':
      case 'openrouter':
      case 'xai':
      case 'groq':
      case 'together':
      case 'fireworks':
      case 'minimax':
      case 'grokk':
      case 'poprouter':
      case 'volink':
      case 'custom':
      case 'open_ai':
      case 'default':
        return OpenAiCompatibleAdapter(endpoint);
      case 'anthropic':
      case 'claude':
        return AnthropicApiAdapter(endpoint);
      case 'gemini':
      case 'google':
      case 'vertex_ai':
        return GeminiApiAdapter(endpoint);
      default:
        return OpenAiCompatibleAdapter(endpoint);
    }
  }

  void clearCache(String endpointId) {
    _adapterCache.remove(endpointId);
  }

  void clearAllCache() {
    _adapterCache.clear();
  }
}

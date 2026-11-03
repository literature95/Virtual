import 'dart:async';

import 'package:nobodywho/nobodywho.dart' as nobodywho;

import '../../models/conversation.dart';
import '../../models/endpoint.dart';
import 'llm_adapter.dart';

/// 本地模型适配器 —— nobodywho 6.x（捆绑 llama.cpp）实现。
///
/// 仅在 io 平台（Android / iOS / Windows / macOS / Linux）编译；
/// web 端没有 nobodywho 实现，由条件导入切到 `nobodywho_adapter_stub.dart`
/// （见 api_service.dart 顶部 import）。
///
/// 接入约定：
/// - 每个端点缓存一个 `Chat` 实例（模型加载约 2.6s，见 Gate 0 PoC 实测），
///   端点参数（模型路径 / contextSize / useGpu）变化时重建；
/// - 采样参数取端点上的类型安全字段（temperature / topP / maxTokens），
///   不读会话级 ChatSettings（本地部署语义以端点配置为准）；
/// - 通过 `complete()` 传入完整 messages 替换引擎历史，保证与云端适配器
///   一致的无状态语义（上下文仍由 context_window_service 两遍拼装决定）。
class NobodyWhoAdapter implements LLMAdapter {
  NobodyWhoAdapter(this.endpoint);

  final LlmEndpoint endpoint;

  static bool _inited = false;
  static final Map<String, _CachedChat> _cache = {};

  @override
  String get protocol => 'nobodywho';

  @override
  Stream<ChatChunk> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) {
    final controller = StreamController<ChatChunk>();
    nobodywho.Chat? activeChat;

    controller.onCancel = () {
      // 上层停止生成（或流结束）时，别让引擎继续烧 CPU
      activeChat?.stopGeneration();
    };

    _generate(controller, messages, (c) => activeChat = c);
    return controller.stream;
  }

  @override
  Future<ChatResponse> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  }) async {
    final content = StringBuffer();
    final reasoning = StringBuffer();
    int? promptTokens;
    int? completionTokens;
    String? finishReason;
    await for (final chunk
        in chatStream(model: model, messages: messages, settings: settings)) {
      content.write(chunk.content);
      reasoning.write(chunk.reasoning);
      promptTokens = chunk.promptTokens ?? promptTokens;
      completionTokens = chunk.completionTokens ?? completionTokens;
      finishReason = chunk.finishReason ?? finishReason;
    }
    return ChatResponse(
      content: content.toString(),
      reasoning: reasoning.isEmpty ? null : reasoning.toString(),
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      finishReason: finishReason,
    );
  }

  Future<void> _generate(
    StreamController<ChatChunk> controller,
    List<Map<String, dynamic>> messages,
    void Function(nobodywho.Chat chat) onChat,
  ) async {
    try {
      if (endpoint.localModelPath.trim().isEmpty) {
        throw StateError('本地模型路径未配置，请在端点「部署」设置中填写 GGUF 文件路径');
      }
      if (!_inited) {
        await nobodywho.NobodyWho.init();
        _inited = true;
      }
      final chat = await _resolveChat();
      onChat(chat);

      final nMessages = _toMessages(messages);
      final stream = chat.complete(nMessages, sampler: _sampler());

      final content = StringBuffer();
      final reasoning = StringBuffer();
      var inReasoning = false;
      var genTokens = 0;
      var finish = 'stop';

      await for (final token in stream) {
        var toReasoning = inReasoning;
        if (!inReasoning && _reasoningOpen.any(token.contains)) {
          inReasoning = true;
          toReasoning = true;
        } else if (inReasoning && _reasoningClose.any(token.contains)) {
          inReasoning = false;
        }

        if (toReasoning) {
          reasoning.write(token);
          controller.add(ChatChunk(reasoning: token));
        } else {
          content.write(token);
          controller.add(ChatChunk(content: token));
        }

        genTokens++;
        if (genTokens >= endpoint.maxTokens && finish == 'stop') {
          finish = 'length';
          chat.stopGeneration(); // 达到端点 maxTokens，要求引擎收尾
        }
      }

      controller.add(ChatChunk(
        isFinal: true,
        finishReason: finish,
        // 本地引擎无 prompt/completion 计数接口，usage 留空由上层兼容
        completionTokens: genTokens,
      ));
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(StateError('本地模型推理失败：$e'));
      }
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  /// 缓存/复用 Chat：模型路径、contextSize、useGpu 任一变化即重建。
  Future<nobodywho.Chat> _resolveChat() async {
    final cached = _cache[endpoint.id];
    if (cached != null &&
        cached.modelPath == endpoint.localModelPath &&
        cached.contextSize == endpoint.contextSize &&
        cached.useGpu == endpoint.useGpu) {
      return cached.chat;
    }
    final chat = await nobodywho.Chat.fromPath(
      modelPath: endpoint.localModelPath.trim(),
      contextSize: endpoint.contextSize,
      useGpu: endpoint.useGpu,
      threadCount: endpoint.threadCount > 0 ? endpoint.threadCount : null,
    );
    _cache[endpoint.id] = _CachedChat(
      chat: chat,
      modelPath: endpoint.localModelPath.trim(),
      contextSize: endpoint.contextSize,
      useGpu: endpoint.useGpu,
    );
    return chat;
  }

  /// 采样器：端点 temperature + top-p 层叠后由 `dist()` 收口
  nobodywho.SamplerConfig _sampler() => nobodywho.SamplerBuilder()
      .temperature(temperature: endpoint.temperature)
      .topP(topP: endpoint.topP, minKeep: 1)
      .dist();

  static const List<String> _reasoningOpen = [
    '<｜begin▁of▁thought｜>',
    '<think>',
    '<thought>',
    '<thinking>',
  ];
  static const List<String> _reasoningClose = [
    '<｜end▁of▁thought｜>',
    '</think>',
    '</thought>',
    '</thinking>',
  ];

  List<nobodywho.Message> _toMessages(List<Map<String, dynamic>> messages) =>
      messages.map((m) {
        final role = m['role']?.toString() ?? 'user';
        final text = _textOf(m['content']);
        return switch (role) {
          'system' => nobodywho.systemMessage(text),
          'assistant' => nobodywho.assistantMessage(text),
          _ => nobodywho.userMessage(text),
        };
      }).toList();

  String _textOf(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final buf = StringBuffer();
      for (final part in content) {
        if (part is Map && part['type'] == 'text') {
          buf.writeln('${part['text'] ?? ''}');
        } else if (part is String) {
          buf.writeln(part);
        }
      }
      return buf.toString().trim();
    }
    return content?.toString() ?? '';
  }
}

class _CachedChat {
  final nobodywho.Chat chat;
  final String modelPath;
  final int contextSize;
  final bool useGpu;

  _CachedChat({
    required this.chat,
    required this.modelPath,
    required this.contextSize,
    required this.useGpu,
  });
}

import '../../models/conversation.dart';

class ChatChunk {
  final String content;
  final String reasoning;
  final bool isFinal;
  final String? finishReason;
  final int? promptTokens;
  final int? completionTokens;

  const ChatChunk({
    this.content = '',
    this.reasoning = '',
    this.isFinal = false,
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
  });
}

class ChatResponse {
  final String content;
  final String? reasoning;
  final int? promptTokens;
  final int? completionTokens;
  final String? finishReason;

  const ChatResponse({
    required this.content,
    this.reasoning,
    this.promptTokens,
    this.completionTokens,
    this.finishReason,
  });
}

abstract class LLMAdapter {
  Stream<ChatChunk> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  });

  Future<ChatResponse> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
  });

  String get protocol;
}

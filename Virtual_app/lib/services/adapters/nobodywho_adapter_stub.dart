import 'dart:async';

import '../../models/conversation.dart';
import '../../models/endpoint.dart';
import 'llm_adapter.dart';

/// 本地模型适配器的 **Web stub**。
///
/// nobodywho（llama.cpp 原生库）没有 web 实现，web 目标下由条件导入选中
/// 本文件（见 api_service.dart 顶部：
/// `import '..._stub.dart' if (dart.library.io) '..._real.dart'`），
/// 保证 `flutter build web` 可编译，运行时给出明确错误而非崩溃。
class NobodyWhoAdapter implements LLMAdapter {
  NobodyWhoAdapter(this.endpoint);

  final LlmEndpoint endpoint;

  static const _message = '当前平台（Web）不支持本地模型部署，请改用云端接入接口';

  @override
  String get protocol => 'nobodywho';

  @override
  Stream<ChatChunk> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
    String? conversationId,
  }) =>
      Stream<ChatChunk>.error(UnsupportedError(_message));

  @override
  Future<ChatResponse> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
    String? conversationId,
  }) async =>
      throw UnsupportedError(_message);
}

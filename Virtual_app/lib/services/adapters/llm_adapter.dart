import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/conversation.dart';

class ChatChunk {
  final String content;
  final String reasoning;
  final bool isFinal;
  final String? finishReason;
  final int? promptTokens;
  final int? completionTokens;

  /// 本地模型性能：首字延迟（ms）与生成速度（tok/s）。
  /// 仅最终块携带，云端适配器恒为 null。
  final int? firstTokenMs;
  final double? tokensPerSecond;

  const ChatChunk({
    this.content = '',
    this.reasoning = '',
    this.isFinal = false,
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
    this.firstTokenMs,
    this.tokensPerSecond,
  });
}

class ChatResponse {
  final String content;
  final String? reasoning;
  final int? promptTokens;
  final int? completionTokens;
  final String? finishReason;
  final int? firstTokenMs;
  final double? tokensPerSecond;

  const ChatResponse({
    required this.content,
    this.reasoning,
    this.promptTokens,
    this.completionTokens,
    this.finishReason,
    this.firstTokenMs,
    this.tokensPerSecond,
  });
}

abstract class LLMAdapter {
  /// [conversationId] 仅本地模型适配器使用：按会话隔离推理上下文，
  /// 云端适配器无状态，忽略该参数。
  Stream<ChatChunk> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
    String? conversationId,
  });

  Future<ChatResponse> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
    String? conversationId,
  });

  String get protocol;
}

/// 本地模型增量上下文能力（由 nobodywho 适配器实现，云端适配器不实现）。
///
/// 提示词组装层需要引擎 tokenizer 来压缩角色卡/裁历史；上下文生命周期
/// （复用、75% 裁剪、会话释放）也由适配器负责，避免组装逻辑散落在适配器里。
abstract class LocalContextAdapter implements LLMAdapter {
  /// 设置本轮使用的 system prompt（压缩角色卡，由组装层产出）。
  void setNextSystemPrompt(String? prompt);

  /// 返回当前会话的 token 计数器；模型未配置时返回 null。
  Future<Future<int> Function(String text)?> tokenCounter(
    String conversationId,
  );

  /// 释放指定会话的推理上下文（切换 / 删除 / 清空对话时调用）。
  Future<void> releaseLocalContext(String conversationId);
}

/// 把流式响应体安全解码为 SSE 行流（三个适配器共用）。
///
/// ⚠️ 必须走 `utf8.decoder.bind(raw)`，绝不能写 `raw.transform(utf8.decoder)`：
/// dio 的 `ResponseBody.stream` 运行时类型是 `Stream<Uint8List>`，而 `Utf8Decoder`
/// 实现的是 `StreamTransformer<List<int>, String>`。`transform` 的泛型实参由接收者
/// 的**运行时**类型实参决定（`as Stream<List<int>>` 只改静态类型，不改运行时实参），
/// 两者不一致时必抛：
///   type 'Utf8Decoder' is not a subtype of type
///   'StreamTransformer<Uint8List, String>' of 'streamTransformer'
/// 而 `bind` 的形参是 `Stream<List<int>>`，协变方向正确，可安全通过检查。
/// 回归：`test/sse_decode_test.dart`。
Stream<String> decodeSseLines(Stream<List<int>> raw) =>
    utf8.decoder.bind(raw).transform(const LineSplitter());

/// 从 [DioException] 提取可读的错误信息（各适配器共用）。
///
/// 流式请求（ResponseType.stream）失败时，`response.data` 是 ResponseBody
/// 对象——直接 toString 在 Web release 构建里只会得到
/// "Instance of 'minified:...'"（类名被压缩），必须读出字节流再解析 JSON，
/// 才能拿到服务端返回的真实错误（如 "invalid temperature: only 1 is
/// allowed for this model"）。
Future<String> extractDioErrorMessage(DioException e) async {
  try {
    final data = e.response?.data;
    String? text;
    if (data is ResponseBody) {
      text = await utf8.decoder.bind(data.stream).join();
    } else if (data is String) {
      text = data;
    }
    if (text != null && text.trim().isNotEmpty) {
      final json = jsonDecode(text);
      if (json is Map) {
        final error = json['error'];
        if (error is Map) {
          return error['message']?.toString() ?? text;
        }
        return (json['message'] ?? json['msg'])?.toString() ?? text;
      }
      return text;
    }
  } catch (_) {}
  return e.message ?? '网络错误（${e.type.name}）';
}

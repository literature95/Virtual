import '../models/chat_message.dart';

/// 上下文窗口服务：把历史消息裁剪到模型上下文预算内（纯函数，可测）
///
/// 背景：此前发送/重新生成把**全量历史**发给模型——长对话 token 线性
/// 暴涨，超出模型上下文窗口直接报错。本服务从最新往旧滑动截断：
/// - 预算 = maxTokens - 系统预留（system/世界书/预设的估算）- 回复预留
/// - token 估算：1 token ≈ 2 字符（中文为主的粗估，宁小勿大）
/// - 从旧端对齐到 user 消息开始（多数模型对序列开头语义有要求）
/// - 单条消息独超预算时截断其 content 前缀兜底
class ContextWindowService {
  ContextWindowService._();

  /// 粗略 token 估算：中文约 1 token/1.5~2 字符，这里取 2 字符（保守）
  static int estimateTokens(String text) => (text.length / 2).ceil();

  /// 裁剪历史消息
  ///
  /// [maxTokens] 模型上下文长度（来自 LlmModelDescriptor.contextLength，
  /// 未知时调用方给 8192 一类的保守值）。
  /// [reservedForSystem] system/世界书/预设占用的估算 token。
  /// [reservedForReply] 给模型回复预留的空间，默认 512。
  static List<ChatMessage> trim(
    List<ChatMessage> history, {
    required int maxTokens,
    int reservedForSystem = 0,
    int reservedForReply = 512,
  }) {
    final budget = maxTokens - reservedForSystem - reservedForReply;
    if (budget <= 0) return const [];

    int cost(ChatMessage m) =>
        estimateTokens(m.content) + estimateTokens(m.reasoning ?? '');

    // 1) 从最新往旧累加，找出预算内的最大后缀
    final newestFirst = <ChatMessage>[];
    var used = 0;
    for (var i = history.length - 1; i >= 0; i--) {
      final c = cost(history[i]);
      if (used + c > budget) break;
      newestFirst.add(history[i]);
      used += c;
    }
    final kept = newestFirst.reversed.toList();

    // 2) 旧端对齐到 user 消息开始（能对齐时），保证序列开头语义正确
    while (kept.isNotEmpty && kept.first.role != MessageRole.user) {
      kept.removeAt(0);
    }

    // 3) 兜底：一条都放不下但历史非空 → 截断最新一条的 content 前缀
    if (kept.isEmpty && history.isNotEmpty) {
      final last = history.last;
      final maxChars = (budget * 2).clamp(0, last.content.length);
      kept.add(last.copyWith(content: last.content.substring(0, maxChars)));
    }
    return kept;
  }
}

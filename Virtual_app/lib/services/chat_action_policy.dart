import '../models/chat_message.dart';

/// 「继续生成」隐藏指令。
///
/// 以用户消息写入数据库（`isHidden = true`），只在 Prompt 里可见，
/// 聊天列表不渲染、不计入可见消息数。
const String kContinueInstruction = '（继续上文，不要重复已写内容）';

/// 最后一条可见消息是否可以继续 / 生成选项。
///
/// 条件：不在生成中、列表非空、最后一条是**已完成的 AI 回复**
/// （生成占位气泡与错误气泡都不算）。
bool canActOnLastReply(
  List<ChatMessage> visibleMessages, {
  required bool isGenerating,
}) {
  if (isGenerating) return false;
  if (visibleMessages.isEmpty) return false;
  final last = visibleMessages.last;
  return last.role == MessageRole.assistant &&
      !last.isGenerating &&
      !last.isError;
}

import 'chat_message.dart';

/// Agent 运行类型
enum AgentRunKind {
  chat, // 普通聊天
  toolCalling, // 工具调用
  multiStep, // 多步推理
  groupChat, // 群聊
  auto, // 自动模式
}

/// Agent 运行阶段
enum AgentRunPhase {
  initializing,
  loadingContext,
  preflight,
  generating,
  toolCalling,
  reasoning,
  finalizing,
  done,
  failed,
}

/// Agent 运行提交模式
enum AgentRunCommitMode {
  stream, // 流式提交
  batch, // 批量提交
  manual, // 手动提交
}

/// Agent 生成结果类型
enum AgentGenerationOutcomeKind {
  success,
  partial,
  failed,
  cancelled,
  error,
}

/// Agent 生成更新类型
enum AgentGenerationUpdateKind {
  text,
  reasoning,
  toolCall,
  toolResult,
  image,
  status,
  error,
}

/// Agent 步骤结果类型
enum AgentStepOutcomeKind {
  success,
  failed,
  skipped,
  error,
}

/// Agent 步骤更新类型
enum AgentStepUpdateKind {
  started,
  progress,
  completed,
  failed,
}

/// Agent 生成来源
enum AgentGenerationSource {
  model,
  tool,
  plugin,
  cache,
  fallback,
}

/// Agent 运行
class AgentRun {
  final String id;
  final String conversationId;
  final AgentRunKind kind;
  final AgentRunPhase phase;
  final AgentRunCommitMode commitMode;
  final List<ChatMessage> messages;
  final List<AgentStep> steps;
  final bool isCancelled;
  final DateTime startTime;
  final DateTime? endTime;
  final int? tokenUsage;
  final String? errorMessage;

  AgentRun({
    required this.id,
    required this.conversationId,
    this.kind = AgentRunKind.chat,
    this.phase = AgentRunPhase.initializing,
    this.commitMode = AgentRunCommitMode.stream,
    this.messages = const [],
    this.steps = const [],
    this.isCancelled = false,
    required this.startTime,
    this.endTime,
    this.tokenUsage,
    this.errorMessage,
  });

  AgentRun copyWith({
    String? id,
    String? conversationId,
    AgentRunKind? kind,
    AgentRunPhase? phase,
    AgentRunCommitMode? commitMode,
    List<ChatMessage>? messages,
    List<AgentStep>? steps,
    bool? isCancelled,
    DateTime? startTime,
    DateTime? endTime,
    int? tokenUsage,
    String? errorMessage,
  }) {
    return AgentRun(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      kind: kind ?? this.kind,
      phase: phase ?? this.phase,
      commitMode: commitMode ?? this.commitMode,
      messages: messages ?? this.messages,
      steps: steps ?? this.steps,
      isCancelled: isCancelled ?? this.isCancelled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tokenUsage: tokenUsage ?? this.tokenUsage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Agent 步骤
class AgentStep {
  final String id;
  final int stepNumber;
  final String title;
  final String description;
  final AgentStepOutcomeKind outcome;
  final AgentRunPhase phase;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, dynamic> metadata;

  AgentStep({
    required this.id,
    required this.stepNumber,
    required this.title,
    this.description = '',
    this.outcome = AgentStepOutcomeKind.success,
    required this.phase,
    required this.startTime,
    this.endTime,
    this.metadata = const {},
  });
}

/// Agent 运行取消结果
class AgentRunCancelResult {
  final bool success;
  final String? reason;
  final DateTime cancelledAt;

  AgentRunCancelResult({
    required this.success,
    this.reason,
    DateTime? cancelledAt,
  }) : cancelledAt = cancelledAt ?? DateTime.now();
}

/// Agent 运行时间线适配器
class AgentRunTimelineAdapter {
  final String agentRunId;
  final String conversationId;
  final List<String> messageIds;

  AgentRunTimelineAdapter({
    required this.agentRunId,
    required this.conversationId,
    this.messageIds = const [],
  });
}

/// 聊天时间线 Agent 生命周期
class ChatTimelineAgentRunLifecycle {
  final String agentRunId;
  final String conversationId;
  final AgentRunPhase phase;
  final DateTime updatedAt;

  ChatTimelineAgentRunLifecycle({
    required this.agentRunId,
    required this.conversationId,
    required this.phase,
    required this.updatedAt,
  });
}

/// 聊天 Agent 预检失败
class ChatAgentRunPreflightFailure implements Exception {
  final String reason;
  final String? details;

  ChatAgentRunPreflightFailure(this.reason, {this.details});
}

/// Agent 运行上下文加载异常
class AgentRunContextLoadException implements Exception {
  final String message;
  final String contextType;

  AgentRunContextLoadException(this.message, {this.contextType = 'unknown'});
}

/// 生成会话失效异常
class GenerationSessionInvalidatedException implements Exception {
  final String reason;
  GenerationSessionInvalidatedException(this.reason);
}

/// LLM 会话失效异常
class LlmSessionInvalidatedException implements Exception {
  final String reason;
  LlmSessionInvalidatedException(this.reason);
}

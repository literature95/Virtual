/// 消息角色
enum MessageRole {
  system,
  user,
  assistant,
  tool,
}

/// 消息来源
enum MessageSource {
  user,
  model,
  system,
  tool,
  plugin,
}

/// 消息变体
enum MessageVariant {
  standard,
  reasoning,
  toolCall,
  toolResult,
  error,
}

/// 气泡显示类型
enum BubbleDisplayType {
  bubble, // 气泡样式
  flat, // 平板样式
  // 可能还有其他类型
}

/// 消息显示模式
enum MessageDisplayMode {
  message, // 消息列表模式
  visual, // 视觉/VN 模式
}

/// 气泡样式
enum BubbleStyle {
  standard,
  flat,
  minimal,
  custom,
}

/// 气泡字体样式
enum BubbleFontStyle {
  normal,
  serif,
  mono,
  cursive,
}

/// 头像样式
enum AvatarStyle {
  circle,
  square,
  rounded,
  none,
}

/// 群聊头像样式
enum GroupAvatarStyle {
  stacked,
  sideBySide,
  carousel,
  hidden,
}

/// 附件类型
enum MessageAttachmentType {
  image,
  file,
  audio,
  video,
}

/// 消息附件
class MessageAttachment {
  final String id;
  final MessageAttachmentType type;
  final String path;
  final String? name;
  final int? size;
  final String? mimeType;
  final String? url;

  MessageAttachment({
    required this.id,
    required this.type,
    required this.path,
    this.name,
    this.size,
    this.mimeType,
    this.url,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'path': path,
        'name': name,
        'size': size,
        'mimeType': mimeType,
        'url': url,
      };

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        id: json['id'] ?? '',
        type: MessageAttachmentType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => MessageAttachmentType.file,
        ),
        path: json['path'] ?? '',
        name: json['name'],
        size: json['size'],
        mimeType: json['mimeType'],
        url: json['url'],
      );
}

/// 消息翻译数据
class MessageTranslation {
  final String? translatedText;
  final String? targetLanguage;
  final String? sourceLanguage;
  final bool isTranslated;

  MessageTranslation({
    this.translatedText,
    this.targetLanguage,
    this.sourceLanguage,
    this.isTranslated = false,
  });

  Map<String, dynamic> toJson() => {
        'translatedText': translatedText,
        'targetLanguage': targetLanguage,
        'sourceLanguage': sourceLanguage,
        'isTranslated': isTranslated,
      };

  factory MessageTranslation.fromJson(Map<String, dynamic> json) =>
      MessageTranslation(
        translatedText: json['translatedText'],
        targetLanguage: json['targetLanguage'],
        sourceLanguage: json['sourceLanguage'],
        isTranslated: json['isTranslated'] ?? false,
      );
}

/// 工具调用
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String? result;
  final bool isDone;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.result,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'result': result,
        'isDone': isDone,
      };

  factory ToolCall.fromJson(Map<String, dynamic> json) => ToolCall(
        id: json['id'],
        name: json['name'],
        arguments: Map<String, dynamic>.from(json['arguments'] ?? {}),
        result: json['result'],
        isDone: json['isDone'] ?? false,
      );
}

/// 聊天消息模型
///
/// 对应原应用 Message 实体（ObjectBox）。
/// 逆向证据：pp.txt Eec 对象 [pp+0x3cc8] ~ [pp+0x3e40] 范围内的属性定义。
/// 已确认字段：content, conversationId, reasoning, speakerName, speakerAvatar,
/// timestamp, hidden, dbAttachments, dbTranslation, dbToolTranscript, dbVariables。
class ChatMessage {
  final String id;
  final String conversationId;
  final MessageRole role;
  final MessageSource source;
  final MessageVariant variant;

  /// 消息内容
  final String content;

  /// 推理/思考过程（reasoning / thinking）
  /// 证据：pp.txt [pp+0x3cf8] String: "reasoning"
  final String? reasoning;

  /// 发言人名称（群聊中区分不同角色）
  /// 证据：pp.txt [pp+0x3d08] String: "speakerName"
  final String? speakerName;

  /// 发言人头像路径
  /// 证据：pp.txt [pp+0x3d18] String: "speakerAvatar"
  final String? speakerAvatar;

  /// 附件列表（图片、文件等）
  /// 证据：pp.txt [pp+0x3d48] String: "dbAttachments"
  final List<MessageAttachment> attachments;

  /// 工具调用列表
  /// 证据：pp.txt [pp+0x3d78] String: "dbToolTranscript"
  final List<ToolCall> toolCalls;

  /// 翻译数据
  /// 证据：pp.txt [pp+0x3d58] String: "dbTranslation"
  final MessageTranslation? translation;

  /// 消息级变量（由宏变量系统写入）
  /// 证据：pp.txt [pp+0x3d68] String: "dbVariables"
  final Map<String, dynamic> variables;

  // === 显示样式字段（对应 db* 系列属性） ===

  /// 用户气泡样式
  /// 证据：pp.txt [pp+0x3da8] String: "dbUserBubbleStyle"
  final BubbleStyle? userBubbleStyle;

  /// 角色气泡样式
  /// 证据：pp.txt [pp+0x3db8] String: "dbCharacterBubbleStyle"
  final BubbleStyle? characterBubbleStyle;

  /// 用户气泡字体样式
  /// 证据：pp.txt [pp+0x3dc8] String: "dbUserBubbleFontStyle"
  final BubbleFontStyle? userBubbleFontStyle;

  /// 角色气泡字体样式
  /// 证据：pp.txt [pp+0x3dd8] String: "dbCharacterBubbleFontStyle"
  final BubbleFontStyle? characterBubbleFontStyle;

  /// 用户头像样式
  /// 证据：pp.txt [pp+0x3de8] String: "dbUserAvatarStyle"
  final AvatarStyle? userAvatarStyle;

  /// 角色头像样式
  /// 证据：pp.txt [pp+0x3df8] String: "dbCharacterAvatarStyle"
  final AvatarStyle? characterAvatarStyle;

  /// 是否为官方/系统消息
  /// 证据：pp.txt [pp+0x3e28] String: "isOfficial"
  final bool isOfficial;

  /// 背景样式（JSON 序列化）
  /// 证据：pp.txt [pp+0x3e48] String: "dbBackgroundStyle"
  final Map<String, dynamic>? backgroundStyle;

  /// 思考/推理样式（JSON 序列化）
  /// 证据：pp.txt [pp+0x3e58] String: "dbThinkingStyle"
  final Map<String, dynamic>? thinkingStyle;

  /// 控制台样式（JSON 序列化）
  /// 证据：pp.txt [pp+0x3e78] String: "dbConsoleStyle"
  final Map<String, dynamic>? consoleStyle;

  /// 气泡显示类型
  /// 证据：pp.txt [pp+0x3e88] String: "dbBubbleDisplayType"
  final BubbleDisplayType? bubbleDisplayType;

  /// 显示模式（消息模式/视觉模式）
  /// 证据：pp.txt [pp+0x3ea0] String: "dbDisplayMode"
  final MessageDisplayMode? displayMode;

  /// VN 模式气泡高度比
  /// 证据：pp.txt [pp+0x3eb8] String: "dbVisualNovelBubbleHeightRatio"
  final double? visualNovelBubbleHeightRatio;

  /// 状态栏样式（JSON 序列化）
  /// 证据：pp.txt [pp+0x3e68] String: "dbStatusBarStyle"
  final Map<String, dynamic>? statusBarStyle;

  // === 状态字段 ===

  final bool isError;
  final bool isGenerating;
  final bool isHidden; // 证据：pp.txt [pp+0x3d38] String: "hidden"

  /// 消息修订号（用于乐观锁/增量同步）
  final int revision;

  /// Token 统计
  final int? promptTokens;
  final int? completionTokens;

  /// 时间戳
  /// 证据：pp.txt [pp+0x3d28] String: "timestamp"
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// 图片路径（向后兼容，现统一用 attachments）
  @Deprecated('Use attachments instead')
  List<String> get imagePaths => attachments
      .where((a) => a.type == MessageAttachmentType.image)
      .map((a) => a.path)
      .toList();

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    this.source = MessageSource.model,
    this.variant = MessageVariant.standard,
    required this.content,
    this.reasoning,
    this.speakerName,
    this.speakerAvatar,
    this.attachments = const [],
    this.toolCalls = const [],
    this.translation,
    this.variables = const {},
    this.userBubbleStyle,
    this.characterBubbleStyle,
    this.userBubbleFontStyle,
    this.characterBubbleFontStyle,
    this.userAvatarStyle,
    this.characterAvatarStyle,
    this.isOfficial = false,
    this.backgroundStyle,
    this.thinkingStyle,
    this.consoleStyle,
    this.bubbleDisplayType,
    this.displayMode,
    this.visualNovelBubbleHeightRatio,
    this.statusBarStyle,
    this.isError = false,
    this.isGenerating = false,
    this.isHidden = false,
    this.revision = 1,
    this.promptTokens,
    this.completionTokens,
    required this.createdAt,
    this.updatedAt,
  });

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    MessageSource? source,
    MessageVariant? variant,
    String? content,
    String? reasoning,
    String? speakerName,
    String? speakerAvatar,
    List<MessageAttachment>? attachments,
    List<ToolCall>? toolCalls,
    MessageTranslation? translation,
    Map<String, dynamic>? variables,
    BubbleStyle? userBubbleStyle,
    BubbleStyle? characterBubbleStyle,
    BubbleFontStyle? userBubbleFontStyle,
    BubbleFontStyle? characterBubbleFontStyle,
    AvatarStyle? userAvatarStyle,
    AvatarStyle? characterAvatarStyle,
    bool? isOfficial,
    Map<String, dynamic>? backgroundStyle,
    Map<String, dynamic>? thinkingStyle,
    Map<String, dynamic>? consoleStyle,
    BubbleDisplayType? bubbleDisplayType,
    MessageDisplayMode? displayMode,
    double? visualNovelBubbleHeightRatio,
    Map<String, dynamic>? statusBarStyle,
    bool? isError,
    bool? isGenerating,
    bool? isHidden,
    int? revision,
    int? promptTokens,
    int? completionTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      source: source ?? this.source,
      variant: variant ?? this.variant,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      speakerName: speakerName ?? this.speakerName,
      speakerAvatar: speakerAvatar ?? this.speakerAvatar,
      attachments: attachments ?? this.attachments,
      toolCalls: toolCalls ?? this.toolCalls,
      translation: translation ?? this.translation,
      variables: variables ?? this.variables,
      userBubbleStyle: userBubbleStyle ?? this.userBubbleStyle,
      characterBubbleStyle: characterBubbleStyle ?? this.characterBubbleStyle,
      userBubbleFontStyle: userBubbleFontStyle ?? this.userBubbleFontStyle,
      characterBubbleFontStyle:
          characterBubbleFontStyle ?? this.characterBubbleFontStyle,
      userAvatarStyle: userAvatarStyle ?? this.userAvatarStyle,
      characterAvatarStyle: characterAvatarStyle ?? this.characterAvatarStyle,
      isOfficial: isOfficial ?? this.isOfficial,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      thinkingStyle: thinkingStyle ?? this.thinkingStyle,
      consoleStyle: consoleStyle ?? this.consoleStyle,
      bubbleDisplayType: bubbleDisplayType ?? this.bubbleDisplayType,
      displayMode: displayMode ?? this.displayMode,
      visualNovelBubbleHeightRatio:
          visualNovelBubbleHeightRatio ?? this.visualNovelBubbleHeightRatio,
      statusBarStyle: statusBarStyle ?? this.statusBarStyle,
      isError: isError ?? this.isError,
      isGenerating: isGenerating ?? this.isGenerating,
      isHidden: isHidden ?? this.isHidden,
      revision: revision ?? this.revision + 1,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'role': role.name,
        'source': source.name,
        'variant': variant.name,
        'content': content,
        'reasoning': reasoning,
        'speakerName': speakerName,
        'speakerAvatar': speakerAvatar,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
        'translation': translation?.toJson(),
        'variables': variables,
        'userBubbleStyle': userBubbleStyle?.name,
        'characterBubbleStyle': characterBubbleStyle?.name,
        'userBubbleFontStyle': userBubbleFontStyle?.name,
        'characterBubbleFontStyle': characterBubbleFontStyle?.name,
        'userAvatarStyle': userAvatarStyle?.name,
        'characterAvatarStyle': characterAvatarStyle?.name,
        'isOfficial': isOfficial,
        'backgroundStyle': backgroundStyle,
        'thinkingStyle': thinkingStyle,
        'consoleStyle': consoleStyle,
        'bubbleDisplayType': bubbleDisplayType?.name,
        'displayMode': displayMode?.name,
        'visualNovelBubbleHeightRatio': visualNovelBubbleHeightRatio,
        'statusBarStyle': statusBarStyle,
        'isError': isError,
        'isGenerating': isGenerating,
        'isHidden': isHidden,
        'revision': revision,
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        conversationId: json['conversationId'] ?? '',
        role: MessageRole.values.firstWhere((e) => e.name == json['role'],
            orElse: () => MessageRole.assistant),
        source: MessageSource.values.firstWhere((e) => e.name == json['source'],
            orElse: () => MessageSource.model),
        variant: MessageVariant.values.firstWhere(
            (e) => e.name == json['variant'],
            orElse: () => MessageVariant.standard),
        content: json['content'] ?? '',
        reasoning: json['reasoning'],
        speakerName: json['speakerName'],
        speakerAvatar: json['speakerAvatar'],
        attachments: (json['attachments'] as List?)
                ?.map((a) => MessageAttachment.fromJson(a))
                .toList() ??
            // 向后兼容：从 imagePaths 迁移
            (json['imagePaths'] as List?)
                ?.map((path) => MessageAttachment(
                      id: path,
                      type: MessageAttachmentType.image,
                      path: path,
                    ))
                .toList() ??
            [],
        toolCalls: (json['toolCalls'] as List?)
                ?.map((t) => ToolCall.fromJson(t))
                .toList() ??
            [],
        translation: json['translation'] != null
            ? MessageTranslation.fromJson(json['translation'])
            : null,
        variables: Map<String, dynamic>.from(json['variables'] ?? {}),
        userBubbleStyle: json['userBubbleStyle'] != null
            ? BubbleStyle.values.firstWhere(
                (e) => e.name == json['userBubbleStyle'],
                orElse: () => BubbleStyle.standard,
              )
            : null,
        characterBubbleStyle: json['characterBubbleStyle'] != null
            ? BubbleStyle.values.firstWhere(
                (e) => e.name == json['characterBubbleStyle'],
                orElse: () => BubbleStyle.standard,
              )
            : null,
        userBubbleFontStyle: json['userBubbleFontStyle'] != null
            ? BubbleFontStyle.values.firstWhere(
                (e) => e.name == json['userBubbleFontStyle'],
                orElse: () => BubbleFontStyle.normal,
              )
            : null,
        characterBubbleFontStyle: json['characterBubbleFontStyle'] != null
            ? BubbleFontStyle.values.firstWhere(
                (e) => e.name == json['characterBubbleFontStyle'],
                orElse: () => BubbleFontStyle.normal,
              )
            : null,
        userAvatarStyle: json['userAvatarStyle'] != null
            ? AvatarStyle.values.firstWhere(
                (e) => e.name == json['userAvatarStyle'],
                orElse: () => AvatarStyle.circle,
              )
            : null,
        characterAvatarStyle: json['characterAvatarStyle'] != null
            ? AvatarStyle.values.firstWhere(
                (e) => e.name == json['characterAvatarStyle'],
                orElse: () => AvatarStyle.circle,
              )
            : null,
        isOfficial: json['isOfficial'] ?? false,
        backgroundStyle: json['backgroundStyle'] != null
            ? Map<String, dynamic>.from(json['backgroundStyle'])
            : null,
        thinkingStyle: json['thinkingStyle'] != null
            ? Map<String, dynamic>.from(json['thinkingStyle'])
            : null,
        consoleStyle: json['consoleStyle'] != null
            ? Map<String, dynamic>.from(json['consoleStyle'])
            : null,
        bubbleDisplayType: json['bubbleDisplayType'] != null
            ? BubbleDisplayType.values.firstWhere(
                (e) => e.name == json['bubbleDisplayType'],
                orElse: () => BubbleDisplayType.bubble,
              )
            : null,
        displayMode: json['displayMode'] != null
            ? MessageDisplayMode.values.firstWhere(
                (e) => e.name == json['displayMode'],
                orElse: () => MessageDisplayMode.message,
              )
            : null,
        visualNovelBubbleHeightRatio:
            (json['visualNovelBubbleHeightRatio'] as num?)?.toDouble(),
        statusBarStyle: json['statusBarStyle'] != null
            ? Map<String, dynamic>.from(json['statusBarStyle'])
            : null,
        isError: json['isError'] ?? false,
        isGenerating: json['isGenerating'] ?? false,
        isHidden: json['isHidden'] ?? false,
        revision: json['revision'] ?? 1,
        promptTokens: json['promptTokens'],
        completionTokens: json['completionTokens'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
      );
}

/// 对话消息变更类型
enum ConversationMessageChangeKind {
  added,
  updated,
  deleted,
  replaced,
}

/// 对话消息操作
enum ConversationMessageOperation {
  send,
  regenerate,
  edit,
  delete,
  copy,
  translate,
  continueMsg,
  inspire,
}

/// 对话变异操作状态
enum ConversationMutationAttemptStatus {
  pending,
  success,
  failed,
}

/// 消息投影协调失败原因
enum MessageProjectionReconciliationFailure {
  mismatch,
  outOfOrder,
  duplicate,
}

/// 消息时间线成员关系
class ConversationMessageTimelineMembership {
  final String messageId;
  final String conversationId;
  final DateTime timestamp;
  final bool isPinned;
  final int order;

  ConversationMessageTimelineMembership({
    required this.messageId,
    required this.conversationId,
    required this.timestamp,
    this.isPinned = false,
    this.order = 0,
  });
}

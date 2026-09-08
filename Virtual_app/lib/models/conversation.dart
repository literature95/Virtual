import 'chat_message.dart';

/// 对话状态
enum ConversationState {
  active,
  archived,
  deleted,
  generating,
  error,
}

/// 对话侧边栏预览样式
enum ConversationSidebarPreviewAspect {
  lastMessage,
  character,
  timestamp,
}

/// 群聊回复模式
/// 证据：MCP 文档会话更新字段 + pp.txt [pp+0x3980] dbResponseMode
enum GroupChatResponseMode {
  natural, // 自然轮流
  manual, // 手动选择
  everyone, // 所有人回复
  scenario, // 剧情/场景模式
}

/// 群聊场景模式
enum GroupChatScenarioMode {
  shared, // 共享场景
  individual, // 独立场景
}

/// 对话模型
///
/// 对应原应用 Conversation 实体（ObjectBox）。
/// 逆向证据：pp.txt Eec 对象 [pp+0x3930] ~ [pp+0x3ab0] 范围内的属性定义。
/// 已确认字段：temperature, topP, topK, presencePenalty, frequencyPenalty,
/// maxCompletionTokens, stream, stop, maxHistory, disableTopP, disableTopK,
/// disableTemperature, title, mutedCharacterIds, allowSelfResponses,
/// overrideEndpointId, overrideScenario, personaId, overrideChatThemeId,
/// overridePresetId, overrideImageEndpointId, messageRevision, characters (ToMany)。
class Conversation {
  final String id;
  final String title;
  final String characterId;
  final List<String> characterIds; // 群聊支持多角色
  final String? modelId;
  final String? endpointId;

  // === 置顶/归档 ===
  final bool isPinned;
  final bool isArchived;
  final ConversationState state;

  // === 生成参数 ===
  /// 最大生成长度
  /// 证据：pp.txt [pp+0x3ad8] String: "maxCompletionTokens"
  final int? maxCompletionTokens;

  /// 温度
  /// 证据：pp.txt [pp+0x3ae8] String: "temperature"
  final double temperature;

  /// Top-P
  /// 证据：pp.txt [pp+0x3b18] String: "topP"
  final double topP;

  /// 是否禁用 Top-P
  /// 证据：pp.txt [pp+0x3b88] String: "disableTopP"
  final bool disableTopP;

  /// Top-K
  /// 证据：pp.txt [pp+0x3b28] String: "topK"
  final int? topK;

  /// 是否禁用 Top-K
  /// 证据：pp.txt [pp+0x3b68] String: "disableTopK"
  final bool disableTopK;

  /// 是否禁用 temperature
  /// 证据：pp.txt [pp+0x3b78] String: "disableTemperature"
  final bool disableTemperature;

  /// 存在惩罚
  /// 证据：pp.txt [pp+0x3af8] String: "presencePenalty"
  final double presencePenalty;

  /// 频率惩罚
  /// 证据：pp.txt [pp+0x3b08] String: "frequencyPenalty"
  final double frequencyPenalty;

  /// 停止序列
  /// 证据：pp.txt [pp+0x3b48] String: "stop"
  final List<String> stopSequences;

  /// 是否流式
  /// 证据：pp.txt [pp+0x3b38] String: "stream"
  final bool enableStream;

  /// 最大历史消息数
  /// 证据：pp.txt [pp+0x3b58] String: "maxHistory"
  final int? maxHistory;

  // === 覆盖设置 ===
  /// 覆盖场景（对话级场景覆盖角色场景）
  /// 证据：pp.txt [pp+0x3990] String: "overrideScenario"
  final String? overrideScenario;

  /// 覆盖端点 ID
  /// 证据：pp.txt [pp+0x39f8] String: "overrideEndpointId"
  final String? overrideEndpointId;

  /// 覆盖预设 ID
  /// 证据：pp.txt [pp+0x3a48] String: "overridePresetId"
  final String? overridePresetId;

  /// 覆盖主题 ID
  /// 证据：pp.txt [pp+0x3a20] String: "overrideChatThemeId"
  final String? overrideChatThemeId;

  /// 覆盖图片生成端点 ID
  /// 证据：pp.txt [pp+0x3a78] String: "overrideImageEndpointId"
  final String? overrideImageEndpointId;

  /// 覆盖 Lorebook ID 列表
  /// 证据：pp.txt [pp+0x3ab0] String: "overrideLorebooks"
  final List<String> overrideLorebookIds;

  // === 群聊设置 ===
  /// 群聊回复模式
  /// 证据：pp.txt [pp+0x3980] String: "dbResponseMode"
  final GroupChatResponseMode responseMode;

  /// 静音的角色 ID 列表
  /// 证据：pp.txt [pp+0x39d0] String: "mutedCharacterIds"
  final List<String> mutedCharacterIds;

  /// 允许自我回复
  /// 证据：pp.txt [pp+0x3970] String: "allowSelfResponses"
  final bool allowSelfResponses;

  // === 引用 ===
  /// Persona ID
  /// 证据：pp.txt [pp+0x39b0] String: "personaId"
  final String? personaId;

  /// 消息修订号（单调递增，用于增量同步/投影失效）
  /// 证据：pp.txt [pp+0x3a88] String: "messageRevision"
  final int messageRevision;

  // === 其他设置（保留嵌套结构以便扩展） ===
  final ChatSettings settings;

  // === 时间与元数据 ===
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final bool isGroupChat;
  final GroupChatSettings? groupChatSettings;

  Conversation({
    required this.id,
    required this.title,
    required this.characterId,
    this.characterIds = const [],
    this.modelId,
    this.endpointId,
    this.isPinned = false,
    this.isArchived = false,
    this.state = ConversationState.active,
    this.maxCompletionTokens,
    this.temperature = 0.7,
    this.topP = 1.0,
    this.disableTopP = false,
    this.topK,
    this.disableTopK = false,
    this.disableTemperature = false,
    this.presencePenalty = 0.0,
    this.frequencyPenalty = 0.0,
    this.stopSequences = const [],
    this.enableStream = true,
    this.maxHistory,
    this.overrideScenario,
    this.overrideEndpointId,
    this.overridePresetId,
    this.overrideChatThemeId,
    this.overrideImageEndpointId,
    this.overrideLorebookIds = const [],
    this.responseMode = GroupChatResponseMode.natural,
    this.mutedCharacterIds = const [],
    this.allowSelfResponses = false,
    this.personaId,
    this.messageRevision = 0,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.isGroupChat = false,
    this.groupChatSettings,
  });

  Conversation copyWith({
    String? id,
    String? title,
    String? characterId,
    List<String>? characterIds,
    String? modelId,
    String? endpointId,
    bool? isPinned,
    bool? isArchived,
    ConversationState? state,
    int? maxCompletionTokens,
    double? temperature,
    double? topP,
    bool? disableTopP,
    int? topK,
    bool? disableTopK,
    bool? disableTemperature,
    double? presencePenalty,
    double? frequencyPenalty,
    List<String>? stopSequences,
    bool? enableStream,
    int? maxHistory,
    String? overrideScenario,
    String? overrideEndpointId,
    String? overridePresetId,
    String? overrideChatThemeId,
    String? overrideImageEndpointId,
    List<String>? overrideLorebookIds,
    GroupChatResponseMode? responseMode,
    List<String>? mutedCharacterIds,
    bool? allowSelfResponses,
    String? personaId,
    int? messageRevision,
    ChatSettings? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    int? unreadCount,
    bool? isGroupChat,
    GroupChatSettings? groupChatSettings,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      characterId: characterId ?? this.characterId,
      characterIds: characterIds ?? this.characterIds,
      modelId: modelId ?? this.modelId,
      endpointId: endpointId ?? this.endpointId,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      state: state ?? this.state,
      maxCompletionTokens: maxCompletionTokens ?? this.maxCompletionTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      disableTopP: disableTopP ?? this.disableTopP,
      topK: topK ?? this.topK,
      disableTopK: disableTopK ?? this.disableTopK,
      disableTemperature: disableTemperature ?? this.disableTemperature,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      stopSequences: stopSequences ?? this.stopSequences,
      enableStream: enableStream ?? this.enableStream,
      maxHistory: maxHistory ?? this.maxHistory,
      overrideScenario: overrideScenario ?? this.overrideScenario,
      overrideEndpointId: overrideEndpointId ?? this.overrideEndpointId,
      overridePresetId: overridePresetId ?? this.overridePresetId,
      overrideChatThemeId: overrideChatThemeId ?? this.overrideChatThemeId,
      overrideImageEndpointId:
          overrideImageEndpointId ?? this.overrideImageEndpointId,
      overrideLorebookIds: overrideLorebookIds ?? this.overrideLorebookIds,
      responseMode: responseMode ?? this.responseMode,
      mutedCharacterIds: mutedCharacterIds ?? this.mutedCharacterIds,
      allowSelfResponses: allowSelfResponses ?? this.allowSelfResponses,
      personaId: personaId ?? this.personaId,
      messageRevision: messageRevision ?? this.messageRevision,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroupChat: isGroupChat ?? this.isGroupChat,
      groupChatSettings: groupChatSettings ?? this.groupChatSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'characterId': characterId,
        'characterIds': characterIds,
        'modelId': modelId,
        'endpointId': endpointId,
        'isPinned': isPinned,
        'isArchived': isArchived,
        'state': state.name,
        'maxCompletionTokens': maxCompletionTokens,
        'temperature': temperature,
        'topP': topP,
        'disableTopP': disableTopP,
        'topK': topK,
        'disableTopK': disableTopK,
        'disableTemperature': disableTemperature,
        'presencePenalty': presencePenalty,
        'frequencyPenalty': frequencyPenalty,
        'stopSequences': stopSequences,
        'enableStream': enableStream,
        'maxHistory': maxHistory,
        'overrideScenario': overrideScenario,
        'overrideEndpointId': overrideEndpointId,
        'overridePresetId': overridePresetId,
        'overrideChatThemeId': overrideChatThemeId,
        'overrideImageEndpointId': overrideImageEndpointId,
        'overrideLorebookIds': overrideLorebookIds,
        'responseMode': responseMode.name,
        'mutedCharacterIds': mutedCharacterIds,
        'allowSelfResponses': allowSelfResponses,
        'personaId': personaId,
        'messageRevision': messageRevision,
        'settings': settings.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastMessageAt': lastMessageAt?.toIso8601String(),
        'lastMessagePreview': lastMessagePreview,
        'unreadCount': unreadCount,
        'isGroupChat': isGroupChat,
        'groupChatSettings': groupChatSettings?.toJson(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        title: json['title'] ?? '',
        characterId: json['characterId'] ?? '',
        characterIds: List<String>.from(json['characterIds'] ?? []),
        modelId: json['modelId'],
        endpointId: json['endpointId'],
        isPinned: json['isPinned'] ?? false,
        isArchived: json['isArchived'] ?? false,
        state: ConversationState.values.firstWhere(
          (e) => e.name == json['state'],
          orElse: () => ConversationState.active,
        ),
        maxCompletionTokens: json['maxCompletionTokens'],
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
        disableTopP: json['disableTopP'] ?? false,
        topK: json['topK'],
        disableTopK: json['disableTopK'] ?? false,
        disableTemperature: json['disableTemperature'] ?? false,
        presencePenalty:
            (json['presencePenalty'] as num?)?.toDouble() ?? 0.0,
        frequencyPenalty:
            (json['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
        stopSequences: List<String>.from(json['stopSequences'] ?? []),
        enableStream: json['enableStream'] ?? true,
        maxHistory: json['maxHistory'],
        overrideScenario: json['overrideScenario'],
        overrideEndpointId: json['overrideEndpointId'],
        overridePresetId: json['overridePresetId'],
        overrideChatThemeId: json['overrideChatThemeId'],
        overrideImageEndpointId: json['overrideImageEndpointId'],
        overrideLorebookIds:
            List<String>.from(json['overrideLorebookIds'] ?? []),
        responseMode: GroupChatResponseMode.values.firstWhere(
          (e) => e.name == json['responseMode'],
          orElse: () => GroupChatResponseMode.natural,
        ),
        mutedCharacterIds:
            List<String>.from(json['mutedCharacterIds'] ?? []),
        allowSelfResponses: json['allowSelfResponses'] ?? false,
        personaId: json['personaId'],
        messageRevision: json['messageRevision'] ?? 0,
        settings: json['settings'] != null
            ? ChatSettings.fromJson(json['settings'])
            : ChatSettings(),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.parse(json['lastMessageAt'])
            : null,
        lastMessagePreview: json['lastMessagePreview'],
        unreadCount: json['unreadCount'] ?? 0,
        isGroupChat: json['isGroupChat'] ?? false,
        groupChatSettings: json['groupChatSettings'] != null
            ? GroupChatSettings.fromJson(json['groupChatSettings'])
            : null,
      );
}

/// 对话设置
///
/// 保留 ChatSettings 嵌套结构用于对话级的可配置项。
/// 注意：部分参数已提升到 Conversation 顶层（与原应用 ObjectBox 模型对齐），
/// ChatSettings 保留作为可配置项的便捷访问层。
class ChatSettings {
  final double temperature;
  final double topP;
  final int? maxTokens;
  final double frequencyPenalty;
  final double presencePenalty;
  final List<String> stopSequences;
  final bool showReasoning;
  final bool enableStream;
  final bool enableToolCalling;
  final bool enableTranslation;
  final String? systemPrompt;
  final String? jailbreakPrompt;
  final String? personaId;
  final String? lorebookId;
  final String? presetId;
  final List<String> enabledRegexIds;
  final List<String> enabledPluginIds;

  /// 推理相关设置
  final bool enableReasoning;
  final String? reasoningEffort; // low / medium / high

  ChatSettings({
    this.temperature = 0.7,
    this.topP = 1.0,
    this.maxTokens,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.stopSequences = const [],
    this.showReasoning = true,
    this.enableStream = true,
    this.enableToolCalling = true,
    this.enableTranslation = false,
    this.systemPrompt,
    this.jailbreakPrompt,
    this.personaId,
    this.lorebookId,
    this.presetId,
    this.enabledRegexIds = const [],
    this.enabledPluginIds = const [],
    this.enableReasoning = true,
    this.reasoningEffort,
  });

  ChatSettings copyWith({
    double? temperature,
    double? topP,
    int? maxTokens,
    double? frequencyPenalty,
    double? presencePenalty,
    List<String>? stopSequences,
    bool? showReasoning,
    bool? enableStream,
    bool? enableToolCalling,
    bool? enableTranslation,
    String? systemPrompt,
    String? jailbreakPrompt,
    String? personaId,
    String? lorebookId,
    String? presetId,
    List<String>? enabledRegexIds,
    List<String>? enabledPluginIds,
    bool? enableReasoning,
    String? reasoningEffort,
  }) {
    return ChatSettings(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      stopSequences: stopSequences ?? this.stopSequences,
      showReasoning: showReasoning ?? this.showReasoning,
      enableStream: enableStream ?? this.enableStream,
      enableToolCalling: enableToolCalling ?? this.enableToolCalling,
      enableTranslation: enableTranslation ?? this.enableTranslation,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      jailbreakPrompt: jailbreakPrompt ?? this.jailbreakPrompt,
      personaId: personaId ?? this.personaId,
      lorebookId: lorebookId ?? this.lorebookId,
      presetId: presetId ?? this.presetId,
      enabledRegexIds: enabledRegexIds ?? this.enabledRegexIds,
      enabledPluginIds: enabledPluginIds ?? this.enabledPluginIds,
      enableReasoning: enableReasoning ?? this.enableReasoning,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
        'frequencyPenalty': frequencyPenalty,
        'presencePenalty': presencePenalty,
        'stopSequences': stopSequences,
        'showReasoning': showReasoning,
        'enableStream': enableStream,
        'enableToolCalling': enableToolCalling,
        'enableTranslation': enableTranslation,
        'systemPrompt': systemPrompt,
        'jailbreakPrompt': jailbreakPrompt,
        'personaId': personaId,
        'lorebookId': lorebookId,
        'presetId': presetId,
        'enabledRegexIds': enabledRegexIds,
        'enabledPluginIds': enabledPluginIds,
        'enableReasoning': enableReasoning,
        'reasoningEffort': reasoningEffort,
      };

  factory ChatSettings.fromJson(Map<String, dynamic> json) => ChatSettings(
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
        maxTokens: json['maxTokens'],
        frequencyPenalty:
            (json['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
        presencePenalty: (json['presencePenalty'] as num?)?.toDouble() ?? 0.0,
        stopSequences: List<String>.from(json['stopSequences'] ?? []),
        showReasoning: json['showReasoning'] ?? true,
        enableStream: json['enableStream'] ?? true,
        enableToolCalling: json['enableToolCalling'] ?? true,
        enableTranslation: json['enableTranslation'] ?? false,
        systemPrompt: json['systemPrompt'],
        jailbreakPrompt: json['jailbreakPrompt'],
        personaId: json['personaId'],
        lorebookId: json['lorebookId'],
        presetId: json['presetId'],
        enabledRegexIds: List<String>.from(json['enabledRegexIds'] ?? []),
        enabledPluginIds: List<String>.from(json['enabledPluginIds'] ?? []),
        enableReasoning: json['enableReasoning'] ?? true,
        reasoningEffort: json['reasoningEffort'],
      );
}

/// 群聊设置
class GroupChatSettings {
  final GroupChatResponseMode responseMode;
  final List<String> activeCharacterIds;
  final bool isMuted;
  final GroupChatScenarioMode scenarioMode;
  final String? scenario;
  final int maxActiveCharacters;
  final GroupAvatarStyle avatarStyle;

  GroupChatSettings({
    this.responseMode = GroupChatResponseMode.natural,
    this.activeCharacterIds = const [],
    this.isMuted = false,
    this.scenarioMode = GroupChatScenarioMode.shared,
    this.scenario,
    this.maxActiveCharacters = 5,
    this.avatarStyle = GroupAvatarStyle.stacked,
  });

  Map<String, dynamic> toJson() => {
        'responseMode': responseMode.name,
        'activeCharacterIds': activeCharacterIds,
        'isMuted': isMuted,
        'scenarioMode': scenarioMode.name,
        'scenario': scenario,
        'maxActiveCharacters': maxActiveCharacters,
        'avatarStyle': avatarStyle.name,
      };

  factory GroupChatSettings.fromJson(Map<String, dynamic> json) =>
      GroupChatSettings(
        responseMode: GroupChatResponseMode.values.firstWhere(
          (e) => e.name == json['responseMode'],
          orElse: () => GroupChatResponseMode.natural,
        ),
        activeCharacterIds:
            List<String>.from(json['activeCharacterIds'] ?? []),
        isMuted: json['isMuted'] ?? false,
        scenarioMode: GroupChatScenarioMode.values.firstWhere(
          (e) => e.name == json['scenarioMode'],
          orElse: () => GroupChatScenarioMode.shared,
        ),
        scenario: json['scenario'],
        maxActiveCharacters: json['maxActiveCharacters'] ?? 5,
        avatarStyle: GroupAvatarStyle.values.firstWhere(
          (e) => e.name == json['avatarStyle'],
          orElse: () => GroupAvatarStyle.stacked,
        ),
      );
}

/// 聊天历史记录
class ChatHistory {
  final List<Conversation> conversations;
  final int totalMessages;
  final DateTime lastActive;

  ChatHistory({
    required this.conversations,
    required this.totalMessages,
    required this.lastActive,
  });
}

/// 聊天开始配置
class ChatStart {
  final String characterId;
  final String? endpointId;
  final String? modelId;
  final String? greeting;
  final ChatSettings? settings;

  ChatStart({
    required this.characterId,
    this.endpointId,
    this.modelId,
    this.greeting,
    this.settings,
  });
}


/// 端点类型
enum EndpointKind {
  llm, // 大语言模型
  tts, // 语音合成
  asr, // 语音识别
  image, // 图片生成
  webSearch, // 网页搜索
}

/// 端点接入方式
/// - [access]：接入——走云端 API（OpenAI/Anthropic/Gemini 兼容服务）
/// - [deploy]：部署——走本机本地模型（nobodywho，仅移动端/桌面端，web 不支持）
enum EndpointMode {
  access, // 接入（云端 API）
  deploy; // 部署（本地模型）

  String get displayName => switch (this) {
        EndpointMode.access => '接入',
        EndpointMode.deploy => '部署',
      };

  String get description => switch (this) {
        EndpointMode.access => '云端 API，填 Base URL / API Key',
        EndpointMode.deploy => '本机运行本地模型（GGUF），无需联网',
      };

  static EndpointMode fromJson(String? value) =>
      EndpointMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => EndpointMode.access, // 旧数据无该字段时按接入处理
      );
}

/// 部署型端点的本地提示词组装模式。
///
/// - [concise]：精简——压缩角色卡 + 最近 4 轮 + 本轮指令，适合 ≤2B 小模型；
/// - [full]：完整——完整角色卡 + 世界书 + 正常历史裁剪（复用云端
///   `PromptService` 两遍拼装），适合 ≥3B、上下文容量足够的模型。
///
/// 默认 [concise]：小模型塞满上下文会「答非所问」，精简模式是历史验证过的
/// 安全默认；大模型由用户在端点里显式切换。
enum LocalPromptMode {
  concise('精简', '压缩角色卡 + 最近 4 轮，适合 ≤2B 小模型'),
  full('完整', '完整角色卡 + 世界书 + 正常历史裁剪，适合 ≥3B 大模型');

  const LocalPromptMode(this.displayName, this.description);

  final String displayName;
  final String description;

  static LocalPromptMode fromJson(String? value) =>
      LocalPromptMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => LocalPromptMode.concise, // 旧数据无该字段按精简处理
      );
}

/// 端点参数值类型
enum EndpointParamValueType {
  string,
  number,
  boolean,
  secret,
  select,
}

/// 端点参数
class EndpointParam {
  final String key;
  final String label;
  final EndpointParamValueType type;
  final String? defaultValue;
  final bool required;
  final String? hint;
  final List<String>? options;

  EndpointParam({
    required this.key,
    required this.label,
    this.type = EndpointParamValueType.string,
    this.defaultValue,
    this.required = false,
    this.hint,
    this.options,
  });
}

/// LLM 端点配置
class LlmEndpoint {
  final String id;
  final String name;
  final String platform; // openai, anthropic, gemini, deepseek 等
  final String baseUrl;
  final String apiKey;
  final List<LlmModelDescriptor> models;
  final String defaultModelId; // 接口的默认模型（须在 models 中）
  final bool isDefault;
  final bool enabled;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> customParams;

  // ===== 部署（本地模型）相关：仅 mode == EndpointMode.deploy 时生效 =====
  /// 接入方式（云端 API / 本地模型）。旧 JSON 缺省时按 [EndpointMode.access]
  final EndpointMode mode;
  /// 本地 GGUF 模型文件绝对路径（由用户在端点里导入或手填）
  final String localModelPath;
  /// 本地提示词组装模式：精简 / 完整（仅部署型生效，默认精简）
  final LocalPromptMode localPromptMode;
  /// 本地推理上下文长度（token）
  final int contextSize;
  /// 是否把模型层 offload 到 GPU（设备不支持时引擎自动回退 CPU）
  final bool useGpu;
  /// 推理线程数，0 = 引擎按 CPU 核数自动
  final int threadCount;
  /// 采样温度（0~2，越低越确定）
  final double temperature;
  /// 核采样 top-p（0~1）
  final double topP;
  /// 单次生成最大 token 数
  final int maxTokens;

  /// 重复惩罚（1.0 = 不惩罚，>1.0 抑制复读；过高会发僵）
  final double repetitionPenalty;

  /// 新端点默认上下文长度：4096（与本地模型功能引入前保持一致）。
  /// 已有端点读回自身存储值，不强制改。
  static const int kDefaultContextSize = 4096;
  static const int kDefaultMaxTokens = 1024;
  static const double kDefaultTemperature = 0.7;
  static const double kDefaultTopP = 0.9;
  static const double kDefaultRepetitionPenalty = 1.1;

  LlmEndpoint({
    required this.id,
    required this.name,
    required this.platform,
    required this.baseUrl,
    required this.apiKey,
    this.models = const [],
    this.defaultModelId = '',
    this.isDefault = false,
    this.enabled = true,
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
    this.customParams = const {},
    this.mode = EndpointMode.access,
    this.localModelPath = '',
    this.localPromptMode = LocalPromptMode.concise,
    int contextSize = kDefaultContextSize,
    this.useGpu = true,
    int threadCount = 0,
    double temperature = kDefaultTemperature,
    double topP = kDefaultTopP,
    int maxTokens = kDefaultMaxTokens,
    double repetitionPenalty = kDefaultRepetitionPenalty,
  })  : contextSize = contextSize.clamp(512, 131072).toInt(),
        threadCount = threadCount.clamp(0, 64).toInt(),
        temperature = temperature.clamp(0.0, 2.0).toDouble(),
        topP = topP.clamp(0.0, 1.0).toDouble(),
        maxTokens = maxTokens.clamp(1, 32768).toInt(),
        repetitionPenalty =
            repetitionPenalty.clamp(1.0, 1.3).toDouble();

  /// 部署型端点是否走「完整」提示词（云端同源组装）。
  bool get usesFullLocalPrompt =>
      mode == EndpointMode.deploy && localPromptMode == LocalPromptMode.full;

  LlmEndpoint copyWith({
    String? id,
    String? name,
    String? platform,
    String? baseUrl,
    String? apiKey,
    List<LlmModelDescriptor>? models,
    String? defaultModelId,
    bool? isDefault,
    bool? enabled,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? customParams,
    EndpointMode? mode,
    String? localModelPath,
    LocalPromptMode? localPromptMode,
    int? contextSize,
    bool? useGpu,
    int? threadCount,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repetitionPenalty,
  }) {
    return LlmEndpoint(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      models: models ?? this.models,
      defaultModelId: defaultModelId ?? this.defaultModelId,
      isDefault: isDefault ?? this.isDefault,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      customParams: customParams ?? this.customParams,
      mode: mode ?? this.mode,
      localModelPath: localModelPath ?? this.localModelPath,
      localPromptMode: localPromptMode ?? this.localPromptMode,
      contextSize: contextSize ?? this.contextSize,
      useGpu: useGpu ?? this.useGpu,
      threadCount: threadCount ?? this.threadCount,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'models': models.map((m) => m.toJson()).toList(),
        'defaultModelId': defaultModelId,
        'isDefault': isDefault,
        'enabled': enabled,
        'priority': priority,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'customParams': customParams,
        'mode': mode.name,
        'localModelPath': localModelPath,
        'localPromptMode': localPromptMode.name,
        'contextSize': contextSize,
        'useGpu': useGpu,
        'threadCount': threadCount,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
        'repetitionPenalty': repetitionPenalty,
      };

  factory LlmEndpoint.fromJson(Map<String, dynamic> json) => LlmEndpoint(
        id: json['id'],
        name: json['name'] ?? '',
        platform: json['platform'] ?? 'openai',
        baseUrl: json['baseUrl'] ?? '',
        apiKey: json['apiKey'] ?? '',
        models: (json['models'] as List?)
                ?.map((m) => LlmModelDescriptor.fromJson(m))
                .toList() ??
            [],
        defaultModelId: json['defaultModelId'] ?? '',
        isDefault: json['isDefault'] ?? false,
        enabled: json['enabled'] ?? true,
        priority: json['priority'] ?? 0,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        customParams: Map<String, String>.from(json['customParams'] ?? {}),
        mode: EndpointMode.fromJson(json['mode'] as String?),
        localModelPath: json['localModelPath'] ?? '',
        localPromptMode: LocalPromptMode.fromJson(json['localPromptMode'] as String?),
        contextSize: (json['contextSize'] as num?)?.toInt() ?? kDefaultContextSize,
        useGpu: json['useGpu'] as bool? ?? true,
        threadCount: (json['threadCount'] as num?)?.toInt() ?? 0,
        temperature:
            (json['temperature'] as num?)?.toDouble() ?? kDefaultTemperature,
        topP: (json['topP'] as num?)?.toDouble() ?? kDefaultTopP,
        maxTokens: (json['maxTokens'] as num?)?.toInt() ?? kDefaultMaxTokens,
        // 旧 JSON 缺该字段按 1.1（引擎侧支持惩罚，默认轻微抑制复读）
        repetitionPenalty: (json['repetitionPenalty'] as num?)?.toDouble() ??
            kDefaultRepetitionPenalty,
      );

  /// 生效模型：默认模型仍存在时用它，否则回落列表第一个
  LlmModelDescriptor? get effectiveModel {
    if (models.isEmpty) return null;
    for (final m in models) {
      if (m.id == defaultModelId) return m;
    }
    return models.first;
  }
}

/// LLM 模型描述
class LlmModelDescriptor {
  final String id;
  final String name;
  final String ownedBy;
  final int contextLength;
  final List<String> capabilities; // text, image, code, function, reasoning, tts, asr, structure, cache
  final ModelPricing? pricing;
  final ModelVendorFamily vendorFamily;
  final bool deprecated;
  final bool visionSupported;
  final bool functionCallingSupported;
  final bool reasoningSupported;

  LlmModelDescriptor({
    required this.id,
    required this.name,
    this.ownedBy = '',
    this.contextLength = 4096,
    this.capabilities = const ['text'],
    this.pricing,
    this.vendorFamily = ModelVendorFamily.other,
    this.deprecated = false,
    this.visionSupported = false,
    this.functionCallingSupported = false,
    this.reasoningSupported = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownedBy': ownedBy,
        'contextLength': contextLength,
        'capabilities': capabilities,
        'pricing': pricing?.toJson(),
        'vendorFamily': vendorFamily.name,
        'deprecated': deprecated,
        'visionSupported': visionSupported,
        'functionCallingSupported': functionCallingSupported,
        'reasoningSupported': reasoningSupported,
      };

  factory LlmModelDescriptor.fromJson(Map<String, dynamic> json) =>
      LlmModelDescriptor(
        id: json['id'] ?? json['model'] ?? '',
        name: json['name'] ?? json['id'] ?? '',
        ownedBy: json['ownedBy'] ?? '',
        contextLength: json['contextLength'] ?? json['context_length'] ?? 4096,
        capabilities: List<String>.from(json['capabilities'] ?? ['text']),
        pricing: json['pricing'] != null
            ? ModelPricing.fromJson(json['pricing'])
            : null,
        vendorFamily: ModelVendorFamily.values.firstWhere(
          (e) => e.name == json['vendorFamily'],
          orElse: () => ModelVendorFamily.other,
        ),
        deprecated: json['deprecated'] ?? false,
        visionSupported: json['visionSupported'] ?? false,
        functionCallingSupported: json['functionCallingSupported'] ?? false,
        reasoningSupported: json['reasoningSupported'] ?? false,
      );
}

/// 模型定价
class ModelPricing {
  final double promptPerToken;
  final double completionPerToken;
  final String currency;

  ModelPricing({
    this.promptPerToken = 0,
    this.completionPerToken = 0,
    this.currency = 'USD',
  });

  Map<String, dynamic> toJson() => {
        'promptPerToken': promptPerToken,
        'completionPerToken': completionPerToken,
        'currency': currency,
      };

  factory ModelPricing.fromJson(Map<String, dynamic> json) => ModelPricing(
        promptPerToken:
            (json['promptPerToken'] as num?)?.toDouble() ??
            (json['prompt'] as num?)?.toDouble() ??
            0,
        completionPerToken:
            (json['completionPerToken'] as num?)?.toDouble() ??
            (json['completion'] as num?)?.toDouble() ??
            0,
        currency: json['currency'] ?? 'USD',
      );
}

/// 模型厂商系列
enum ModelVendorFamily {
  openai,
  anthropic,
  google,
  deepseek,
  xai,
  meta,
  mistral,
  qwen,
  yi,
  other,
}

/// TTS 端点
class TtsEndpoint {
  final String id;
  final String name;
  final TtsPlatform platform;
  final String baseUrl;
  final String apiKey;
  final List<TtsVoice> voices;
  final bool isDefault;
  final bool enabled;

  TtsEndpoint({
    required this.id,
    required this.name,
    required this.platform,
    this.baseUrl = '',
    this.apiKey = '',
    this.voices = const [],
    this.isDefault = false,
    this.enabled = true,
  });
}

/// TTS 平台
enum TtsPlatform {
  system,
  elevenlabs,
  gemini,
  minimax,
  edge,
}

/// TTS 音色
class TtsVoice {
  final String id;
  final String name;
  final String language;
  final String gender;
  final TtsVoiceRole role;

  TtsVoice({
    required this.id,
    required this.name,
    this.language = 'en',
    this.gender = 'unknown',
    this.role = TtsVoiceRole.normal,
  });
}

/// TTS 音色角色
enum TtsVoiceRole {
  normal,
  character,
  narration,
}

/// TTS 音色绑定范围
enum TtsVoicesBindingScope {
  global,
  character,
  conversation,
}

/// TTS 播放状态
enum TtsPlayStatus {
  idle,
  loading,
  playing,
  paused,
  stopped,
  error,
}

/// TTS 播放事件
enum TtsPlaybackEvent {
  start,
  pause,
  resume,
  stop,
  complete,
  error,
}

/// TTS 播放来源
enum TtsPlaybackOrigin {
  userAction,
  autoPlay,
  queue,
}

/// TTS 播放规则动作
enum TtsPlaybackRuleAction {
  play,
  skip,
  queue,
}

/// TTS 播放规则范围
enum TtsPlaybackRuleScope {
  all,
  currentConversation,
  currentCharacter,
  selected,
}

/// TTS 处理配置
class TtsPlayDisposition {
  final bool shouldPlay;
  final String? voiceId;
  final double speed;
  final double pitch;

  TtsPlayDisposition({
    this.shouldPlay = false,
    this.voiceId,
    this.speed = 1.0,
    this.pitch = 1.0,
  });
}

/// TTS 角色引用
class TtsCharacterRef {
  final String characterId;
  final String voiceId;

  TtsCharacterRef({
    required this.characterId,
    required this.voiceId,
  });
}

/// TTS Persona 引用
class TtsPersonaRef {
  final String personaId;
  final String voiceId;

  TtsPersonaRef({
    required this.personaId,
    required this.voiceId,
  });
}

/// TTS 聊天切换播放策略
enum TtsChatSwitchPlaybackPolicy {
  alwaysPlay,
  stopCurrent,
  queueAll,
}

/// 气泡 TTS 浮层对齐
enum BubbleTtsOverlayAlignment {
  top,
  bottom,
  left,
  right,
}

/// ASR 端点
class AsrEndpoint {
  final String id;
  final String name;
  final AsrPlatform platform;
  final String baseUrl;
  final String apiKey;
  final bool isDefault;
  final bool enabled;

  AsrEndpoint({
    required this.id,
    required this.name,
    required this.platform,
    this.baseUrl = '',
    this.apiKey = '',
    this.isDefault = false,
    this.enabled = true,
  });
}

/// ASR 平台
enum AsrPlatform {
  system,
  whisper,
  gemini,
  deepgram,
}

/// ASR 完成原因
enum AsrCompletionReason {
  endOfSpeech,
  stopped,
  timeout,
  error,
}

/// ASR 结束策略
enum AsrEndStrategy {
  manual,
  auto,
  voiceActivity,
}

/// ASR 端点决策
enum AsrEndpointerDecision {
  listening,
  endOfSpeech,
  noSpeech,
  timeout,
}

/// ASR 事件类型
enum AsrEventType {
  listening,
  partialResult,
  finalResult,
  error,
  done,
}

/// ASR 监听模式
enum AsrListenMode {
  pushToTalk,
  continuous,
  voiceActivity,
}

/// ASR 调试模式
enum AsrDebugMode {
  off,
  basic,
  verbose,
}

/// 图片生成端点
class ImageEndpoint {
  final String id;
  final String name;
  final String platform;
  final String baseUrl;
  final String apiKey;
  final List<ImggenModel> models;
  final bool isDefault;
  final bool enabled;

  ImageEndpoint({
    required this.id,
    required this.name,
    required this.platform,
    this.baseUrl = '',
    this.apiKey = '',
    this.models = const [],
    this.isDefault = false,
    this.enabled = true,
  });
}

/// 图片生成模型
class ImggenModel {
  final String id;
  final String name;
  final List<String> sizes;
  final int maxSteps;
  final double pricePerImage;

  ImggenModel({
    required this.id,
    required this.name,
    this.sizes = const ['1024x1024'],
    this.maxSteps = 50,
    this.pricePerImage = 0,
  });
}

/// 网页搜索端点
class WebSearchEndpoint {
  final String id;
  final String name;
  final String platform; // tavily, google, brage
  final String apiKey;
  final bool isDefault;
  final bool enabled;

  WebSearchEndpoint({
    required this.id,
    required this.name,
    required this.platform,
    this.apiKey = '',
    this.isDefault = false,
    this.enabled = true,
  });
}

/// 可用端点
class AvailableEndpoint {
  final String id;
  final EndpointKind kind;
  final String name;
  final bool available;
  final String? reason;

  AvailableEndpoint({
    required this.id,
    required this.kind,
    required this.name,
    required this.available,
    this.reason,
  });
}

/// 合作伙伴端点类型
enum PartnerEndpointKind {
  official,
  thirdParty,
  community,
}

/// 合作伙伴品牌
class PartnerBrand {
  final String id;
  final String name;
  final String? logoPath;
  final String website;
  final String description;

  PartnerBrand({
    required this.id,
    required this.name,
    this.logoPath,
    this.website = '',
    this.description = '',
  });
}

/// 合作伙伴渠道类型
enum PartnerChannelKind {
  direct,
  reseller,
  affiliate,
}

/// 合作伙伴定价
class PartnerPricing {
  final double discount;
  final String? currency;
  final String? note;

  PartnerPricing({
    this.discount = 0,
    this.currency,
    this.note,
  });
}

/// 合作伙伴字段
enum PartnerField {
  apiKey,
  baseUrl,
  model,
  custom,
}


/// 端点类型
enum EndpointKind {
  llm, // 大语言模型
  tts, // 语音合成
  asr, // 语音识别
  image, // 图片生成
  webSearch, // 网页搜索
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
  final bool isDefault;
  final bool enabled;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> customParams;

  LlmEndpoint({
    required this.id,
    required this.name,
    required this.platform,
    required this.baseUrl,
    required this.apiKey,
    this.models = const [],
    this.isDefault = false,
    this.enabled = true,
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
    this.customParams = const {},
  });

  LlmEndpoint copyWith({
    String? id,
    String? name,
    String? platform,
    String? baseUrl,
    String? apiKey,
    List<LlmModelDescriptor>? models,
    bool? isDefault,
    bool? enabled,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? customParams,
  }) {
    return LlmEndpoint(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      models: models ?? this.models,
      isDefault: isDefault ?? this.isDefault,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      customParams: customParams ?? this.customParams,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'models': models.map((m) => m.toJson()).toList(),
        'isDefault': isDefault,
        'enabled': enabled,
        'priority': priority,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'customParams': customParams,
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
        isDefault: json['isDefault'] ?? false,
        enabled: json['enabled'] ?? true,
        priority: json['priority'] ?? 0,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        customParams: Map<String, String>.from(json['customParams'] ?? {}),
      );
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

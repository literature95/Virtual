class PlatformPreset {
  final String id;
  final String name;
  final String platform;
  final String baseUrl;
  final String? anthropicVersion;
  final Map<String, String> defaultHeaders;
  final Map<String, String> defaultParams;

  const PlatformPreset({
    required this.id,
    required this.name,
    required this.platform,
    required this.baseUrl,
    this.anthropicVersion,
    this.defaultHeaders = const {},
    this.defaultParams = const {},
  });
}

const List<PlatformPreset> platformPresets = [
  PlatformPreset(
    id: 'openai',
    name: 'OpenAI',
    platform: 'openai',
    baseUrl: 'https://api.openai.com/v1',
  ),
  PlatformPreset(
    id: 'anthropic',
    name: 'Anthropic',
    platform: 'anthropic',
    baseUrl: 'https://api.anthropic.com/v1',
    anthropicVersion: '2023-06-01',
  ),
  PlatformPreset(
    id: 'gemini',
    name: 'Google Gemini',
    platform: 'gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
  ),
  PlatformPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    platform: 'deepseek',
    baseUrl: 'https://api.deepseek.com',
  ),
  PlatformPreset(
    id: 'grok',
    name: 'Grok (xAI)',
    platform: 'xai',
    baseUrl: 'https://api.x.ai/v1',
  ),
  PlatformPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    platform: 'openrouter',
    baseUrl: 'https://openrouter.ai/api/v1',
  ),
  PlatformPreset(
    id: 'minimax',
    name: 'MiniMax',
    platform: 'minimax',
    baseUrl: 'https://api.minimax.io/v1',
  ),
  PlatformPreset(
    id: 'qwen',
    name: 'Qwen (通义千问)',
    platform: 'qwen',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  ),
  PlatformPreset(
    id: 'moonshot',
    name: 'Moonshot (月之暗面)',
    platform: 'moonshot',
    baseUrl: 'https://api.moonshot.cn/v1',
  ),
  PlatformPreset(
    id: 'glm',
    name: 'GLM (智谱)',
    platform: 'glm',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
  ),
  PlatformPreset(
    id: 'groq',
    name: 'Groq',
    platform: 'groq',
    baseUrl: 'https://api.groq.com/openai/v1',
  ),
  PlatformPreset(
    id: 'together',
    name: 'Together AI',
    platform: 'together',
    baseUrl: 'https://api.together.xyz/v1',
  ),
  PlatformPreset(
    id: 'fireworks',
    name: 'Fireworks AI',
    platform: 'fireworks',
    baseUrl: 'https://api.fireworks.ai/inference/v1',
  ),
  PlatformPreset(
    id: 'doubao',
    name: 'Doubao (豆包)',
    platform: 'doubao',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
  ),
  PlatformPreset(
    id: 'vertex',
    name: 'Vertex AI',
    platform: 'vertex',
    baseUrl: 'https://aiplatform.googleapis.com',
  ),
];

PlatformPreset? findPlatformPreset(String platform) {
  try {
    return platformPresets.firstWhere(
      (p) => p.platform.toLowerCase() == platform.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}

List<PlatformPreset> searchPlatformPresets(String query) {
  final lowerQuery = query.toLowerCase();
  return platformPresets.where((p) {
    return p.name.toLowerCase().contains(lowerQuery) ||
        p.platform.toLowerCase().contains(lowerQuery) ||
        p.id.toLowerCase().contains(lowerQuery);
  }).toList();
}

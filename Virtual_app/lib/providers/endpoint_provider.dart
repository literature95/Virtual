import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

import '../data/app_database.dart';
import '../models/endpoint.dart';
import '../services/model_registry_service.dart';

/// 端点管理 Provider
///
/// 管理 LLM / TTS / ASR / Image / WebSearch 五类端点。
class EndpointProvider extends ChangeNotifier {
  final AppDatabase _db;
  final ModelRegistryService _modelRegistry;
  final _uuid = const Uuid();
  final Dio _dio = Dio();

  // LLM 端点
  List<LlmEndpoint> _llmEndpoints = [];
  List<LlmEndpoint> get llmEndpoints => _llmEndpoints;

  LlmEndpoint? _defaultLlmEndpoint;
  LlmEndpoint? get defaultLlmEndpoint => _defaultLlmEndpoint;

  // TTS 端点
  List<TtsEndpoint> _ttsEndpoints = [];
  List<TtsEndpoint> get ttsEndpoints => _ttsEndpoints;

  TtsEndpoint? _defaultTtsEndpoint;
  TtsEndpoint? get defaultTtsEndpoint => _defaultTtsEndpoint;

  // ASR 端点
  final List<AsrEndpoint> _asrEndpoints = [];
  List<AsrEndpoint> get asrEndpoints => _asrEndpoints;

  // Image 端点
  final List<ImageEndpoint> _imageEndpoints = [];
  List<ImageEndpoint> get imageEndpoints => _imageEndpoints;

  // WebSearch 端点
  final List<WebSearchEndpoint> _webSearchEndpoints = [];
  List<WebSearchEndpoint> get webSearchEndpoints => _webSearchEndpoints;

  // 模型缓存
  final Map<String, List<LlmModelDescriptor>> _modelCache = {};

  /// 模型注册表服务
  ModelRegistryService get modelRegistry => _modelRegistry;

  EndpointProvider(this._db, {ModelRegistryService? modelRegistry})
      : _modelRegistry = modelRegistry ?? ModelRegistryService() {
    loadAll();
  }

  void loadAll() {
    loadLlmEndpoints();
    loadTtsEndpoints();
  }

  // ========== LLM 端点 ==========

  void loadLlmEndpoints() {
    _llmEndpoints = _db.getLlmEndpoints();
    try {
      _defaultLlmEndpoint = _llmEndpoints.firstWhere((e) => e.isDefault);
    } catch (_) {
      _defaultLlmEndpoint =
          _llmEndpoints.isNotEmpty ? _llmEndpoints.first : null;
    }
    notifyListeners();
  }

  Future<void> saveLlmEndpoint(LlmEndpoint endpoint) async {
    await _db.saveEndpoint(endpoint);
    loadLlmEndpoints();
  }

  Future<void> deleteLlmEndpoint(String id) async {
    await _db.deleteEndpoint(id);
    loadLlmEndpoints();
  }

  /// 设置默认 LLM 端点
  Future<void> setDefaultLlm(String id) async {
    final currentDefault = _db.getDefaultLlmEndpoint();
    if (currentDefault != null && currentDefault.id == id) return;

    final endpoints = _db.getLlmEndpoints();
    for (final ep in endpoints) {
      if (ep.id == id) {
        await _db.saveEndpoint(ep.copyWith(isDefault: true));
      } else if (ep.isDefault) {
        await _db.saveEndpoint(ep.copyWith(isDefault: false));
      }
    }
    loadLlmEndpoints();
  }

  // ========== 模型列表 ==========

  /// 从远端获取模型列表（支持 OpenAI 兼容协议）
  Future<List<LlmModelDescriptor>> fetchModels(LlmEndpoint endpoint) async {
    final cacheKey = '${endpoint.baseUrl}_${endpoint.apiKey.hashCode}';
    if (_modelCache.containsKey(cacheKey)) {
      return _modelCache[cacheKey]!;
    }

    try {
      final response = await _dio.get(
        '${endpoint.baseUrl}/models',
        options: Options(headers: {
          'Authorization': 'Bearer ${endpoint.apiKey}',
        }),
      );

      final data = response.data;
      final List<dynamic> modelsData = data['data'] as List? ?? [];
      final models = modelsData
          .map((m) => LlmModelDescriptor(
                id: m['id']?.toString() ?? '',
                name: m['id']?.toString() ?? '',
                contextLength: m['context_window'] as int? ?? 4096,
                visionSupported: _checkVisionSupport(m['id']?.toString() ?? ''),
                functionCallingSupported:
                    _checkToolSupport(m['id']?.toString() ?? ''),
                reasoningSupported:
                    _checkReasoningSupport(m['id']?.toString() ?? ''),
              ))
          .toList();

      _modelCache[cacheKey] = models;
      return models;
    } catch (e) {
      // 优先尝试从注册表中匹配平台对应的模型，其次用内置默认列表
      final registryModels =
          await _getRegistryModelsForPlatform(endpoint.platform);
      final defaults = registryModels.isNotEmpty
          ? registryModels
          : _getDefaultModelsForPlatform(endpoint.platform);
      _modelCache[cacheKey] = defaults;
      return defaults;
    }
  }

  bool _checkVisionSupport(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('vision') ||
        lower.contains('gpt-4o') ||
        lower.contains('gpt-4-turbo') ||
        lower.contains('claude-3') ||
        lower.contains('gemini') ||
        lower.contains('qwen-vl') ||
        lower.contains('glm-4v');
  }

  bool _checkToolSupport(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('gpt-4') ||
        lower.contains('gpt-3.5-turbo') ||
        lower.contains('claude-3') ||
        lower.contains('gemini') ||
        lower.contains('qwen') ||
        lower.contains('glm-4') ||
        lower.contains('moonshot') ||
        lower.contains('deepseek');
  }

  bool _checkReasoningSupport(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('reasoning') ||
        lower.contains('r1') ||
        lower.contains('o1') ||
        lower.contains('o3') ||
        lower.contains('deepseek-reasoner') ||
        lower.contains('thinking');
  }

  /// 从模型注册表中按平台获取模型
  Future<List<LlmModelDescriptor>> _getRegistryModelsForPlatform(
      String platform) async {
    if (!_modelRegistry.isLoaded) {
      await _modelRegistry.load();
    }
    if (!_modelRegistry.isLoaded) return const [];

    final lower = platform.toLowerCase();
    String? vendorKey;

    switch (lower) {
      case 'openai':
      case 'open_ai':
        vendorKey = 'openai';
        break;
      case 'anthropic':
      case 'claude':
        vendorKey = 'claude';
        break;
      case 'gemini':
      case 'google':
        vendorKey = 'gemini';
        break;
      case 'deepseek':
        vendorKey = 'deepseek';
        break;
      case 'xai':
      case 'grok':
        vendorKey = 'grok';
        break;
      case 'doubao':
        vendorKey = 'doubao';
        break;
      case 'openrouter':
        vendorKey = 'openrouter_popular';
        break;
      case 'vertex':
        vendorKey = 'vertex';
        break;
    }

    if (vendorKey != null) {
      return _modelRegistry.getModelsByVendor(vendorKey);
    }
    return const [];
  }

  /// 根据平台获取默认模型列表
  List<LlmModelDescriptor> _getDefaultModelsForPlatform(String platform) {
    final lower = platform.toLowerCase();
    switch (lower) {
      case 'openai':
      case 'open_ai':
        return [
          LlmModelDescriptor(
            id: 'gpt-4o',
            name: 'GPT-4o',
            ownedBy: 'openai',
            contextLength: 128000,
            capabilities: ['text', 'image', 'function'],
            vendorFamily: ModelVendorFamily.openai,
            visionSupported: true,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'gpt-4o-mini',
            name: 'GPT-4o mini',
            ownedBy: 'openai',
            contextLength: 128000,
            capabilities: ['text', 'image', 'function'],
            vendorFamily: ModelVendorFamily.openai,
            visionSupported: true,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'gpt-4-turbo',
            name: 'GPT-4 Turbo',
            ownedBy: 'openai',
            contextLength: 128000,
            capabilities: ['text', 'image', 'function'],
            vendorFamily: ModelVendorFamily.openai,
            visionSupported: true,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'gpt-3.5-turbo',
            name: 'GPT-3.5 Turbo',
            ownedBy: 'openai',
            contextLength: 16384,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.openai,
            functionCallingSupported: true,
          ),
        ];
      case 'anthropic':
      case 'claude':
        return [
          LlmModelDescriptor(
            id: 'claude-3-5-sonnet-latest',
            name: 'Claude 3.5 Sonnet',
            ownedBy: 'anthropic',
            contextLength: 200000,
            capabilities: ['text', 'image', 'function'],
            vendorFamily: ModelVendorFamily.anthropic,
            visionSupported: true,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'claude-3-opus-latest',
            name: 'Claude 3 Opus',
            ownedBy: 'anthropic',
            contextLength: 200000,
            capabilities: ['text', 'image', 'function'],
            vendorFamily: ModelVendorFamily.anthropic,
            visionSupported: true,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'claude-3-haiku-latest',
            name: 'Claude 3 Haiku',
            ownedBy: 'anthropic',
            contextLength: 200000,
            capabilities: ['text', 'image', 'function'],
            vendorFamily: ModelVendorFamily.anthropic,
            visionSupported: true,
            functionCallingSupported: true,
          ),
        ];
      case 'deepseek':
        return [
          LlmModelDescriptor(
            id: 'deepseek-chat',
            name: 'DeepSeek V3',
            ownedBy: 'deepseek',
            contextLength: 64000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.deepseek,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'deepseek-reasoner',
            name: 'DeepSeek R1',
            ownedBy: 'deepseek',
            contextLength: 64000,
            capabilities: ['text', 'function', 'reasoning'],
            vendorFamily: ModelVendorFamily.deepseek,
            functionCallingSupported: true,
            reasoningSupported: true,
          ),
        ];
      case 'qwen':
      case 'tongyi':
        return [
          LlmModelDescriptor(
            id: 'qwen-plus',
            name: 'Qwen Plus',
            ownedBy: 'alibaba',
            contextLength: 128000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.qwen,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'qwen-turbo',
            name: 'Qwen Turbo',
            ownedBy: 'alibaba',
            contextLength: 128000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.qwen,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'qwen-max',
            name: 'Qwen Max',
            ownedBy: 'alibaba',
            contextLength: 32000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.qwen,
            functionCallingSupported: true,
          ),
        ];
      case 'gemini':
      case 'google':
        return [
          LlmModelDescriptor(
            id: 'gemini-1.5-pro',
            name: 'Gemini 1.5 Pro',
            ownedBy: 'google',
            contextLength: 1000000,
            capabilities: ['text', 'image', 'function'],
            vendorFamily: ModelVendorFamily.google,
            visionSupported: true,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'gemini-1.5-flash',
            name: 'Gemini 1.5 Flash',
            ownedBy: 'google',
            contextLength: 1000000,
            capabilities: ['text', 'image', 'function'],
            vendorFamily: ModelVendorFamily.google,
            visionSupported: true,
            functionCallingSupported: true,
          ),
        ];
      case 'moonshot':
      case 'kimi':
        return [
          LlmModelDescriptor(
            id: 'moonshot-v1-8k',
            name: 'Moonshot V1 8K',
            ownedBy: 'moonshot',
            contextLength: 8000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.other,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'moonshot-v1-32k',
            name: 'Moonshot V1 32K',
            ownedBy: 'moonshot',
            contextLength: 32000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.other,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'moonshot-v1-128k',
            name: 'Moonshot V1 128K',
            ownedBy: 'moonshot',
            contextLength: 128000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.other,
            functionCallingSupported: true,
          ),
        ];
      case 'glm':
      case 'zhipu':
        return [
          LlmModelDescriptor(
            id: 'glm-4-plus',
            name: 'GLM-4-Plus',
            ownedBy: 'zhipu',
            contextLength: 128000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.other,
            functionCallingSupported: true,
          ),
          LlmModelDescriptor(
            id: 'glm-4-air',
            name: 'GLM-4-Air',
            ownedBy: 'zhipu',
            contextLength: 128000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.other,
            functionCallingSupported: true,
          ),
        ];
      case 'openrouter':
        return [
          LlmModelDescriptor(
            id: 'openrouter/auto',
            name: 'Auto (OpenRouter)',
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.other,
            functionCallingSupported: true,
          ),
        ];
      case 'xai':
      case 'grok':
        return [
          LlmModelDescriptor(
            id: 'grok-2',
            name: 'Grok 2',
            ownedBy: 'xai',
            contextLength: 128000,
            capabilities: ['text', 'function'],
            vendorFamily: ModelVendorFamily.xai,
            functionCallingSupported: true,
          ),
        ];
      default:
        // 自定义/未知平台，返回空列表由用户手动填写
        return [];
    }
  }

  // ========== TTS 端点 ==========

  void loadTtsEndpoints() {
    _ttsEndpoints = [];
    notifyListeners();
  }

  // ========== 工具方法 ==========

  String generateId() => _uuid.v4();
}

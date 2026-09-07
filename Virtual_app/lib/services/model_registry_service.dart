import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/endpoint.dart';

/// 模型注册表服务
///
/// 从 assets/registry/models.json 加载内置模型注册表，
/// 提供按厂商、按 id 查询等能力。
class ModelRegistryService {
  static ModelRegistryService? _instance;

  Map<String, List<LlmModelDescriptor>> _vendorModels = {};
  List<LlmModelDescriptor> _allModels = [];
  bool _loaded = false;

  ModelRegistryService._();

  factory ModelRegistryService() {
    _instance ??= ModelRegistryService._();
    return _instance!;
  }

  /// 是否已经加载完成
  bool get isLoaded => _loaded;

  /// 所有厂商 key 列表
  List<String> get vendorKeys => _vendorModels.keys.toList();

  /// 所有模型（同步访问，需确保已 load()）
  List<LlmModelDescriptor> get allModels => List.unmodifiable(_allModels);

  /// 从 assets 加载模型注册表
  Future<void> load() async {
    if (_loaded) return;

    try {
      final raw = await rootBundle.loadString('assets/registry/models.json');
      final Map<String, dynamic> jsonData = jsonDecode(raw);

      final Map<String, List<LlmModelDescriptor>> vendorMap = {};
      final List<LlmModelDescriptor> all = [];

      jsonData.forEach((vendorKey, modelsList) {
        final List<dynamic> list = modelsList as List<dynamic>;
        final vendorFamily = _mapVendorKeyToFamily(vendorKey);

        final models = list.map((m) {
          final map = m as Map<String, dynamic>;
          final id = map['id']?.toString() ?? '';
          final name = map['name']?.toString() ?? id;
          final contextLength = map['context_length'] as int? ?? 4096;
          final ownedBy = map['owned_by']?.toString() ?? '';

          // 解析定价（字符串 → double）
          ModelPricing? pricing;
          final pricingRaw = map['pricing'];
          if (pricingRaw is Map<String, dynamic>) {
            pricing = ModelPricing(
              promptPerToken:
                  double.tryParse(pricingRaw['prompt']?.toString() ?? '0') ??
                      0,
              completionPerToken:
                  double.tryParse(pricingRaw['completion']?.toString() ?? '0') ??
                      0,
            );
          }

          // 解析 capabilities
          final capabilities = <String>['text'];
          final capsRaw = map['capabilities'];
          if (capsRaw is Map<String, dynamic>) {
            if (capsRaw['reasoning'] == true) capabilities.add('reasoning');
            if (capsRaw['function_call'] == true) capabilities.add('function');
            if (capsRaw['caching'] == true) capabilities.add('cache');
            if (capsRaw['structured_output'] == true) {
              capabilities.add('structure');
            }
            if (capsRaw['code_interpreter'] == true) capabilities.add('code');
            if (capsRaw['tts'] == true) capabilities.add('tts');
            if (capsRaw['asr'] == true) capabilities.add('asr');
            if (capsRaw['image_generation'] == true) capabilities.add('image');
          }

          // 启发式判断能力
          final visionSupported = capsRaw != null
              ? (capsRaw['image_generation'] == true ||
                  capsRaw['vision'] == true ||
                  _checkVisionSupport(id))
              : _checkVisionSupport(id);
          final functionCallingSupported = capsRaw != null
              ? (capsRaw['function_call'] == true || _checkToolSupport(id))
              : _checkToolSupport(id);
          final reasoningSupported = capsRaw != null
              ? (capsRaw['reasoning'] == true || _checkReasoningSupport(id))
              : _checkReasoningSupport(id);

          // 补全 capabilities
          if (visionSupported && !capabilities.contains('image')) {
            capabilities.add('image');
          }
          if (functionCallingSupported && !capabilities.contains('function')) {
            capabilities.add('function');
          }
          if (reasoningSupported && !capabilities.contains('reasoning')) {
            capabilities.add('reasoning');
          }

          // 推断厂商系列（优先用 vendorKey，其次用 model id）
          final family = vendorFamily != ModelVendorFamily.other
              ? vendorFamily
              : _inferVendorFamilyFromModelId(id);

          return LlmModelDescriptor(
            id: id,
            name: name,
            ownedBy: ownedBy,
            contextLength: contextLength,
            capabilities: capabilities,
            pricing: pricing,
            vendorFamily: family,
            deprecated: false,
            visionSupported: visionSupported,
            functionCallingSupported: functionCallingSupported,
            reasoningSupported: reasoningSupported,
          );
        }).toList();

        vendorMap[vendorKey] = models;
        all.addAll(models);
      });

      _vendorModels = vendorMap;
      _allModels = all;
      _loaded = true;
    } catch (e) {
      // 加载失败时保持空状态，不抛出异常
      _vendorModels = {};
      _allModels = [];
      _loaded = false;
    }
  }

  /// 获取全部模型
  Future<List<LlmModelDescriptor>> getAllModels() async {
    if (!_loaded) await load();
    return List.unmodifiable(_allModels);
  }

  /// 按厂商获取模型列表
  List<LlmModelDescriptor> getModelsByVendor(String vendorKey) {
    return List.unmodifiable(_vendorModels[vendorKey] ?? const []);
  }

  /// 按 id 查找模型
  LlmModelDescriptor? findModelById(String modelId) {
    try {
      return _allModels.firstWhere((m) => m.id == modelId);
    } catch (_) {
      return null;
    }
  }

  // ========== 厂商映射 ==========

  ModelVendorFamily _mapVendorKeyToFamily(String vendorKey) {
    switch (vendorKey.toLowerCase()) {
      case 'openai':
        return ModelVendorFamily.openai;
      case 'claude':
      case 'anthropic':
        return ModelVendorFamily.anthropic;
      case 'gemini':
      case 'vertex':
        return ModelVendorFamily.google;
      case 'deepseek':
        return ModelVendorFamily.deepseek;
      case 'grok':
        return ModelVendorFamily.xai;
      case 'doubao':
      case 'openrouter_popular':
      default:
        return ModelVendorFamily.other;
    }
  }

  ModelVendorFamily _inferVendorFamilyFromModelId(String modelId) {
    final lower = modelId.toLowerCase();
    if (lower.startsWith('gpt-') || lower.startsWith('o1') || lower.startsWith('o3')) {
      return ModelVendorFamily.openai;
    }
    if (lower.startsWith('claude-')) {
      return ModelVendorFamily.anthropic;
    }
    if (lower.startsWith('gemini-') || lower.contains('gemini')) {
      return ModelVendorFamily.google;
    }
    if (lower.startsWith('deepseek-')) {
      return ModelVendorFamily.deepseek;
    }
    if (lower.startsWith('grok-')) {
      return ModelVendorFamily.xai;
    }
    if (lower.contains('qwen') || lower.contains('qwen2')) {
      return ModelVendorFamily.qwen;
    }
    if (lower.contains('mistral')) {
      return ModelVendorFamily.mistral;
    }
    if (lower.contains('llama') || lower.contains('meta')) {
      return ModelVendorFamily.meta;
    }
    if (lower.contains('yi-')) {
      return ModelVendorFamily.yi;
    }
    return ModelVendorFamily.other;
  }

  // ========== 能力启发式判断 ==========

  bool _checkVisionSupport(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('vision') ||
        lower.contains('gpt-4o') ||
        lower.contains('gpt-4-turbo') ||
        lower.contains('claude-3') ||
        lower.contains('gemini') ||
        lower.contains('qwen-vl') ||
        lower.contains('glm-4v') ||
        lower.contains('vl-') ||
        lower.contains('-vl');
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
        lower.contains('deepseek') ||
        lower.contains('mistral') ||
        lower.contains('sonnet') ||
        lower.contains('opus');
  }

  bool _checkReasoningSupport(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('reasoning') ||
        lower.contains('r1') ||
        lower.contains('o1') ||
        lower.contains('o3') ||
        lower.contains('deepseek-reasoner') ||
        lower.contains('thinking') ||
        lower.contains('fable') ||
        lower.contains('mythos') ||
        lower.contains('opus');
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/endpoint_provider.dart';
import '../../models/endpoint.dart';
import '../../models/conversation.dart';
import '../../services/api_service.dart';
import '../../services/model_registry_service.dart';

/// 端点编辑/新建页面
class EndpointEditPage extends StatefulWidget {
  final String? endpointId;

  const EndpointEditPage({super.key, this.endpointId});

  @override
  State<EndpointEditPage> createState() => _EndpointEditPageState();
}

class _EndpointEditPageState extends State<EndpointEditPage> {
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelSearchController = TextEditingController();
  final _customModelIdController = TextEditingController();
  final _customModelNameController = TextEditingController();

  String _selectedPlatform = 'openai';
  bool _isDefault = false;
  bool _enabled = true;
  bool _obscureApiKey = true;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isFetchingModels = false;
  bool _showAdvanced = false;

  List<LlmModelDescriptor> _selectedModels = [];

  /// 接口默认模型（从已添加模型中点选；对话未显式选模型时优先用它）
  String _defaultModelId = '';
  bool _testingConnection = false;
  Map<String, String> _customParams = {};

  static const List<Map<String, String>> _platforms = [
    {'key': 'openai', 'name': 'OpenAI 兼容', 'url': 'https://api.openai.com/v1'},
    {
      'key': 'anthropic',
      'name': 'Anthropic',
      'url': 'https://api.anthropic.com/v1'
    },
    {
      'key': 'gemini',
      'name': 'Google Gemini',
      'url': 'https://generativelanguage.googleapis.com/v1beta'
    },
    {'key': 'deepseek', 'name': 'DeepSeek', 'url': 'https://api.deepseek.com'},
    {
      'key': 'vertex_ai',
      'name': 'Google Vertex AI',
      'url': 'https://aiplatform.googleapis.com'
    },
    {'key': 'groq', 'name': 'Groq', 'url': 'https://api.groq.com/openai/v1'},
    {
      'key': 'moonshot',
      'name': 'Kimi (月之暗面)',
      'url': 'https://api.moonshot.cn/v1'
    },
    {
      'key': 'qwen',
      'name': 'Qwen (通义千问)',
      'url': 'https://dashscope.aliyuncs.com/compatible-mode/v1'
    },
    {
      'key': 'glm',
      'name': 'GLM (智谱清言)',
      'url': 'https://open.bigmodel.cn/api/paas/v4'
    },
    {'key': 'ollama', 'name': 'Ollama', 'url': 'http://localhost:11434/v1'},
    {
      'key': 'openrouter',
      'name': 'OpenRouter',
      'url': 'https://openrouter.ai/api/v1'
    },
    {'key': 'xai', 'name': 'xAI (Grok)', 'url': 'https://api.x.ai/v1'},
    {
      'key': 'poprouter',
      'name': 'PopRouter',
      'url': 'https://api.poprouter.ai'
    },
    {'key': 'volink', 'name': 'Volink', 'url': 'https://api.volink.org'},
    {'key': 'novelai', 'name': 'NovelAI', 'url': 'https://image.novelai.net'},
    {'key': 'custom', 'name': '自定义', 'url': ''},
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.endpointId != null;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 加载模型注册表
    final registry = ModelRegistryService();
    if (!registry.isLoaded) {
      await registry.load();
    }

    // 如果是编辑模式，加载端点数据
    if (_isEditing && widget.endpointId != null) {
      if (!mounted) return;
      final provider = context.read<EndpointProvider>();
      final endpoint = provider.llmEndpoints.firstWhere(
        (e) => e.id == widget.endpointId,
        orElse: () => throw 'Endpoint not found',
      );
      _nameController.text = endpoint.name;
      _baseUrlController.text = endpoint.baseUrl;
      _apiKeyController.text = endpoint.apiKey;
      _selectedPlatform = endpoint.platform;
      _isDefault = endpoint.isDefault;
      _enabled = endpoint.enabled;
      _selectedModels = List.from(endpoint.models);
      _defaultModelId = endpoint.defaultModelId;
      _customParams = Map.from(endpoint.customParams);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelSearchController.dispose();
    _customModelIdController.dispose();
    _customModelNameController.dispose();
    super.dispose();
  }

  void _onPlatformChanged(String? platform) {
    if (platform == null) return;
    setState(() {
      _selectedPlatform = platform;
      // 自动填充默认 Base URL
      final plat = _platforms.firstWhere(
        (p) => p['key'] == platform,
        orElse: () => {'url': ''},
      );
      final defaultUrl = plat['url'] ?? '';
      if (defaultUrl.isNotEmpty) {
        _baseUrlController.text = defaultUrl;
      }
      // 自动填充名称（如果为空）
      if (_nameController.text.isEmpty) {
        _nameController.text = plat['name'] ?? platform;
      }
    });
  }

  /// 连接测试：用当前表单配置临时构建端点，发一条 1-token 请求验证连通性。
  /// 不依赖已保存的数据——未保存的新接口也能直接测。
  Future<void> _testConnection() async {
    final name = _nameController.text.trim();
    final baseUrl =
        _baseUrlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入接口名称')),
      );
      return;
    }
    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Base URL')),
      );
      return;
    }
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API Key')),
      );
      return;
    }
    if (_selectedModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加或获取模型')),
      );
      return;
    }

    final testModelId = _defaultModelId.isNotEmpty
        ? _defaultModelId
        : _selectedModels.first.id;

    setState(() => _testingConnection = true);

    // 临时端点：只用于本次测试，不落库（ApiService 用新实例避免适配器缓存）
    final testEndpoint = LlmEndpoint(
      id: 'conn-test-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      platform: _selectedPlatform,
      baseUrl: baseUrl,
      apiKey: apiKey,
      models: _selectedModels,
      defaultModelId: _defaultModelId,
      customParams: _customParams,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final adapter = ApiService().getAdapter(testEndpoint);
      final sw = Stopwatch()..start();
      // 温度固定 1.0：思考类模型（如 kimi-k3/o1 系列）只接受 temperature=1，
      // 通用连通性测试与采样随机性无关，1 是各厂商兼容度最高的值
      final resp = await adapter.chatCompletions(
        model: testModelId,
        messages: const [
          {'role': 'user', 'content': 'Hi'},
        ],
        settings: ChatSettings(maxTokens: 8, temperature: 1.0),
      );
      sw.stop();

      if (mounted) {
        final ms = sw.elapsedMilliseconds;
        final preview = resp.content.trim();
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('连接成功'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _testInfoRow('耗时', '${(ms / 1000).toStringAsFixed(1)} 秒'),
                _testInfoRow('模型', testModelId),
                if (preview.isNotEmpty) _testInfoRow('回复', preview),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(ctx).colorScheme.error),
                const SizedBox(width: 8),
                const Text('连接失败'),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                msg.length > 400 ? '${msg.substring(0, 400)}…' : msg,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Widget _testInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13.5)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEndpoint() async {    final name = _nameController.text.trim();
    final baseUrl =
        _baseUrlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入接口名称')),
      );
      return;
    }
    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Base URL')),
      );
      return;
    }
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API Key')),
      );
      return;
    }

    final provider = context.read<EndpointProvider>();
    final now = DateTime.now();

    if (_isEditing && widget.endpointId != null) {
      final existing = provider.llmEndpoints.firstWhere(
        (e) => e.id == widget.endpointId,
        orElse: () => throw 'Endpoint not found',
      );
      final updated = existing.copyWith(
        name: name,
        platform: _selectedPlatform,
        baseUrl: baseUrl,
        apiKey: apiKey,
        models: _selectedModels,
        defaultModelId: _defaultModelId,
        isDefault: _isDefault,
        enabled: _enabled,
        customParams: _customParams,
        updatedAt: now,
      );
      await provider.saveLlmEndpoint(updated);
    } else {
      final endpoint = LlmEndpoint(
        id: provider.generateId(),
        name: name,
        platform: _selectedPlatform,
        baseUrl: baseUrl,
        apiKey: apiKey,
        models: _selectedModels,
        defaultModelId: _defaultModelId,
        isDefault: _isDefault,
        enabled: _enabled,
        customParams: _customParams,
        createdAt: now,
        updatedAt: now,
      );
      await provider.saveLlmEndpoint(endpoint);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? '已保存' : '已创建')),
      );
      context.go('/endpoints');
    }
  }

  Future<void> _deleteEndpoint() async {
    if (widget.endpointId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除接口'),
        content: const Text('确定要删除这个接口吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context
          .read<EndpointProvider>()
          .deleteLlmEndpoint(widget.endpointId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
        context.go('/endpoints');
      }
    }
  }

  Future<void> _fetchModelsFromRemote() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写 Base URL 和 API Key')),
      );
      return;
    }

    setState(() => _isFetchingModels = true);

    try {
      final provider = context.read<EndpointProvider>();
      final tempEndpoint = LlmEndpoint(
        id: 'temp',
        name: 'temp',
        platform: _selectedPlatform,
        baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
        apiKey: apiKey,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final fetched = await provider.fetchModels(tempEndpoint);

      // 合并：已有的保留，新增的追加
      final existingIds = _selectedModels.map((m) => m.id).toSet();
      final newModels =
          fetched.where((m) => !existingIds.contains(m.id)).toList();
      _selectedModels = [..._selectedModels, ...newModels];
      // 尚未指定默认模型时，自动落到第一个，保证接口始终有明确的可用模型
      if (_defaultModelId.isEmpty && _selectedModels.isNotEmpty) {
        _defaultModelId = _selectedModels.first.id;
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('获取到 ${fetched.length} 个模型，新增 ${newModels.length} 个')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingModels = false);
      }
    }
  }

  void _showRegistryDialog() {
    final registry = ModelRegistryService();
    showDialog(
      context: context,
      builder: (ctx) => _ModelRegistryDialog(
        registry: registry,
        selectedModelIds: _selectedModels.map((m) => m.id).toSet(),
        onModelsSelected: (models) {
          setState(() {
            final existingIds = _selectedModels.map((m) => m.id).toSet();
            final newModels = models.where((m) => !existingIds.contains(m.id));
            _selectedModels = [..._selectedModels, ...newModels];
            if (_defaultModelId.isEmpty && _selectedModels.isNotEmpty) {
              _defaultModelId = _selectedModels.first.id;
            }
          });
        },
      ),
    );
  }

  void _showCustomModelDialog() {
    _customModelIdController.clear();
    _customModelNameController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动添加模型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customModelIdController,
              decoration: const InputDecoration(
                labelText: '模型 ID',
                border: OutlineInputBorder(),
                hintText: '例如: my-model-v1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customModelNameController,
              decoration: const InputDecoration(
                labelText: '显示名称',
                border: OutlineInputBorder(),
                hintText: '例如: 我的模型 V1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final id = _customModelIdController.text.trim();
              final name = _customModelNameController.text.trim();
              if (id.isEmpty) return;

              setState(() {
                _selectedModels.add(LlmModelDescriptor(
                  id: id,
                  name: name.isEmpty ? id : name,
                ));
                if (_defaultModelId.isEmpty) {
                  _defaultModelId = id;
                }
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _removeModel(String modelId) {
    setState(() {
      _selectedModels.removeWhere((m) => m.id == modelId);
      // 删掉的恰是默认模型：顺移到剩余第一个
      if (_defaultModelId == modelId) {
        _defaultModelId = _selectedModels.firstOrNull?.id ?? '';
      }
    });
  }

  void _addCustomParam() {
    setState(() {
      _customParams[''] = '';
    });
  }

  void _updateCustomParamKey(String oldKey, String newKey) {
    setState(() {
      final value = _customParams[oldKey] ?? '';
      _customParams.remove(oldKey);
      _customParams[newKey] = value;
    });
  }

  void _updateCustomParamValue(String key, String value) {
    _customParams[key] = value;
  }

  void _removeCustomParam(String key) {
    setState(() {
      _customParams.remove(key);
    });
  }

  List<LlmModelDescriptor> get _filteredModels {
    final query = _modelSearchController.text.toLowerCase();
    if (query.isEmpty) return _selectedModels;
    return _selectedModels
        .where((m) =>
            m.id.toLowerCase().contains(query) ||
            m.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '编辑接口' : '新接口'),
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/endpoints');
              }
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑接口' : '新接口'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/endpoints');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _saveEndpoint,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 平台选择
          const Text('平台类型', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _platforms.any((p) => p['key'] == _selectedPlatform)
                ? _selectedPlatform
                : 'custom',
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _platforms.map((p) {
              return DropdownMenuItem<String>(
                value: p['key'],
                child: Text(p['name'] ?? p['key']!),
              );
            }).toList(),
            onChanged: _onPlatformChanged,
          ),
          const SizedBox(height: 20),

          // 名称
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '接口名称',
              border: OutlineInputBorder(),
              hintText: '给这个接口起个名字',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),

          // Base URL
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              border: OutlineInputBorder(),
              hintText: 'https://api.example.com/v1',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 16),

          // API Key
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              hintText: 'sk-...',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _obscureApiKey = !_obscureApiKey);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 模型管理区域
          Row(
            children: [
              const Text(
                '模型列表',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
              const Spacer(),
              Text(
                _defaultModelId.isEmpty
                    ? '未选择模型'
                    : '当前使用：${_selectedModels.where((m) => m.id == _defaultModelId).firstOrNull?.name ?? _defaultModelId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _defaultModelId.isEmpty
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 模型操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showRegistryDialog,
                  icon: const Icon(Icons.grid_view_outlined),
                  label: const Text('从注册表添加'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isFetchingModels ? null : _fetchModelsFromRemote,
                  icon: _isFetchingModels
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: Text(_isFetchingModels ? '获取中...' : '从远端获取'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 手动添加 & 搜索
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _modelSearchController,
                  decoration: InputDecoration(
                    hintText: '搜索模型...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showCustomModelDialog,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '手动添加',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 已选模型列表
          if (_filteredModels.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.extension_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '还没有添加模型',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredModels.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  final model = _filteredModels[index];
                  final isDefaultModel = model.id == _defaultModelId;
                  return ListTile(
                    dense: true,
                    // 点击模型行 = 设为该接口的默认模型
                    onTap: () =>
                        setState(() => _defaultModelId = model.id),
                    leading: CircleAvatar(
                      radius: 16,
                      child: Icon(
                        _getModelIcon(model),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      model.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      isDefaultModel ? '${model.id} · 当前使用' : model.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDefaultModel
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDefaultModel)
                          Icon(Icons.check_circle,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary)
                        else
                          Icon(Icons.circle_outlined,
                              size: 18,
                              color:
                                  Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(width: 6),
                        if (model.visionSupported)
                          const Icon(Icons.photo, size: 14),
                        const SizedBox(width: 4),
                        if (model.functionCallingSupported)
                          const Icon(Icons.build, size: 14),
                        const SizedBox(width: 4),
                        if (model.reasoningSupported)
                          const Icon(Icons.psychology, size: 14),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeModel(model.id),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),

          // 高级设置折叠
          ExpansionTile(
            title: const Text('高级设置'),
            leading: const Icon(Icons.tune),
            initiallyExpanded: _showAdvanced,
            onExpansionChanged: (v) => setState(() => _showAdvanced = v),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 启用开关
                    SwitchListTile(
                      title: const Text('启用接口'),
                      subtitle: Text(
                        _enabled ? '接口可用' : '接口已禁用',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                      contentPadding: EdgeInsets.zero,
                    ),

                    // 设为默认
                    SwitchListTile(
                      title: const Text('设为默认接口'),
                      subtitle: Text(
                        _isDefault ? '新对话默认使用此接口' : '点击设为默认',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),

                    // 自定义请求参数
                    Row(
                      children: [
                        const Text(
                          '自定义请求参数',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addCustomParam,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('添加'),
                        ),
                      ],
                    ),
                    if (_customParams.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '暂无自定义参数',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ..._customParams.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: TextEditingController(
                                    text: entry.key,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '参数名',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onChanged: (val) =>
                                      _updateCustomParamKey(entry.key, val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: TextEditingController(
                                    text: entry.value,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '参数值',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onChanged: (val) =>
                                      _updateCustomParamValue(entry.key, val),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _removeCustomParam(entry.key),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 连接测试按钮
          OutlinedButton.icon(
            onPressed: _testingConnection ? null : _testConnection,
            icon: _testingConnection
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bolt),
            label: Text(_testingConnection ? '测试中…' : '测试连接'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 12),

          // 保存按钮
          FilledButton.icon(
            onPressed: _saveEndpoint,
            icon: const Icon(Icons.check),
            label: Text(_isEditing ? '保存修改' : '创建接口'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          // 删除按钮（编辑模式）
          if (_isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _deleteEndpoint,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                '删除接口',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  IconData _getModelIcon(LlmModelDescriptor model) {
    switch (model.vendorFamily) {
      case ModelVendorFamily.openai:
        return Icons.smart_toy;
      case ModelVendorFamily.anthropic:
        return Icons.psychology;
      case ModelVendorFamily.google:
        return Icons.auto_awesome;
      case ModelVendorFamily.deepseek:
        return Icons.search;
      case ModelVendorFamily.xai:
        return Icons.bolt;
      case ModelVendorFamily.qwen:
        return Icons.auto_fix_high;
      default:
        return Icons.extension;
    }
  }
}

/// 模型注册表选择对话框
class _ModelRegistryDialog extends StatefulWidget {
  final ModelRegistryService registry;
  final Set<String> selectedModelIds;
  final ValueChanged<List<LlmModelDescriptor>> onModelsSelected;

  const _ModelRegistryDialog({
    required this.registry,
    required this.selectedModelIds,
    required this.onModelsSelected,
  });

  @override
  State<_ModelRegistryDialog> createState() => _ModelRegistryDialogState();
}

class _ModelRegistryDialogState extends State<_ModelRegistryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  late List<String> _vendorKeys;
  final Set<String> _checkedIds = {};

  @override
  void initState() {
    super.initState();
    _vendorKeys = widget.registry.vendorKeys;
    _tabController = TabController(length: _vendorKeys.length, vsync: this);
    _checkedIds.addAll(widget.selectedModelIds);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getVendorDisplayName(String key) {
    switch (key) {
      case 'openai':
        return 'OpenAI';
      case 'claude':
        return 'Claude';
      case 'gemini':
        return 'Gemini';
      case 'deepseek':
        return 'DeepSeek';
      case 'grok':
        return 'Grok';
      case 'doubao':
        return '豆包';
      case 'openrouter_popular':
        return 'OpenRouter';
      case 'vertex':
        return 'Vertex AI';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text(
                    '从注册表添加模型',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '已选 ${_checkedIds.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索模型...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),

            // Tab 栏
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: _vendorKeys
                  .map((k) => Tab(text: _getVendorDisplayName(k)))
                  .toList(),
            ),

            // 模型列表
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _vendorKeys.map((vendorKey) {
                  final models = widget.registry.getModelsByVendor(vendorKey);
                  final query = _searchController.text.toLowerCase();
                  final filtered = query.isEmpty
                      ? models
                      : models
                          .where((m) =>
                              m.id.toLowerCase().contains(query) ||
                              m.name.toLowerCase().contains(query))
                          .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('无匹配模型'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final model = filtered[index];
                      final isChecked = _checkedIds.contains(model.id);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(model.name),
                        subtitle: Text(
                          model.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _checkedIds.add(model.id);
                            } else {
                              _checkedIds.remove(model.id);
                            }
                          });
                        },
                        secondary: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (model.visionSupported)
                              const Icon(Icons.photo, size: 14),
                            const SizedBox(width: 2),
                            if (model.functionCallingSupported)
                              const Icon(Icons.build, size: 14),
                            const SizedBox(width: 2),
                            if (model.reasoningSupported)
                              const Icon(Icons.psychology, size: 14),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),

            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        // 全选/取消当前 tab
                        final currentVendor = _vendorKeys[_tabController.index];
                        final currentModels =
                            widget.registry.getModelsByVendor(currentVendor);
                        final currentIds =
                            currentModels.map((m) => m.id).toSet();
                        final allChecked =
                            currentIds.every((id) => _checkedIds.contains(id));
                        if (allChecked) {
                          _checkedIds.removeAll(currentIds);
                        } else {
                          _checkedIds.addAll(currentIds);
                        }
                      });
                    },
                    child: const Text('全选/取消'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      // 收集所有选中的模型
                      final allModels = widget.registry.allModels;
                      final selected = allModels
                          .where((m) => _checkedIds.contains(m.id))
                          .toList();
                      widget.onModelsSelected(selected);
                      Navigator.of(context).pop();
                    },
                    child: Text('添加 (${_checkedIds.length})'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

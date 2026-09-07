class PluginInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final bool enabled;
  final String? code;

  const PluginInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    this.enabled = false,
    this.code,
  });

  factory PluginInfo.fromJson(Map<String, dynamic> json) {
    return PluginInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      enabled: json['enabled'] as bool? ?? false,
      code: json['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'enabled': enabled,
        'code': code,
      };
}

class PluginService {
  static PluginService? _instance;
  PluginService._();
  factory PluginService() => _instance ??= PluginService._();

  final List<PluginInfo> _plugins = [];
  bool _initialized = false;

  List<PluginInfo> get plugins => List.unmodifiable(_plugins);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> loadPlugins() async {
    _plugins.clear();
  }

  Future<void> installPlugin(PluginInfo plugin) async {
    _plugins.add(plugin);
  }

  Future<void> uninstallPlugin(String pluginId) async {
    _plugins.removeWhere((p) => p.id == pluginId);
  }

  Future<void> togglePlugin(String pluginId, bool enabled) async {
    final index = _plugins.indexWhere((p) => p.id == pluginId);
    if (index != -1) {
      _plugins[index] = PluginInfo(
        id: _plugins[index].id,
        name: _plugins[index].name,
        description: _plugins[index].description,
        version: _plugins[index].version,
        enabled: enabled,
        code: _plugins[index].code,
      );
    }
  }

  Future<dynamic> executePlugin(
      String pluginId, String action, Map<String, dynamic> params) async {
    final plugin = _plugins.firstWhere(
      (p) => p.id == pluginId,
      orElse: () => throw Exception('Plugin not found: $pluginId'),
    );
    if (!plugin.enabled) throw Exception('Plugin disabled: $pluginId');
    return {'status': 'ok', 'action': action};
  }
}

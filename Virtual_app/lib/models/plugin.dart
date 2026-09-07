
/// 插件功能类型
enum PluginFeatureKind {
  ui,
  tool,
  generator,
  theme,
  translator,
  tts,
  asr,
  storage,
}

/// 插件运行时同步类型
enum PluginRuntimeSyncKind {
  sync,
  async,
  stream,
}

/// 插件 HTML 聊天区域
enum PluginHtmlChatRegion {
  top,
  bottom,
  side,
  overlay,
  bubble,
}

/// 插件 HTML 消息位置
enum PluginHtmlMessagePosition {
  before,
  after,
  inside,
  replacement,
}

/// 插件 HTML 消息角色
enum PluginHtmlMessageRole {
  user,
  assistant,
  system,
  all,
}

/// 插件 HTML 插槽
enum PluginHtmlSlot {
  chatConsole,
  chatHeader,
  chatFooter,
  characterEditor,
  settings,
  sidebar,
}

/// 插件生成本文钩子阶段
enum GenerationPhase {
  beforeSend,
  afterResponse,
}

/// 插件动作分派失败
class PluginActionDispatchFailure implements Exception {
  final String pluginId;
  final String action;
  final String reason;

  PluginActionDispatchFailure({
    required this.pluginId,
    required this.action,
    required this.reason,
  });
}

/// 插件安装错误码
enum PluginInstallErrorCode {
  invalidManifest,
  downloadFailed,
  extractFailed,
  versionConflict,
  permissionDenied,
  unknown,
}

/// 插件安装异常
class PluginInstallException implements Exception {
  final PluginInstallErrorCode code;
  final String message;

  PluginInstallException(this.code, this.message);
}

/// 插件清单错误码
enum PluginManifestErrorCode {
  missingName,
  missingVersion,
  invalidFormat,
  unsupportedVersion,
  missingEntry,
}

/// 插件清单异常
class PluginManifestException implements Exception {
  final PluginManifestErrorCode code;
  final String message;

  PluginManifestException(this.code, this.message);
}

/// 已安装的插件
class InstalledPlugin {
  final String id;
  final String name;
  final String version;
  final String description;
  final String? author;
  final PluginRuntime runtime;
  final bool enabled;
  final List<PluginFeatureKind> features;
  final Map<String, dynamic> config;
  final String? entryUrl;
  final DateTime installedAt;
  final DateTime updatedAt;
  final String? iconPath;
  final List<String> permissions;

  InstalledPlugin({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.author,
    required this.runtime,
    this.enabled = true,
    this.features = const [],
    this.config = const {},
    this.entryUrl,
    required this.installedAt,
    required this.updatedAt,
    this.iconPath,
    this.permissions = const [],
  });

  InstalledPlugin copyWith({
    String? id,
    String? name,
    String? version,
    String? description,
    String? author,
    PluginRuntime? runtime,
    bool? enabled,
    List<PluginFeatureKind>? features,
    Map<String, dynamic>? config,
    String? entryUrl,
    DateTime? installedAt,
    DateTime? updatedAt,
    String? iconPath,
    List<String>? permissions,
  }) {
    return InstalledPlugin(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      author: author ?? this.author,
      runtime: runtime ?? this.runtime,
      enabled: enabled ?? this.enabled,
      features: features ?? this.features,
      config: config ?? this.config,
      entryUrl: entryUrl ?? this.entryUrl,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? DateTime.now(),
      iconPath: iconPath ?? this.iconPath,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'author': author,
        'runtime': runtime.name,
        'enabled': enabled,
        'features': features.map((e) => e.name).toList(),
        'config': config,
        'entryUrl': entryUrl,
        'installedAt': installedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'iconPath': iconPath,
        'permissions': permissions,
      };

  factory InstalledPlugin.fromJson(Map<String, dynamic> json) =>
      InstalledPlugin(
        id: json['id'],
        name: json['name'] ?? '',
        version: json['version'] ?? '1.0.0',
        description: json['description'] ?? '',
        author: json['author'],
        runtime: PluginRuntime.values.firstWhere(
          (e) => e.name == json['runtime'],
          orElse: () => PluginRuntime.html,
        ),
        enabled: json['enabled'] ?? true,
        features: (json['features'] as List?)
                ?.map((e) => PluginFeatureKind.values.firstWhere(
                      (f) => f.name == e,
                      orElse: () => PluginFeatureKind.ui,
                    ))
                .toList() ??
            [],
        config: Map<String, dynamic>.from(json['config'] ?? {}),
        entryUrl: json['entryUrl'],
        installedAt: DateTime.parse(json['installedAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        iconPath: json['iconPath'],
        permissions: List<String>.from(json['permissions'] ?? []),
      );
}

/// 插件运行时类型
enum PluginRuntime {
  html, // HTML/CSS/JS 插件
  quickjs, // QuickJS 插件
  native, // 原生插件
}

/// 插件动作
class PluginAction {
  final String id;
  final String name;
  final String pluginId;
  final PluginFeatureKind kind;
  final Map<String, dynamic> params;

  PluginAction({
    required this.id,
    required this.name,
    required this.pluginId,
    required this.kind,
    this.params = const {},
  });
}

/// 插件事件
class PluginEvent {
  final String pluginId;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  PluginEvent({
    required this.pluginId,
    required this.type,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 插件生成本文钩子
class PluginGenerationTextHook {
  final String pluginId;
  final String hookId;
  final GenerationPhase phase;
  final bool enabled;
  final int order;

  PluginGenerationTextHook({
    required this.pluginId,
    required this.hookId,
    required this.phase,
    this.enabled = true,
    this.order = 0,
  });
}

/// 插件 HTML 片段
class PluginHtmlFragments {
  final String pluginId;
  final Map<PluginHtmlSlot, String> slots;
  final Map<PluginHtmlChatRegion, String> regions;

  PluginHtmlFragments({
    required this.pluginId,
    this.slots = const {},
    this.regions = const {},
  });
}

/// 插件 HTML 表面
class PluginHtmlSurface {
  final String pluginId;
  final String title;
  final String htmlContent;
  final bool isModal;

  PluginHtmlSurface({
    required this.pluginId,
    required this.title,
    required this.htmlContent,
    this.isModal = false,
  });
}

/// 插件拦截器
class PluginInterceptor {
  final String pluginId;
  final String interceptorId;
  final String target;
  final bool enabled;

  PluginInterceptor({
    required this.pluginId,
    required this.interceptorId,
    required this.target,
    this.enabled = true,
  });
}

/// 插件本地化
class PluginLocalization {
  final String pluginId;
  final Map<String, Map<String, String>> bundles;

  PluginLocalization({
    required this.pluginId,
    this.bundles = const {},
  });
}

/// 插件本地化包
class PluginLocalizationBundle {
  final String locale;
  final Map<String, String> strings;

  PluginLocalizationBundle({
    required this.locale,
    required this.strings,
  });
}

/// 插件注册器
class PluginRegistrant {
  final String pluginId;
  final String libraryName;
  final bool registered;

  PluginRegistrant({
    required this.pluginId,
    required this.libraryName,
    this.registered = false,
  });
}

/// 插件注册库
class PluginRegistrantLibrary {
  final String name;
  final String version;
  final Set<String> pluginIds;

  PluginRegistrantLibrary({
    required this.name,
    required this.version,
    this.pluginIds = const {},
  });
}

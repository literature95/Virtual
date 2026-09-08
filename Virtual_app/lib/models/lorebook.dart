
/// Lorebook 条目匹配策略
enum LorebookEntryMatchStrategy {
  exact, // 精确匹配
  partial, // 部分匹配
  regex, // 正则匹配
}

/// Lorebook 条目位置
enum LorebookEntryPosition {
  beforeSystem,
  afterSystem,
  beforeUser,
  afterUser,
  beforeAssistant,
  afterAssistant,
  top,
  bottom,
}

/// Lorebook 条目格式
enum LorebookEntryFormat {
  plainText,
  markdown,
  json,
}

/// Lorebook 状态
enum LorebookState {
  idle,
  loading,
  loaded,
  saving,
  error,
}

/// Lorebook
///
/// 字段设计对齐 Character Card v2/v3 的 `character_book`（世界书）规范，
/// 保证从第三方角色卡导入时可无损落地，导出时可回环（round-trip）。
class Lorebook {
  final String id;
  final String name;
  final String description;
  final List<LorebookEntry> entries;
  final bool enabled;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 向前扫描多少条历史消息用于关键词匹配（对应 `character_book.scan_depth`）
  final int scanDepth;

  /// 世界书注入内容的 token 预算（对应 `character_book.token_budget`）
  final int tokenBudget;

  /// 是否允许条目递归触发（对应 `character_book.recursive_scanning`）
  final bool recursiveScanning;

  /// 原始扩展数据（chub / agnai / depth_prompt 等厂商私有字段）
  final Map<String, dynamic> extensions;

  Lorebook({
    required this.id,
    required this.name,
    this.description = '',
    this.entries = const [],
    this.enabled = true,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
    this.scanDepth = 0,
    this.tokenBudget = 0,
    this.recursiveScanning = false,
    this.extensions = const {},
  });

  Lorebook copyWith({
    String? id,
    String? name,
    String? description,
    List<LorebookEntry>? entries,
    bool? enabled,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? scanDepth,
    int? tokenBudget,
    bool? recursiveScanning,
    Map<String, dynamic>? extensions,
  }) {
    return Lorebook(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      entries: entries ?? this.entries,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      scanDepth: scanDepth ?? this.scanDepth,
      tokenBudget: tokenBudget ?? this.tokenBudget,
      recursiveScanning: recursiveScanning ?? this.recursiveScanning,
      extensions: extensions ?? this.extensions,
    );
  }

  /// 从 Character Card v2/v3 的 `character_book` 节点构建
  ///
  /// [fallbackName] 用于缺少 `name` 字段时补默认名。
  factory Lorebook.fromCharacterBook(
    Map<String, dynamic> book, {
    String? fallbackName,
  }) {
    final now = DateTime.now();
    final rawEntries = book['entries'];
    final entries = rawEntries is List
        ? rawEntries
            .whereType<Map>()
            .map((e) => LorebookEntry.fromCharacterBook(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <LorebookEntry>[];

    return Lorebook(
      id: _nowId(),
      name: (book['name'] as String? ?? fallbackName ?? 'World Book').isEmpty
          ? (fallbackName ?? 'World Book')
          : book['name'] as String,
      description: book['description'] as String? ?? '',
      entries: entries,
      enabled: true,
      order: 0,
      createdAt: now,
      updatedAt: now,
      scanDepth: _asInt(book['scan_depth']) ?? 0,
      tokenBudget: _asInt(book['token_budget']) ?? 0,
      recursiveScanning: book['recursive_scanning'] == true,
      extensions: Map<String, dynamic>.from(book['extensions'] ?? {}),
    );
  }

  /// 回写为 Character Card v2/v3 的 `character_book` 节点
  Map<String, dynamic> toCharacterBook() => {
        'name': name,
        'description': description,
        'scan_depth': scanDepth,
        'token_budget': tokenBudget,
        'recursive_scanning': recursiveScanning,
        'extensions': extensions,
        'entries': entries.map((e) => e.toCharacterBook()).toList(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'entries': entries.map((e) => e.toJson()).toList(),
        'enabled': enabled,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'scanDepth': scanDepth,
        'tokenBudget': tokenBudget,
        'recursiveScanning': recursiveScanning,
        'extensions': extensions,
      };

  factory Lorebook.fromJson(Map<String, dynamic> json) => Lorebook(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        entries: (json['entries'] as List?)
                ?.map((e) => LorebookEntry.fromJson(e))
                .toList() ??
            [],
        enabled: json['enabled'] ?? true,
        order: json['order'] ?? 0,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        scanDepth: _asInt(json['scanDepth']) ?? 0,
        tokenBudget: _asInt(json['tokenBudget']) ?? 0,
        recursiveScanning: json['recursiveScanning'] ?? false,
        extensions: Map<String, dynamic>.from(json['extensions'] ?? {}),
      );
}

/// Lorebook 条目
class LorebookEntry {
  final String id;

  /// 主触发关键词（展示用；实际匹配以 [keys] 为准，为空时回落到 [key]）
  final String key;

  /// 全部主触发关键词（对应 `character_book.entries[].keys`）
  final List<String> keys;
  final List<String> secondaryKeys; // 附加关键词
  final String content; // 注入内容
  final LorebookEntryMatchStrategy matchStrategy;
  final LorebookEntryPosition position; // 注入位置
  final LorebookEntryFormat format;
  final bool enabled;
  final int order;
  final bool caseSensitive;
  final int? tokenBudget;
  final String? comment;

  /// 冲突时的优先级（对应 `character_book.entries[].priority`）
  final int priority;

  /// 触发概率 0-100（对应 `character_book.entries[].probability`）
  final int probability;

  /// 是否需要在主+次要关键词全部命中时才注入（对应 `selective`）
  final bool selective;

  /// 是否常驻注入（忽略关键词匹配，对应 `constant`）
  final bool constant;

  /// 条目插入的消息深度（`extensions.depth`）
  final int depth;

  /// 厂商私有扩展（如 chub 的 embedded / addMemo / useProbability）
  final Map<String, dynamic> extensions;

  LorebookEntry({
    required this.id,
    required this.key,
    List<String>? keys,
    this.secondaryKeys = const [],
    required this.content,
    this.matchStrategy = LorebookEntryMatchStrategy.partial,
    this.position = LorebookEntryPosition.bottom,
    this.format = LorebookEntryFormat.plainText,
    this.enabled = true,
    this.order = 0,
    this.caseSensitive = false,
    this.tokenBudget,
    this.comment,
    this.priority = 10,
    this.probability = 100,
    this.selective = false,
    this.constant = false,
    this.depth = 4,
    this.extensions = const {},
  }) : keys = keys ?? (key.isEmpty ? const [] : [key]);

  LorebookEntry copyWith({
    String? id,
    String? key,
    List<String>? keys,
    List<String>? secondaryKeys,
    String? content,
    LorebookEntryMatchStrategy? matchStrategy,
    LorebookEntryPosition? position,
    LorebookEntryFormat? format,
    bool? enabled,
    int? order,
    bool? caseSensitive,
    int? tokenBudget,
    String? comment,
    int? priority,
    int? probability,
    bool? selective,
    bool? constant,
    int? depth,
    Map<String, dynamic>? extensions,
  }) {
    return LorebookEntry(
      id: id ?? this.id,
      key: key ?? this.key,
      keys: keys ?? this.keys,
      secondaryKeys: secondaryKeys ?? this.secondaryKeys,
      content: content ?? this.content,
      matchStrategy: matchStrategy ?? this.matchStrategy,
      position: position ?? this.position,
      format: format ?? this.format,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      tokenBudget: tokenBudget ?? this.tokenBudget,
      comment: comment ?? this.comment,
      priority: priority ?? this.priority,
      probability: probability ?? this.probability,
      selective: selective ?? this.selective,
      constant: constant ?? this.constant,
      depth: depth ?? this.depth,
      extensions: extensions ?? this.extensions,
    );
  }

  /// 实际参与匹配的关键词列表
  List<String> get matchKeys => keys.isEmpty ? [key] : keys;

  /// 从 Character Card v2/v3 的 `character_book.entries[]` 节点构建
  factory LorebookEntry.fromCharacterBook(Map<String, dynamic> e) {
    final rawKeys = _asStringList(e['keys']);
    final secondary = _asStringList(e['secondary_keys']);
    final exts = Map<String, dynamic>.from(e['extensions'] ?? {});
    final primary = rawKeys.isNotEmpty ? rawKeys.first : '';

    return LorebookEntry(
      id: _nowId(),
      key: primary,
      keys: rawKeys,
      secondaryKeys: secondary,
      content: e['content'] as String? ?? '',
      matchStrategy: LorebookEntryMatchStrategy.partial,
      position: _positionFromCharacterBook(e['position'] as String?),
      format: LorebookEntryFormat.plainText,
      enabled: e['enabled'] ?? true,
      order: _asInt(e['insertion_order']) ?? 0,
      caseSensitive: e['case_sensitive'] == true,
      tokenBudget: _asInt(e['token_budget']),
      comment: e['comment'] as String? ?? '',
      priority: _asInt(e['priority']) ?? 10,
      probability: _asInt(e['probability']) ?? 100,
      selective: e['selective'] == true,
      constant: e['constant'] == true,
      depth: _asInt(exts['depth']) ?? _asInt(e['depth']) ?? 4,
      extensions: exts,
    );
  }

  /// 回写为 `character_book.entries[]` 节点（保证导入↔导出不丢字段）
  Map<String, dynamic> toCharacterBook() => {
        'keys': matchKeys,
        'secondary_keys': secondaryKeys,
        'content': content,
        'enabled': enabled,
        'insertion_order': order,
        'case_sensitive': caseSensitive,
        'priority': priority,
        'comment': comment ?? '',
        'selective': selective,
        'constant': constant,
        'position': position.toCharacterBook(),
        'extensions': <String, dynamic>{
          ...extensions,
          'depth': depth,
        },
        'probability': probability,
      };

  /// CCv3 position → App 注入位置映射
  ///
  /// CCv3 常见取值：`before_char` / `after_char` / `before_example` /
  /// `after_example` / `before_scenario`。App 的注入管线以 system 为核心，
  /// 因此「char 之前」等价于 system 之前，「char 之后」等价于 system 之后。
  static LorebookEntryPosition _positionFromCharacterBook(String? raw) {
    switch (raw) {
      case 'before_char':
      case 'before_scenario':
        return LorebookEntryPosition.beforeSystem;
      case 'after_char':
        return LorebookEntryPosition.afterSystem;
      case 'before_example':
        return LorebookEntryPosition.beforeUser;
      case 'after_example':
        return LorebookEntryPosition.afterUser;
      default:
        return LorebookEntryPosition.afterSystem;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'keys': keys,
        'secondaryKeys': secondaryKeys,
        'content': content,
        'matchStrategy': matchStrategy.name,
        'position': position.name,
        'format': format.name,
        'enabled': enabled,
        'order': order,
        'caseSensitive': caseSensitive,
        'tokenBudget': tokenBudget,
        'comment': comment,
        'priority': priority,
        'probability': probability,
        'selective': selective,
        'constant': constant,
        'depth': depth,
        'extensions': extensions,
      };

  factory LorebookEntry.fromJson(Map<String, dynamic> json) => LorebookEntry(
        id: json['id'],
        key: json['key'] ?? '',
        keys: List<String>.from(json['keys'] ?? []),
        secondaryKeys: List<String>.from(json['secondaryKeys'] ?? []),
        content: json['content'] ?? '',
        matchStrategy: LorebookEntryMatchStrategy.values.firstWhere(
          (e) => e.name == json['matchStrategy'],
          orElse: () => LorebookEntryMatchStrategy.partial,
        ),
        position: LorebookEntryPosition.values.firstWhere(
          (e) => e.name == json['position'],
          orElse: () => LorebookEntryPosition.bottom,
        ),
        format: LorebookEntryFormat.values.firstWhere(
          (e) => e.name == json['format'],
          orElse: () => LorebookEntryFormat.plainText,
        ),
        enabled: json['enabled'] ?? true,
        order: json['order'] ?? 0,
        caseSensitive: json['caseSensitive'] ?? false,
        tokenBudget: json['tokenBudget'],
        comment: json['comment'],
        priority: _asInt(json['priority']) ?? 10,
        probability: _asInt(json['probability']) ?? 100,
        selective: json['selective'] ?? false,
        constant: json['constant'] ?? false,
        depth: _asInt(json['depth']) ?? 4,
        extensions: Map<String, dynamic>.from(json['extensions'] ?? {}),
      );
}

/// App 注入位置 → CCv3 position 反向映射
extension LorebookEntryPositionX on LorebookEntryPosition {
  String toCharacterBook() {
    switch (this) {
      case LorebookEntryPosition.beforeSystem:
        return 'before_char';
      case LorebookEntryPosition.afterSystem:
        return 'after_char';
      case LorebookEntryPosition.beforeUser:
        return 'before_example';
      case LorebookEntryPosition.afterUser:
        return 'after_example';
      case LorebookEntryPosition.beforeAssistant:
      case LorebookEntryPosition.afterAssistant:
      case LorebookEntryPosition.top:
      case LorebookEntryPosition.bottom:
        return 'after_char';
    }
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

List<String> _asStringList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

String _nowId() => DateTime.now().microsecondsSinceEpoch.toString();

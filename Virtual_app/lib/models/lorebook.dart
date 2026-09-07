
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
class Lorebook {
  final String id;
  final String name;
  final String description;
  final List<LorebookEntry> entries;
  final bool enabled;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lorebook({
    required this.id,
    required this.name,
    this.description = '',
    this.entries = const [],
    this.enabled = true,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'entries': entries.map((e) => e.toJson()).toList(),
        'enabled': enabled,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
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
      );
}

/// Lorebook 条目
class LorebookEntry {
  final String id;
  final String key; // 触发关键词
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

  LorebookEntry({
    required this.id,
    required this.key,
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
  });

  LorebookEntry copyWith({
    String? id,
    String? key,
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
  }) {
    return LorebookEntry(
      id: id ?? this.id,
      key: key ?? this.key,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
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
      };

  factory LorebookEntry.fromJson(Map<String, dynamic> json) => LorebookEntry(
        id: json['id'],
        key: json['key'] ?? '',
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
      );
}

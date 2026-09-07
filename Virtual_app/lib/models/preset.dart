
/// 预设条目类型
enum PresetEntryType {
  systemPrompt,
  jailbreak,
  userMessage,
  assistantMessage,
  tool,
  custom,
}

/// 预设条目角色
enum PresetEntryRole {
  system,
  user,
  assistant,
  tool,
}

/// 预设条目位置
enum PresetEntryPosition {
  beforeSystem,
  afterSystem,
  beforeFirstUser,
  beforeLastUser,
  afterLastUser,
  beforeAssistant,
  afterAssistant,
  top,
  bottom,
}

/// 预设
class Preset {
  final String id;
  final String name;
  final String description;
  final List<PresetEntry> entries;
  final bool isBuiltIn;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Preset({
    required this.id,
    required this.name,
    this.description = '',
    this.entries = const [],
    this.isBuiltIn = false,
    this.isActive = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Preset copyWith({
    String? id,
    String? name,
    String? description,
    List<PresetEntry>? entries,
    bool? isBuiltIn,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Preset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      entries: entries ?? this.entries,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'entries': entries.map((e) => e.toJson()).toList(),
        'isBuiltIn': isBuiltIn,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        entries: (json['entries'] as List?)
                ?.map((e) => PresetEntry.fromJson(e))
                .toList() ??
            [],
        isBuiltIn: json['isBuiltIn'] ?? false,
        isActive: json['isActive'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

/// 预设条目
class PresetEntry {
  final String id;
  final String label;
  final PresetEntryType type;
  final PresetEntryRole role;
  final PresetEntryPosition position;
  final String content;
  final bool enabled;
  final int order;
  final bool insertOnce;
  final String? condition;

  PresetEntry({
    required this.id,
    required this.label,
    required this.type,
    required this.role,
    required this.position,
    required this.content,
    this.enabled = true,
    this.order = 0,
    this.insertOnce = false,
    this.condition,
  });

  PresetEntry copyWith({
    String? id,
    String? label,
    PresetEntryType? type,
    PresetEntryRole? role,
    PresetEntryPosition? position,
    String? content,
    bool? enabled,
    int? order,
    bool? insertOnce,
    String? condition,
  }) {
    return PresetEntry(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      role: role ?? this.role,
      position: position ?? this.position,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      insertOnce: insertOnce ?? this.insertOnce,
      condition: condition ?? this.condition,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'role': role.name,
        'position': position.name,
        'content': content,
        'enabled': enabled,
        'order': order,
        'insertOnce': insertOnce,
        'condition': condition,
      };

  factory PresetEntry.fromJson(Map<String, dynamic> json) => PresetEntry(
        id: json['id'],
        label: json['label'] ?? '',
        type: PresetEntryType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PresetEntryType.custom,
        ),
        role: PresetEntryRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => PresetEntryRole.system,
        ),
        position: PresetEntryPosition.values.firstWhere(
          (e) => e.name == json['position'],
          orElse: () => PresetEntryPosition.bottom,
        ),
        content: json['content'] ?? '',
        enabled: json['enabled'] ?? true,
        order: json['order'] ?? 0,
        insertOnce: json['insertOnce'] ?? false,
        condition: json['condition'],
      );
}

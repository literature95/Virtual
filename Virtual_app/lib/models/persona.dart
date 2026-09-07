
/// Persona 模型（用户人设）
class Persona {
  final String id;
  final String name;
  final String description;
  final String? personality;
  final String? avatarPath;
  final bool isActive;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  Persona({
    required this.id,
    required this.name,
    this.description = '',
    this.personality,
    this.avatarPath,
    this.isActive = false,
    this.isBuiltIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Persona copyWith({
    String? id,
    String? name,
    String? description,
    String? personality,
    String? avatarPath,
    bool? isActive,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Persona(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      personality: personality ?? this.personality,
      avatarPath: avatarPath ?? this.avatarPath,
      isActive: isActive ?? this.isActive,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'personality': personality,
        'avatarPath': avatarPath,
        'isActive': isActive,
        'isBuiltIn': isBuiltIn,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        personality: json['personality'],
        avatarPath: json['avatarPath'],
        isActive: json['isActive'] ?? false,
        isBuiltIn: json['isBuiltIn'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

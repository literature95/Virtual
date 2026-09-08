/// 角色模型
///
/// 对应原应用 Character 实体（ObjectBox）。
/// 逆向证据：pp.txt Eec 对象 [pp+0x3760] ~ [pp+0x38f0] 范围内的属性定义。
/// 已确认字段：name, personality, scenario, firstMes, mesExample, avatar,
/// description, creatorNotes, pinned, updateAt, systemPrompt,
/// postHistoryInstructions, alternateGreetings, tags, creator, characterVersion,
/// dbExtensions, nickname, source, groupOnlyGreetings, creationDate,
/// modificationDate, dbCreatorNotesMultilingual。
class Character {
  final String id;
  final String name;
  final String? nickname; // 证据：pp.txt [pp+0x3898] String: "nickname"
  final String? description;
  final String? personality;
  final String? scenario;
  final String? firstMessage; // 对应 firstMes
  final String? avatarPath; // 对应 avatar

  // === 样式设置 ===
  final CharacterAvatarStyle avatarStyle;
  final CharacterBubbleStyle bubbleStyle;
  final CharacterBubbleFontStyle bubbleFontStyle;

  // === 内容字段 ===
  final String? creatorNotes; // 证据：pp.txt [pp+0x37f8]
  final String? systemPrompt; // 证据：pp.txt [pp+0x3828]
  final String? postHistoryInstructions; // 证据：pp.txt [pp+0x3838]
  final List<String> tags; // 证据：pp+0x3858
  final List<String> alternateGreetings; // 证据：pp+0x3848
  final List<CharacterExampleMessage> exampleMessages; // 对应 mesExample

  /// 群聊专属问候语
  /// 证据：pp.txt [pp+0x38b8] String: "groupOnlyGreetings"
  final List<String> groupOnlyGreetings;

  // === 元数据 ===
  final String? creator; // 证据：pp+0x3868
  final String? characterVersion; // 证据：pp+0x3878
  final String? source; // 证据：pp+0x38a8] (导入来源标识)

  /// 扩展数据（JSON 格式，存储自定义扩展字段）
  /// 证据：pp.txt [pp+0x3888] String: "dbExtensions"
  final Map<String, dynamic> extensions;

  /// 多语言创作者备注（JSON 格式，key=语言代码）
  /// 证据：pp.txt [pp+0x38f0] String: "dbCreatorNotesMultilingual"
  final Map<String, String> creatorNotesMultilingual;

  // === 关联 ===
  final String? lorebookId;
  final String? personaId;

  // === 状态 ===
  final bool isPinned; // 证据：pp+0x3808 String: "pinned"
  final bool isFavorite;
  final int usageCount;

  // === 时间 ===
  final DateTime createdAt; // 对应 creationDate
  final DateTime updatedAt; // 对应 updateAt / modificationDate

  Character({
    required this.id,
    required this.name,
    this.nickname,
    this.description,
    this.personality,
    this.scenario,
    this.firstMessage,
    this.avatarPath,
    this.avatarStyle = CharacterAvatarStyle.circle,
    this.bubbleStyle = CharacterBubbleStyle.standard,
    this.bubbleFontStyle = CharacterBubbleFontStyle.normal,
    this.creatorNotes,
    this.systemPrompt,
    this.postHistoryInstructions,
    this.tags = const [],
    this.alternateGreetings = const [],
    this.exampleMessages = const [],
    this.groupOnlyGreetings = const [],
    this.creator,
    this.characterVersion,
    this.source,
    this.extensions = const {},
    this.creatorNotesMultilingual = const {},
    this.lorebookId,
    this.personaId,
    this.isPinned = false,
    this.isFavorite = false,
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Character copyWith({
    String? id,
    String? name,
    String? nickname,
    String? description,
    String? personality,
    String? scenario,
    String? firstMessage,
    String? avatarPath,
    CharacterAvatarStyle? avatarStyle,
    CharacterBubbleStyle? bubbleStyle,
    CharacterBubbleFontStyle? bubbleFontStyle,
    String? creatorNotes,
    String? systemPrompt,
    String? postHistoryInstructions,
    List<String>? tags,
    List<String>? alternateGreetings,
    List<CharacterExampleMessage>? exampleMessages,
    List<String>? groupOnlyGreetings,
    String? creator,
    String? characterVersion,
    String? source,
    Map<String, dynamic>? extensions,
    Map<String, String>? creatorNotesMultilingual,
    String? lorebookId,
    String? personaId,
    bool? isPinned,
    bool? isFavorite,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      description: description ?? this.description,
      personality: personality ?? this.personality,
      scenario: scenario ?? this.scenario,
      firstMessage: firstMessage ?? this.firstMessage,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      bubbleStyle: bubbleStyle ?? this.bubbleStyle,
      bubbleFontStyle: bubbleFontStyle ?? this.bubbleFontStyle,
      creatorNotes: creatorNotes ?? this.creatorNotes,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      postHistoryInstructions:
          postHistoryInstructions ?? this.postHistoryInstructions,
      tags: tags ?? this.tags,
      alternateGreetings: alternateGreetings ?? this.alternateGreetings,
      exampleMessages: exampleMessages ?? this.exampleMessages,
      groupOnlyGreetings: groupOnlyGreetings ?? this.groupOnlyGreetings,
      creator: creator ?? this.creator,
      characterVersion: characterVersion ?? this.characterVersion,
      source: source ?? this.source,
      extensions: extensions ?? this.extensions,
      creatorNotesMultilingual:
          creatorNotesMultilingual ?? this.creatorNotesMultilingual,
      lorebookId: lorebookId ?? this.lorebookId,
      personaId: personaId ?? this.personaId,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nickname': nickname,
        'description': description,
        'personality': personality,
        'scenario': scenario,
        'firstMessage': firstMessage,
        'avatarPath': avatarPath,
        'avatarStyle': avatarStyle.name,
        'bubbleStyle': bubbleStyle.name,
        'bubbleFontStyle': bubbleFontStyle.name,
        'creatorNotes': creatorNotes,
        'systemPrompt': systemPrompt,
        'postHistoryInstructions': postHistoryInstructions,
        'tags': tags,
        'alternateGreetings': alternateGreetings,
        'exampleMessages': exampleMessages.map((e) => e.toJson()).toList(),
        'groupOnlyGreetings': groupOnlyGreetings,
        'creator': creator,
        'characterVersion': characterVersion,
        'source': source,
        'extensions': extensions,
        'creatorNotesMultilingual': creatorNotesMultilingual,
        'lorebookId': lorebookId,
        'personaId': personaId,
        'isPinned': isPinned,
        'isFavorite': isFavorite,
        'usageCount': usageCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        id: json['id'],
        name: json['name'] ?? '',
        nickname: json['nickname'],
        description: json['description'],
        personality: json['personality'],
        scenario: json['scenario'],
        firstMessage: json['firstMessage'] ?? json['firstMes'],
        avatarPath: json['avatarPath'] ?? json['avatar'],
        avatarStyle: CharacterAvatarStyle.values.firstWhere(
          (e) => e.name == json['avatarStyle'],
          orElse: () => CharacterAvatarStyle.circle,
        ),
        bubbleStyle: CharacterBubbleStyle.values.firstWhere(
          (e) => e.name == json['bubbleStyle'],
          orElse: () => CharacterBubbleStyle.standard,
        ),
        bubbleFontStyle: CharacterBubbleFontStyle.values.firstWhere(
          (e) => e.name == json['bubbleFontStyle'],
          orElse: () => CharacterBubbleFontStyle.normal,
        ),
        creatorNotes: json['creatorNotes'],
        systemPrompt: json['systemPrompt'],
        postHistoryInstructions: json['postHistoryInstructions'],
        tags: List<String>.from(json['tags'] ?? []),
        alternateGreetings:
            List<String>.from(json['alternateGreetings'] ?? []),
        exampleMessages: (json['exampleMessages'] as List?)
                ?.map((e) => CharacterExampleMessage.fromJson(e))
                .toList() ??
            // 兼容 mesExample 字段（CCv3 格式）
            parseMesExample(json['mesExample']),
        groupOnlyGreetings:
            List<String>.from(json['groupOnlyGreetings'] ?? []),
        creator: json['creator'],
        characterVersion: json['characterVersion'],
        source: json['source'],
        extensions: Map<String, dynamic>.from(json['extensions'] ?? {}),
        creatorNotesMultilingual: Map<String, String>.from(
            json['creatorNotesMultilingual'] ?? {}),
        lorebookId: json['lorebookId'],
        personaId: json['personaId'],
        isPinned: json['isPinned'] ?? json['pinned'] ?? false,
        isFavorite: json['isFavorite'] ?? false,
        usageCount: json['usageCount'] ?? 0,
        createdAt: DateTime.parse(json['createdAt'] ?? json['creationDate'] ??
            DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(json['updatedAt'] ??
            json['modificationDate'] ??
            json['updateAt'] ??
            DateTime.now().toIso8601String()),
      );

  /// 解析 mesExample 格式（CCv3 风格，<START> 分隔）
  ///
  /// 支持两种输入：字符串（`<START>` 分隔的 `{{char}}`/`{{user}}` 对话）与
  /// List（`CharacterExampleMessage` JSON）。导入服务也复用此解析。
  static List<CharacterExampleMessage> parseMesExample(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => CharacterExampleMessage.fromJson(e))
          .toList();
    }
    if (raw is String) {
      // CCv2/v3 格式：<START> 分隔的示例对话
      final parts = raw.split('<START>');
      return parts.where((p) => p.trim().isNotEmpty).map((p) {
        // 简单解析：尝试从 {{char}}: 和 {{user}}: 行分离
        final lines = p.trim().split('\n');
        String userMsg = '';
        String charMsg = '';
        bool inUser = false;
        bool inChar = false;
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('{{user}}:') || trimmed.startsWith('User:')) {
            inUser = true;
            inChar = false;
            userMsg += '${trimmed.substring(trimmed.indexOf(':') + 1).trim()}\n';
          } else if (trimmed.startsWith('{{char}}:') ||
              trimmed.startsWith('Assistant:')) {
            inUser = false;
            inChar = true;
            charMsg += '${trimmed.substring(trimmed.indexOf(':') + 1).trim()}\n';
          } else if (inUser) {
            userMsg += '$trimmed\n';
          } else if (inChar) {
            charMsg += '$trimmed\n';
          }
        }
        return CharacterExampleMessage(
          userMessage: userMsg.trim(),
          assistantMessage: charMsg.trim(),
        );
      }).toList();
    }
    return [];
  }
}

/// 角色头像样式
enum CharacterAvatarStyle {
  circle,
  square,
  rounded,
  none,
}

/// 角色气泡样式
enum CharacterBubbleStyle {
  standard,
  flat,
  minimal,
  custom,
}

/// 角色气泡字体样式
enum CharacterBubbleFontStyle {
  normal,
  serif,
  mono,
  cursive,
}

/// 群聊角色头像样式
enum GroupCharacterAvatarStyle {
  stacked,
  sideBySide,
  carousel,
  hidden,
}

/// 示例消息
class CharacterExampleMessage {
  final String userMessage;
  final String assistantMessage;
  final String? note;

  CharacterExampleMessage({
    required this.userMessage,
    required this.assistantMessage,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'userMessage': userMessage,
        'assistantMessage': assistantMessage,
        'note': note,
      };

  factory CharacterExampleMessage.fromJson(Map<String, dynamic> json) =>
      CharacterExampleMessage(
        userMessage: json['userMessage'] ?? '',
        assistantMessage: json['assistantMessage'] ?? '',
        note: json['note'],
      );
}

/// 角色删除类型
enum CharacterDeleteCandidateKind {
  single,
  all,
  selected,
}

/// 角色删除提交状态
enum CharacterDeleteCommitStatus {
  pending,
  confirming,
  deleting,
  success,
  failed,
}

/// 角色导入提交状态
enum CharacterImportCommitStatus {
  pending,
  analyzing,
  importing,
  success,
  failed,
  conflict,
}

/// 角色导入组件类型
enum CharacterImportComponentKind {
  character,
  lorebook,
  preset,
  regex,
}

/// 角色导入冲突操作
enum CharacterImportConflictAction {
  skip,
  overwrite,
  rename,
  merge,
}

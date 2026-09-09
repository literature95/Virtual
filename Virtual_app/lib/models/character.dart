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

  /// 导入来源 ID（后端角色卡 ID / 卡包内 ID），存于 `extensions['sourceId']`。
  ///
  /// 本地角色 id 由 uuid 生成，与来源 ID 天然不同域，因此来源 ID 必须单独留存，
  /// 否则一键导入无法查重——同一个在线角色点 5 次会堆出 5 个同名副本。
  String? get sourceId => extensions['sourceId'] as String?;

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

  factory Character.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? '';
    return Character(
      id: json['id'],
      name: name,
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
            parseMesExample(json['mesExample'], charName: name),
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
  }

  /// 解析 mesExample（示例对话）
  ///
  /// CCv2 / CCv3 规范只规定「`<START>` 分隔的多轮示例」，没有规定行内前缀写法。
  /// 现实中至少存在三种写法，本解析器全部支持（旧实现仅支持第 1 种，会静默丢弃
  /// 其余写法，是角色「语气漂移 / OOC」的主要来源）：
  ///
  /// 1. 宏前缀：`{{user}}: ...` / `{{char}}: ...`
  /// 2. 固定名前缀：`User: ...` / `Assistant: ...`
  /// 3. **任意角色名前缀**（chub.ai / SillyTavern 常见）：
  ///    `Handsome Dragonborn: ...` / `Cricket: ...` / `Potential Client: ...`
  ///
  /// 归属判定规则（`[charName]` 为角色名，大小写/首尾空格不敏感）：
  /// - 说话人 == charName，或属于 assistant 别名集合 → assistant 侧
  /// - `{{user}}` / `user` / `human` 等用户别名，或**任何未知的第三方名字** → user 侧
  /// - 无前缀的行 / 行首有缩进的行 → 续写，归并到上一位说话人（保留原始换行）
  /// - 纯序号行（`1.` / `2)` / `1、`）直接跳过
  ///
  /// 一个 `<START>` 块 = 一条 [CharacterExampleMessage]；块内多轮按说话人分别
  /// 拼接（模型本身只有 user/assistant 两栏，这是格式本身的限制，非本项目缺陷）。
  static List<CharacterExampleMessage> parseMesExample(
    dynamic raw, {
    String? charName,
  }) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) {
        if (e is Map) return CharacterExampleMessage.fromJson(Map.from(e));
        // 兼容纯字符串数组：整条视作角色台词
        return CharacterExampleMessage(
          userMessage: '',
          assistantMessage: e.toString(),
        );
      }).toList();
    }
    if (raw is! String) return [];

    final result = <CharacterExampleMessage>[];
    for (final block in raw.split('<START>')) {
      if (block.trim().isEmpty) continue;

      final userTurns = <String>[];
      final charTurns = <String>[];
      var isAssistantTurn = false;
      final buffer = StringBuffer();

      void flush() {
        final text = buffer.toString().trim();
        buffer.clear();
        if (text.isEmpty) return;
        (isAssistantTurn ? charTurns : userTurns).add(text);
      }

      /// 结束当前示例并入列（附带为此 card 生成一条记录）
      void emit() {
        flush();
        if (userTurns.isEmpty && charTurns.isEmpty) return;
        result.add(CharacterExampleMessage(
          userMessage: userTurns.join('\n\n').trim(),
          assistantMessage: charTurns.join('\n\n').trim(),
        ));
        userTurns.clear();
        charTurns.clear();
      }

      for (final rawLine in block.split('\n')) {
        // 保留续写的原始缩进判定：有缩进即视为同一句换行
        final trimmed = rawLine.trim();
        final speaker = _matchExampleSpeaker(rawLine, charName);

        if (trimmed.isEmpty) {
          buffer.writeln();
          continue;
        }
        if (_isNumberingLine(trimmed)) {
          // 部分作者不使用 <START>，仅用 `1.` `2.` 分隔示例（如 chub.ai 导出）
          emit();
          continue;
        }

        if (speaker != null) {
          flush();
          isAssistantTurn = speaker.isAssistant;
          final content = speaker.content;
          if (content.isNotEmpty) {
            buffer.writeln(content);
          }
        } else {
          // 续写行：保留前导空白以外的原文
          buffer.writeln(trimmed.isEmpty ? '' : trimmed);
        }
      }
      emit();
    }
    return result;
  }

  /// 判断一行是否只是示例序号（如 `1.` / `2)` / `1、` / `- `）
  static bool _isNumberingLine(String trimmed) =>
      RegExp(r'^\d+\s*[.、)）:：]*$').hasMatch(trimmed);

  /// 尝试从一行中解析出「说话人 + 内容」。
  ///
  /// 返回 null 表示该行不是新的说话轮（即续写行）。
  static _ExampleSpeaker? _matchExampleSpeaker(String line, String? charName) {
    // 续写判定：行首缩进，或无 `Name:` 结构
    if (line.trimLeft() != line) return null;
    const maxSpeakerLen = 32;
    final idx = line.indexOf(':');
    if (idx <= 0 || idx > maxSpeakerLen) return null;

    final speakerRaw = line.substring(0, idx).trim();
    final content = line.substring(idx + 1).trimLeft();
    if (speakerRaw.isEmpty) return null;
    // 说话人不应含句号/星号等叙述符号，避免把 `*Cricket thinks: maybe` 误判
    if (RegExp(r'[*{}<>\n]').hasMatch(speakerRaw)) {
      // `{{char}}` / `{{user}}` 是合法例外
      if (!RegExp(r'^\{\{?\s*(char|user|Char|User|persona)\s*\}?\}$')
          .hasMatch(speakerRaw)) {
        return null;
      }
    }

    final key = speakerRaw.toLowerCase().replaceAll(RegExp(r'[{}\s]'), '');
    const assistantAliases = {
      'char',
      'assistant',
      'ai',
      'bot',
      'model',
      'system',
      'charname',
      '角色',
      'ai助手',
    };
    const userAliases = {'user', 'you', 'human', 'player', '用户', '我'};

    bool? explicitRole;
    if (assistantAliases.contains(key)) explicitRole = true;
    if (userAliases.contains(key)) explicitRole = false;

    final nameMatchesChar = charName != null &&
        charName.trim().isNotEmpty &&
        _normalize(speakerRaw) == _normalize(charName);

    return _ExampleSpeaker(
      isAssistant: explicitRole ?? nameMatchesChar,
      content: content,
    );
  }

  static String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// 示例对话中的一次「说话人切换」判定结果
class _ExampleSpeaker {
  final bool isAssistant;
  final String content;

  const _ExampleSpeaker({required this.isAssistant, required this.content});
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

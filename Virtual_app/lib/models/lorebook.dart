
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

  /// 从 SillyTavern World Info（世界书）JSON 构建
  ///
  /// 与 CCv3 `character_book` 的差异（对磁盘上 231 个真实世界书实测得出）：
  ///
  /// | 维度 | `character_book` | SillyTavern World Info |
  /// | --- | --- | --- |
  /// | `entries` | **数组** `[{…}]` | **对象** `{"0":{…},"1":{…}}` |
  /// | 启用开关 | `enabled` | `disable`（**语义相反**） |
  /// | 关键词 | `keys` / `secondary_keys` | `key` / `keysecondary` |
  /// | 位置 | 字符串 `before_char` | **整数** `0..4` |
  /// | 名称 | 必有 `name` | 221 个样本中仅 7 个有 |
  ///
  /// 若拿 `entries` 当数组解析，这 221 个文件会**静默得到 0 条目**——
  /// 世界书看起来"导入成功"却完全没有内容。
  ///
  /// [fallbackName] 用于顶层缺少 `name` 时补默认名（调用方传文件名）。
  factory Lorebook.fromWorldInfo(
    Map<String, dynamic> json, {
    String? fallbackName,
  }) {
    final now = DateTime.now();
    final raw = json['entries'];
    final entries = <LorebookEntry>[];
    if (raw is Map) {
      // JSON 对象的键序被 Dart 的 Map 保留，因此条目顺序与文件一致
      for (final value in raw.values) {
        if (value is Map) {
          entries.add(
            LorebookEntry.fromWorldInfo(Map<String, dynamic>.from(value)),
          );
        }
      }
    }

    // 顶层未知键保留进 extensions，避免导入→导出丢字段。
    // `originalData` 是 entries 的冗余副本（59 个样本里体积可观），显式跳过。
    final exts = Map<String, dynamic>.from(
      json['extensions'] ?? <String, dynamic>{},
    );
    const known = {
      'entries',
      'originalData',
      'name',
      'description',
      'scan_depth',
      'token_budget',
      'recursive_scanning',
      'extensions',
    };
    for (final e in json.entries) {
      if (!known.contains(e.key)) exts.putIfAbsent(e.key, () => e.value);
    }

    final name = json['name']?.toString();
    return Lorebook(
      id: _nowId(),
      name: (name == null || name.isEmpty)
          ? (fallbackName ?? 'World Book')
          : name,
      description: json['description']?.toString() ?? '',
      entries: entries,
      enabled: true,
      order: 0,
      createdAt: now,
      updatedAt: now,
      scanDepth: _asInt(json['scan_depth']) ?? 0,
      tokenBudget: _asInt(json['token_budget']) ?? 0,
      recursiveScanning: json['recursive_scanning'] == true,
      extensions: exts,
    );
  }

  /// 回写为 SillyTavern World Info（世界书）JSON —— 导出默认形态
  ///
  /// `entries` 用**对象**形态：这是 SillyTavern 真正读写的形式，
  /// 数组形态只有 CCv3 的 `character_book` 才用。导出为对象形态才能被
  /// SillyTavern / 其他前端直接吃下。
  Map<String, dynamic> toWorldInfo() {
    final outEntries = <String, dynamic>{};
    for (var i = 0; i < entries.length; i++) {
      outEntries['$i'] = entries[i].toWorldInfo(index: i);
    }
    return {
      'name': name,
      'description': description,
      'scan_depth': scanDepth,
      'token_budget': tokenBudget,
      'recursive_scanning': recursiveScanning,
      'extensions': extensions,
      'entries': outEntries,
    };
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

  /// 从 SillyTavern World Info 的 `entries[<key>]` 条目构建
  ///
  /// 字段映射（SillyTavern → 本模型）：
  ///
  /// - `key` / `keysecondary` → [keys] / [secondaryKeys]
  ///   （真实语料 5975 条中 `key` **全部**是数组，仍兼容字符串写法）
  /// - `disable` → [enabled] 取反（**最容易写错的一处**：`disable: true`
  ///   在 SillyTavern 里表示"这条不生效"，直接赋给 `enabled` 会把全部
  ///   条目反转成启用状态）
  /// - `position` 整数 → [position]：`0` char 前 · `1` char 后 · `2` AN 前 ·
  ///   `3` AN 后 · `4` 按深度（本模型的注入管线不支持深度，落到"用户消息之前"，
  ///   原始深度值保留在 `extensions.depth`）
  /// - `selective` + `selectiveLogic` → [selective]：只有 `3`（AND_ALL，
  ///   次要关键词需全部命中）与本模型的布尔语义等价；`0`（AND_ANY）等价于
  ///   `selective == false`；`1`/`2` 是取反逻辑，本模型无法表达，降级处理
  /// - `useProbability == false` → [probability] 归 100
  /// - `useRegex == true` → [matchStrategy] 置 regex
  /// - 其余 SillyTavern 专有字段（`group` / `scanDepth` / `matchWholeWords` /
  ///   `sticky` / `cooldown` …）原样进 [extensions]，保证往返不丢
  factory LorebookEntry.fromWorldInfo(Map<String, dynamic> e) {
    // 少数转换工具会把两套字段同时写进一个条目；此时以 SillyTavern 字段为准，
    // 因为它是真实语料中的实际形态。
    final rawKeys = _readStringOrList(e['key']);
    final keys = rawKeys.isNotEmpty ? rawKeys : _readStringOrList(e['keys']);
    final rawSecondary = _readStringOrList(e['keysecondary']);
    final secondary = rawSecondary.isNotEmpty
        ? rawSecondary
        : _readStringOrList(e['secondary_keys']);

    final exts = Map<String, dynamic>.from(e['extensions'] ?? {});
    // 保留 SillyTavern 专有字段，导出时原样写回
    const passthrough = {
      'uid',
      'addMemo',
      'displayIndex',
      'excludeRecursion',
      'useProbability',
      'selectiveLogic',
      'matchWholeWords',
      'group',
      'groupOverride',
      'groupWeight',
      'scanDepth',
      'automationId',
      'role',
      'vectorized',
      'sticky',
      'cooldown',
      'delay',
      'delayUntilRecursion',
      'disable',
    };
    for (final k in passthrough) {
      if (e.containsKey(k)) exts.putIfAbsent(k, () => e[k]);
    }

    final selective = e['selective'] == true;
    final logic = _asInt(e['selectiveLogic']);
    final useProbability = e['useProbability'] != false;
    final rawPosition = e['position'];
    final position = rawPosition is String
        ? _positionFromCharacterBook(rawPosition)
        : _positionFromWorldInfo(_asInt(rawPosition));

    return LorebookEntry(
      id: _nowId(),
      key: keys.isNotEmpty ? keys.first : '',
      keys: keys,
      // SillyTavern 的 `selective: false` 表示"次要关键词不参与匹配"，
      // 等价于把次要关键词清空；否则它们会被当成额外的触发条件。
      secondaryKeys: selective ? secondary : const [],
      content: e['content']?.toString() ?? '',
      matchStrategy: e['useRegex'] == true
          ? LorebookEntryMatchStrategy.regex
          : LorebookEntryMatchStrategy.partial,
      position: position,
      format: LorebookEntryFormat.plainText,
      enabled: e.containsKey('disable')
          ? e['disable'] != true
          : (e['enabled'] ?? true),
      order: _asInt(e['order']) ?? _asInt(e['insertion_order']) ?? 0,
      caseSensitive: e['caseSensitive'] == true || e['case_sensitive'] == true,
      tokenBudget: _asInt(e['token_budget']),
      comment: e['comment']?.toString() ?? e['name']?.toString() ?? '',
      priority: _asInt(e['priority']) ?? 10,
      probability: useProbability ? (_asInt(e['probability']) ?? 100) : 100,
      selective: selective && logic == 3,
      constant: e['constant'] == true,
      depth: _asInt(e['depth']) ?? 4,
      extensions: exts,
    );
  }

  /// 回写为 SillyTavern World Info 的单个条目
  ///
  /// 先铺开 [extensions] 中的 SillyTavern 专有字段（`group` / `scanDepth` /
  /// `matchWholeWords` …），再用本模型的权威字段覆盖，从而在用户编辑后
  /// 仍保留未建模的原始信息。
  Map<String, dynamic> toWorldInfo({int index = 0}) => {
        ...extensions,
        'uid': index,
        'key': matchKeys,
        'keysecondary': secondaryKeys,
        'comment': comment ?? '',
        'content': content,
        'constant': constant,
        'selective': secondaryKeys.isNotEmpty,
        'selectiveLogic': selective ? 3 : 0,
        'order': order,
        'position': position.toWorldInfo(),
        // 与导入时的 `disable` 反语义严格对称
        'disable': !enabled,
        'probability': probability,
        'useProbability': true,
        'depth': depth,
        'displayIndex': index,
        'addMemo': extensions['addMemo'] == true,
        'excludeRecursion': extensions['excludeRecursion'] == true,
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

  /// SillyTavern 整数 position → App 注入位置映射
  ///
  /// SillyTavern 的 `world_info_position` 常量：
  /// `0`=before_char · `1`=after_char · `2`=before_AN · `3`=after_AN ·
  /// `4`=at_depth（配合 `depth` 字段插到聊天靠后的位置）。
  ///
  /// 本模型的注入管线以 system 为核心并支持 before/after user，因此
  /// AN（Author's Note）与 at_depth 都归到「用户消息之前/之后」——
  /// 它们的作用位置都在对话尾部。真实语料分布：`1` 2461 · `0` 2158 ·
  /// `3` 933 · `2` 311 · `4` 112，全部落在这条映射内。
  static LorebookEntryPosition _positionFromWorldInfo(int? raw) {
    switch (raw) {
      case 0:
        return LorebookEntryPosition.beforeSystem;
      case 1:
        return LorebookEntryPosition.afterSystem;
      case 2:
        return LorebookEntryPosition.beforeUser; // before_AN
      case 3:
        return LorebookEntryPosition.afterUser; // after_AN
      case 4:
        return LorebookEntryPosition.beforeUser; // at_depth（管线不支持深度）
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

/// App 注入位置 → SillyTavern 整数 position 反向映射
///
/// 与 [LorebookEntryPositionX.toCharacterBook] 分列两个扩展名，避免
/// 同名方法在不同返回类型上冲突。
extension LorebookEntryPositionWorldInfoX on LorebookEntryPosition {
  int toWorldInfo() {
    switch (this) {
      case LorebookEntryPosition.beforeSystem:
        return 0; // before_char
      case LorebookEntryPosition.afterSystem:
        return 1; // after_char
      case LorebookEntryPosition.beforeUser:
        return 2; // before_AN
      case LorebookEntryPosition.afterUser:
        return 3; // after_AN
      case LorebookEntryPosition.beforeAssistant:
      case LorebookEntryPosition.afterAssistant:
      case LorebookEntryPosition.top:
      case LorebookEntryPosition.bottom:
        return 1; // after_char —— SillyTavern 无对应位置，归入 char 之后
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

/// 读取「字符串或字符串数组」字段
///
/// SillyTavern 的 `key` / `keysecondary` 规范上是数组，但历史上允许单个
/// 字符串；`_asStringList` 遇到字符串会返回空表，等于静默丢掉触发词。
List<String> _readStringOrList(dynamic v) {
  if (v is String) return v.isEmpty ? const [] : [v];
  return _asStringList(v);
}

/// 进程内单调递增序号
///
/// `microsecondsSinceEpoch` 在快速循环里可能取到相同的值（一次解析可能连续
/// 构造数千个条目），只靠时间戳会生成重复 id。附上序号确保唯一。
int _idSeq = 0;

String _nowId() => '${DateTime.now().microsecondsSinceEpoch}-${_idSeq++}';

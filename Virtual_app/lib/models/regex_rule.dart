
/// 正则条目时机
enum RegexEntryTiming {
  send, // 发送时
  receive, // 接收时
  display, // 显示时
  sendDisplay, // 发送时显示
  receiveDisplay, // 接收时显示
}

/// 正则条目替换位置
enum RegexEntryPlacement {
  all,
  first,
  last,
  exact,
}

/// 正则条目替换策略
enum RegexEntrySubstitution {
  replaceAll,
  replaceFirst,
  append,
  prepend,
  remove,
}

/// 正则引用对话
class RegexConversationRef {
  final String regexId;
  final String conversationId;
  final bool enabled;

  RegexConversationRef({
    required this.regexId,
    required this.conversationId,
    this.enabled = true,
  });
}

/// 正则规则
class RegexRule {
  final String id;
  final String name;
  final String pattern;
  final String replacement;
  final RegexEntryTiming timing;
  final RegexEntryPlacement placement;
  final RegexEntrySubstitution substitution;
  final bool enabled;
  final int order;
  final bool caseSensitive;
  final bool multiline;
  final bool dotAll;
  final String? description;

  RegexRule({
    required this.id,
    required this.name,
    required this.pattern,
    required this.replacement,
    this.timing = RegexEntryTiming.receive,
    this.placement = RegexEntryPlacement.all,
    this.substitution = RegexEntrySubstitution.replaceAll,
    this.enabled = true,
    this.order = 0,
    this.caseSensitive = false,
    this.multiline = false,
    this.dotAll = false,
    this.description,
  });

  String apply(String input) {
    if (!enabled) return input;
    if (pattern.isEmpty) return input;

    try {
      final regex = RegExp(
        pattern,
        caseSensitive: caseSensitive,
        multiLine: multiline,
        dotAll: dotAll,
      );

      switch (substitution) {
        case RegexEntrySubstitution.replaceAll:
          return input.replaceAll(regex, replacement);
        case RegexEntrySubstitution.replaceFirst:
          return input.replaceFirst(regex, replacement);
        case RegexEntrySubstitution.append:
          return '$input$replacement';
        case RegexEntrySubstitution.prepend:
          return '$replacement$input';
        case RegexEntrySubstitution.remove:
          return input.replaceAll(regex, '');
      }
    } catch (_) {
      return input;
    }
  }

  bool test(String input) {
    if (!enabled || pattern.isEmpty) return false;
    try {
      final regex = RegExp(
        pattern,
        caseSensitive: caseSensitive,
        multiLine: multiline,
        dotAll: dotAll,
      );
      return regex.hasMatch(input);
    } catch (_) {
      return false;
    }
  }

  RegexRule copyWith({
    String? id,
    String? name,
    String? pattern,
    String? replacement,
    RegexEntryTiming? timing,
    RegexEntryPlacement? placement,
    RegexEntrySubstitution? substitution,
    bool? enabled,
    int? order,
    bool? caseSensitive,
    bool? multiline,
    bool? dotAll,
    String? description,
  }) {
    return RegexRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      timing: timing ?? this.timing,
      placement: placement ?? this.placement,
      substitution: substitution ?? this.substitution,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      multiline: multiline ?? this.multiline,
      dotAll: dotAll ?? this.dotAll,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pattern': pattern,
        'replacement': replacement,
        'timing': timing.name,
        'placement': placement.name,
        'substitution': substitution.name,
        'enabled': enabled,
        'order': order,
        'caseSensitive': caseSensitive,
        'multiline': multiline,
        'dotAll': dotAll,
        'description': description,
      };

  factory RegexRule.fromJson(Map<String, dynamic> json) => RegexRule(
        id: json['id'],
        name: json['name'] ?? '',
        pattern: json['pattern'] ?? '',
        replacement: json['replacement'] ?? '',
        timing: RegexEntryTiming.values.firstWhere(
          (e) => e.name == json['timing'],
          orElse: () => RegexEntryTiming.receive,
        ),
        placement: RegexEntryPlacement.values.firstWhere(
          (e) => e.name == json['placement'],
          orElse: () => RegexEntryPlacement.all,
        ),
        substitution: RegexEntrySubstitution.values.firstWhere(
          (e) => e.name == json['substitution'],
          orElse: () => RegexEntrySubstitution.replaceAll,
        ),
        enabled: json['enabled'] ?? true,
        order: json['order'] ?? 0,
        caseSensitive: json['caseSensitive'] ?? false,
        multiline: json['multiline'] ?? false,
        dotAll: json['dotAll'] ?? false,
        description: json['description'],
      );
}


/// 聊天主题
class ChatTheme {
  final String id;
  final String name;
  final bool isBuiltIn;
  final bool isActive;

  // 颜色
  final int primaryColor;
  final int secondaryColor;
  final int backgroundColor;
  final int surfaceColor;
  final int userBubbleColor;
  final int userTextColor;
  final int assistantBubbleColor;
  final int assistantTextColor;
  final int systemTextColor;

  // 样式
  final ChatThemeStyle bubbleStyle;
  final double borderRadius;
  final double bubblePadding;
  final double messageSpacing;
  final String? fontFamily;
  final double fontSize;

  // 背景
  final String? backgroundImage;
  final double backgroundOpacity;
  final ChatBackgroundBlur backgroundBlur;

  // 角色样式
  final bool showAvatar;
  final ChatAvatarPosition avatarPosition;
  final double avatarSize;

  ChatTheme({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
    this.isActive = false,
    this.primaryColor = 0xFF6750A4,
    this.secondaryColor = 0xFFB58392,
    this.backgroundColor = 0xFFFFFBFE,
    this.surfaceColor = 0xFFFFFBFE,
    this.userBubbleColor = 0xFF6750A4,
    this.userTextColor = 0xFFFFFFFF,
    this.assistantBubbleColor = 0xFFE7E0EC,
    this.assistantTextColor = 0xFF1D1B20,
    this.systemTextColor = 0xFF49454F,
    this.bubbleStyle = ChatThemeStyle.bubble,
    this.borderRadius = 18,
    this.bubblePadding = 14,
    this.messageSpacing = 4,
    this.fontFamily,
    this.fontSize = 15,
    this.backgroundImage,
    this.backgroundOpacity = 1.0,
    this.backgroundBlur = ChatBackgroundBlur.none,
    this.showAvatar = true,
    this.avatarPosition = ChatAvatarPosition.left,
    this.avatarSize = 36,
  });

  ChatTheme copyWith({
    String? id,
    String? name,
    bool? isBuiltIn,
    bool? isActive,
    int? primaryColor,
    int? secondaryColor,
    int? backgroundColor,
    int? surfaceColor,
    int? userBubbleColor,
    int? userTextColor,
    int? assistantBubbleColor,
    int? assistantTextColor,
    int? systemTextColor,
    ChatThemeStyle? bubbleStyle,
    double? borderRadius,
    double? bubblePadding,
    double? messageSpacing,
    String? fontFamily,
    double? fontSize,
    String? backgroundImage,
    double? backgroundOpacity,
    ChatBackgroundBlur? backgroundBlur,
    bool? showAvatar,
    ChatAvatarPosition? avatarPosition,
    double? avatarSize,
  }) {
    return ChatTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isActive: isActive ?? this.isActive,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      userTextColor: userTextColor ?? this.userTextColor,
      assistantBubbleColor: assistantBubbleColor ?? this.assistantBubbleColor,
      assistantTextColor: assistantTextColor ?? this.assistantTextColor,
      systemTextColor: systemTextColor ?? this.systemTextColor,
      bubbleStyle: bubbleStyle ?? this.bubbleStyle,
      borderRadius: borderRadius ?? this.borderRadius,
      bubblePadding: bubblePadding ?? this.bubblePadding,
      messageSpacing: messageSpacing ?? this.messageSpacing,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      showAvatar: showAvatar ?? this.showAvatar,
      avatarPosition: avatarPosition ?? this.avatarPosition,
      avatarSize: avatarSize ?? this.avatarSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isBuiltIn': isBuiltIn,
        'isActive': isActive,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'backgroundColor': backgroundColor,
        'surfaceColor': surfaceColor,
        'userBubbleColor': userBubbleColor,
        'userTextColor': userTextColor,
        'assistantBubbleColor': assistantBubbleColor,
        'assistantTextColor': assistantTextColor,
        'systemTextColor': systemTextColor,
        'bubbleStyle': bubbleStyle.name,
        'borderRadius': borderRadius,
        'bubblePadding': bubblePadding,
        'messageSpacing': messageSpacing,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'backgroundImage': backgroundImage,
        'backgroundOpacity': backgroundOpacity,
        'backgroundBlur': backgroundBlur.name,
        'showAvatar': showAvatar,
        'avatarPosition': avatarPosition.name,
        'avatarSize': avatarSize,
      };

  factory ChatTheme.fromJson(Map<String, dynamic> json) => ChatTheme(
        id: json['id'],
        name: json['name'] ?? '',
        isBuiltIn: json['isBuiltIn'] ?? false,
        isActive: json['isActive'] ?? false,
        primaryColor: json['primaryColor'] ?? 0xFF6750A4,
        secondaryColor: json['secondaryColor'] ?? 0xFFB58392,
        backgroundColor: json['backgroundColor'] ?? 0xFFFFFBFE,
        surfaceColor: json['surfaceColor'] ?? 0xFFFFFBFE,
        userBubbleColor: json['userBubbleColor'] ?? 0xFF6750A4,
        userTextColor: json['userTextColor'] ?? 0xFFFFFFFF,
        assistantBubbleColor: json['assistantBubbleColor'] ?? 0xFFE7E0EC,
        assistantTextColor: json['assistantTextColor'] ?? 0xFF1D1B20,
        systemTextColor: json['systemTextColor'] ?? 0xFF49454F,
        bubbleStyle: ChatThemeStyle.values.firstWhere(
          (e) => e.name == json['bubbleStyle'],
          orElse: () => ChatThemeStyle.bubble,
        ),
        borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 18,
        bubblePadding: (json['bubblePadding'] as num?)?.toDouble() ?? 14,
        messageSpacing: (json['messageSpacing'] as num?)?.toDouble() ?? 4,
        fontFamily: json['fontFamily'],
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 15,
        backgroundImage: json['backgroundImage'],
        backgroundOpacity:
            (json['backgroundOpacity'] as num?)?.toDouble() ?? 1.0,
        backgroundBlur: ChatBackgroundBlur.values.firstWhere(
          (e) => e.name == json['backgroundBlur'],
          orElse: () => ChatBackgroundBlur.none,
        ),
        showAvatar: json['showAvatar'] ?? true,
        avatarPosition: ChatAvatarPosition.values.firstWhere(
          (e) => e.name == json['avatarPosition'],
          orElse: () => ChatAvatarPosition.left,
        ),
        avatarSize: (json['avatarSize'] as num?)?.toDouble() ?? 36,
      );
}

enum ChatThemeStyle {
  bubble,
  flat,
  minimal,
  im,
}

enum ChatBackgroundBlur {
  none,
  light,
  medium,
  heavy,
}

enum ChatAvatarPosition {
  left,
  right,
  both,
  hidden,
}

/// 主题匹配
class ChatThemeMatch {
  final String themeId;
  final double score;
  final MatchReason reason;

  ChatThemeMatch({
    required this.themeId,
    required this.score,
    required this.reason,
  });
}

enum MatchReason {
  exact,
  colorSimilar,
  styleSimilar,
  fallback,
}

/// 主题导入操作
enum ChatThemeImportAction {
  import,
  skip,
  overwrite,
  merge,
}

/// 主题导入决策
enum ChatThemeImportDecision {
  success,
  skipped,
  failed,
  conflict,
}

/// 主题归档
class ThemeArchive {
  final String id;
  final String name;
  final DateTime createdAt;
  final int themeCount;
  final int fileSize;

  ThemeArchive({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.themeCount,
    required this.fileSize,
  });
}

/// 主题规范
class ThemeSpec {
  final String version;
  final Map<String, dynamic> schema;

  ThemeSpec({required this.version, required this.schema});
}

/// 主题名称
class ThemeName {
  final String id;
  final String name;
  final String category;

  ThemeName({required this.id, required this.name, this.category = 'custom'});
}

/// 可空的聊天主题引用
class NullableChatThemeRef {
  final String? themeId;
  final bool isOverride;

  NullableChatThemeRef({this.themeId, this.isOverride = false});
}

/// 对话可空聊天主题引用
class ConversationNullableChatThemeRef {
  final String conversationId;
  final String? themeId;
  final bool isInherited;

  ConversationNullableChatThemeRef({
    required this.conversationId,
    this.themeId,
    this.isInherited = true,
  });
}

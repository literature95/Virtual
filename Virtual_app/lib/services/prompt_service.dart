import 'package:intl/intl.dart';

import '../models/character.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/persona.dart';
import '../utils/image_data.dart';

/// Prompt 构建服务
///
/// 根据角色信息、对话历史、Persona 等构建最终发送给 LLM 的消息列表。
/// 支持宏变量替换，兼容主流角色卡格式（SillyTavern / Character.AI）。
/// 支持 46+ 种宏变量，包括身份、时间、条件块、注释等。
class PromptService {
  /// 构建完整的聊天消息列表（OpenAI 格式）
  ///
  /// [character] 角色信息
  /// [history] 历史消息列表
  /// [userMessage] 最新用户消息内容
  /// [persona] 用户人设（可选）
  /// [conversation] 对话信息（可选，用于群聊、覆盖场景等）
  /// [groupCharacters] 群聊中的角色列表（可选）
  /// [memories] 记忆内容（可选）
  /// [summary] 对话摘要（可选）
  /// [wordCountLimit] 字数限制（可选）
  /// [systemPromptOverride] 自定义 system prompt（可选，会追加到角色描述后）
  /// [jailbreakPrompt] 越狱提示词（可选，追加在 system prompt 末尾）
  static List<Map<String, dynamic>> buildMessages({
    required Character character,
    required List<ChatMessage> history,
    required String userMessage,
    Persona? persona,
    Conversation? conversation,
    List<Character>? groupCharacters,
    String? memories,
    String? summary,
    int? wordCountLimit,
    String? systemPromptOverride,
    String? jailbreakPrompt,
  }) {
    final macros = _buildMacros(
      character: character,
      persona: persona,
      history: history,
      userMessage: userMessage,
      conversation: conversation,
      groupCharacters: groupCharacters,
      memories: memories,
      summary: summary,
      wordCountLimit: wordCountLimit,
    );

    final systemContent = _buildSystemPrompt(
      character: character,
      macros: macros,
      persona: persona,
      conversation: conversation,
      memories: memories,
      summary: summary,
      systemPromptOverride: systemPromptOverride,
      jailbreakPrompt: jailbreakPrompt,
    );

    final messages = <Map<String, dynamic>>[];

    // System message
    messages.add({
      'role': 'system',
      'content': systemContent,
    });

    // 历史消息（过滤掉隐藏的和错误的）
    for (final msg in history) {
      if (msg.isHidden) continue;
      if (msg.role == MessageRole.system) continue;

      final role = _roleToString(msg.role);
      final content = _applyMacros(msg.content, macros);
      final images = msg.attachments
          .where((a) => a.type == MessageAttachmentType.image)
          .toList();

      if (images.isNotEmpty) {
        // 多模态消息：文本 + 图片（OpenAI 视觉格式）
        final parts = <Map<String, dynamic>>[];
        if (content.isNotEmpty) {
          parts.add({'type': 'text', 'text': content});
        }
        for (final a in images) {
          final url = imageDataUrlFromPath(a.path);
          if (url != null) {
            parts.add({
              'type': 'image_url',
              'image_url': {'url': url},
            });
          }
        }
        if (parts.isNotEmpty) {
          messages.add({'role': role, 'content': parts});
          continue;
        }
      }
      messages.add({
        'role': role,
        'content': content,
      });
    }

    // 最新用户消息
    messages.add({
      'role': 'user',
      'content': _applyMacros(userMessage, macros),
    });

    return messages;
  }

  /// 构建 system prompt 内容
  static String _buildSystemPrompt({
    required Character character,
    required Map<String, String> macros,
    Persona? persona,
    Conversation? conversation,
    String? memories,
    String? summary,
    String? systemPromptOverride,
    String? jailbreakPrompt,
  }) {
    final parts = <String>[];

    // charPrompt（角色系统提示词，优先级最高）
    final charPrompt = character.systemPrompt?.trim() ?? '';
    if (charPrompt.isNotEmpty) {
      parts.add(_applyMacros(charPrompt, macros));
    }

    // 角色名 + 基础描述
    final charDesc = character.description?.trim() ?? '';
    if (charDesc.isNotEmpty) {
      parts.add(_applyMacros(charDesc, macros));
    }

    // 性格
    final personality = character.personality?.trim() ?? '';
    if (personality.isNotEmpty) {
      parts.add(_applyMacros(personality, macros));
    }

    // 场景（优先使用对话覆盖场景）
    final scenario = (conversation?.overrideScenario?.trim() ??
            character.scenario?.trim()) ??
        '';
    if (scenario.isNotEmpty) {
      parts.add(_applyMacros(scenario, macros));
    }

    // charDepthPrompt（角色深度提示）
    final depthPrompt =
        character.extensions['depthPrompt']?.toString().trim() ?? '';
    if (depthPrompt.isNotEmpty) {
      parts.add(_applyMacros(depthPrompt, macros));
    }

    // Persona 描述
    if (persona != null) {
      final personaDesc = persona.description.trim();
      if (personaDesc.isNotEmpty) {
        parts.add(_applyMacros(personaDesc, macros));
      }
      if (persona.personality?.isNotEmpty ?? false) {
        parts.add(_applyMacros(persona.personality!, macros));
      }
    }

    // charInstruction（角色后历史指令）
    final charInstruction = _extractCharInstruction(character);
    if (charInstruction.isNotEmpty) {
      parts.add(_applyMacros(charInstruction, macros));
    }

    // 创作者备注：**不自动注入**。
    //
    // creator_notes 是作者写给「人」看的元信息（推荐 preset、抽样参数、
    // prompt 排版建议等），第三方卡片常含 `{{...}}` 宏片段或 Markdown
    // 代码块，直接拼进 system prompt 会污染甚至误导模型。
    // 需要时使用 `{{charCreatorNotes}}` 宏显式引用即可。
    // 示例消息（已渲染）
    final mesExamples = macros['mesExamples'] ?? '';
    if (mesExamples.isNotEmpty) {
      parts.add(mesExamples);
    }

    // 记忆内容
    if (memories != null && memories.trim().isNotEmpty) {
      parts.add(_applyMacros(memories.trim(), macros));
    }

    // 对话摘要
    if (summary != null && summary.trim().isNotEmpty) {
      parts.add(_applyMacros(summary.trim(), macros));
    }

    // 自定义 system prompt 覆盖/追加
    if (systemPromptOverride != null &&
        systemPromptOverride.trim().isNotEmpty) {
      parts.add(_applyMacros(systemPromptOverride.trim(), macros));
    }

    // 越狱提示词
    if (jailbreakPrompt != null && jailbreakPrompt.trim().isNotEmpty) {
      parts.add(_applyMacros(jailbreakPrompt.trim(), macros));
    }

    var result = parts.join('\n\n').trim();
    result = _applyMacros(result, macros);
    return result;
  }

  /// 构建宏变量映射表（完整 46 宏实现）
  static Map<String, String> _buildMacros({
    required Character character,
    required List<ChatMessage> history,
    required String userMessage,
    Persona? persona,
    Conversation? conversation,
    List<Character>? groupCharacters,
    String? memories,
    String? summary,
    int? wordCountLimit,
  }) {
    final now = DateTime.now();
    final userName = persona?.name ?? 'User';
    final personaDesc = persona?.description ?? '';

    // === Identity & Group Macros ===
    final charName = character.nickname?.isNotEmpty == true
        ? character.nickname!
        : character.name;
    final isGroupChat = conversation?.isGroupChat ?? false;
    final groupNames = _buildGroupNames(groupCharacters, character);
    final groupNotMutedNames = _buildGroupNotMutedNames(
      groupCharacters,
      character,
      conversation?.mutedCharacterIds ?? [],
    );

    // === Character/Persona Context Macros ===
    final charInstruction = _extractCharInstruction(character);
    final mesExamplesRaw = _renderExampleMessagesRaw(
      character.exampleMessages,
      charName: character.name,
      userName: userName,
    );
    final mesExamples = _renderExampleMessages(
      character.exampleMessages,
      charName: character.name,
      userName: userName,
    );
    final charTags = character.tags.join(', ');
    final charVersion = character.characterVersion ?? '';
    final charCreatorNotes = character.creatorNotes ?? '';
    final charDepthPrompt =
        character.extensions['depthPrompt']?.toString() ?? '';

    // === Time/State Macros ===
    final weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = weekdayNames[now.weekday - 1];
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);
    final isodate = now.toIso8601String();
    final isotime = DateFormat('HH:mm:ss').format(now);

    // === Last Message Macros ===
    final lastMessage = _findLastMessage(history);
    final lastUserMessage = _findLastUserMessage(history);
    final lastCharMessage = _findLastCharMessage(history);

    // === Utility Macros ===
    const newline = '\n';
    final memoriesValue = memories ?? '';
    final summaryValue = summary ?? '';
    final wordsValue = wordCountLimit?.toString() ?? '';

    // === Build macros map ===
    final macros = <String, String>{
      // Identity & Group
      'char': charName,
      'user': userName,
      'group': groupNames,
      'charIfNotGroup': isGroupChat ? groupNames : charName,
      'groupNotMuted': groupNotMutedNames,

      // Character/Persona Context
      'charPrompt': character.systemPrompt ?? '',
      'charInstruction': charInstruction,
      'charDescription': character.description ?? '',
      'description': character.description ?? '',
      'charPersonality': character.personality ?? '',
      'personality': character.personality ?? '',
      'charScenario': character.scenario ?? '',
      'scenario': character.scenario ?? '',
      'persona': personaDesc,
      'mesExamples': mesExamples,
      'mesExamplesRaw': mesExamplesRaw,
      'charVersion': charVersion,
      'charDepthPrompt': charDepthPrompt,
      'charCreatorNotes': charCreatorNotes,
      'charNickname': character.nickname ?? '',
      'charTags': charTags,

      // Time/State
      'time': timeStr,
      'date': dateStr,
      'weekday': weekday,
      'isotime': isotime,
      'isodate': isodate,
      'lastMessage': lastMessage,
      'lastUserMessage': lastUserMessage,
      'lastCharMessage': lastCharMessage,
      'input': userMessage,

      // Utility
      'newline': newline,
      'memories': memoriesValue,
      'summary': summaryValue,
      'original': '', // 原始提示词，由外部注入
      'words': wordsValue,
    };

    // 添加角色扩展字段
    if (character.extensions.isNotEmpty) {
      for (final entry in character.extensions.entries) {
        if (entry.value != null) {
          macros['char${_capitalize(entry.key)}'] = entry.value.toString();
        }
      }
    }

    // 添加 persona 扩展
    if (persona != null) {
      macros['personaName'] = persona.name;
      macros['personaAvatar'] = persona.avatarPath ?? '';
    }

    return macros;
  }

  /// 应用宏变量替换（支持条件块和注释）
  static String _applyMacros(String text, Map<String, String> macros) {
    var result = text;

    // 1. 移除注释块 {{// ... }}
    result = result.replaceAll(RegExp(r'\{\{//.*?\}\}', dotAll: true), '');

    // 2. 处理条件块 {{#if variable}}...{{/if}}
    result = _processConditionals(result, macros);

    // 3. 应用宏变量替换（嵌套解析，最多 3 层）
    for (var i = 0; i < 3; i++) {
      var changed = false;
      macros.forEach((key, value) {
        final before = result;
        result = result.replaceAll('{{$key}}', value);
        if (result != before) changed = true;
      });
      if (!changed) break;
    }

    return result;
  }

  /// 处理条件块 {{#if variable}}...{{/if}}
  ///
  /// 如果 variable 对应的值非空，则保留块内容；否则移除整个块。
  static String _processConditionals(
    String text,
    Map<String, String> macros,
  ) {
    final pattern = RegExp(
      r'\{\{#if\s+(\w+)\}\}(.*?)\{\{/if\}\}',
      dotAll: true,
    );

    return text.replaceAllMapped(pattern, (match) {
      final variable = match.group(1)!;
      final content = match.group(2)!;
      final value = macros[variable] ?? '';
      return value.isNotEmpty ? content : '';
    });
  }

  /// 渲染示例消息为文本（带角色标记）
  static String _renderExampleMessages(
    List<CharacterExampleMessage> examples, {
    required String charName,
    required String userName,
  }) {
    if (examples.isEmpty) return '';
    final buffer = StringBuffer('对话示例:\n');
    for (final example in examples) {
      buffer.writeln('$userName: ${example.userMessage}');
      buffer.writeln('$charName: ${example.assistantMessage}');
      if (example.note != null && example.note!.isNotEmpty) {
        buffer.writeln('(${example.note})');
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// 渲染示例消息为原始文本（保留 {{char}} 和 {{user}} 宏）
  static String _renderExampleMessagesRaw(
    List<CharacterExampleMessage> examples, {
    required String charName,
    required String userName,
  }) {
    if (examples.isEmpty) return '';
    final buffer = StringBuffer();
    for (final example in examples) {
      buffer.writeln('{{user}}: ${example.userMessage}');
      buffer.writeln('{{char}}: ${example.assistantMessage}');
      if (example.note != null && example.note!.isNotEmpty) {
        buffer.writeln('(${example.note})');
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// 提取角色后历史指令
  ///
  /// 仅取 [Character.postHistoryInstructions]。
  ///
  /// 历史坑点：本方法曾把 `creatorNotes` 作为兜底返回，而
  /// [_buildSystemPrompt] 末尾又会单独追加一次 creatorNotes，导致同一段文本被
  /// 注入两次 —— creator notes 里通常混有 `{{...}}` 宏与作者提示词结构，重复
  /// 注入既浪费 token 又可能污染 prompt。此处已收敛为单一来源。
  static String _extractCharInstruction(Character character) =>
      character.postHistoryInstructions?.trim() ?? '';

  /// 构建群聊角色名称列表（逗号分隔）
  static String _buildGroupNames(
    List<Character>? groupCharacters,
    Character currentCharacter,
  ) {
    if (groupCharacters == null || groupCharacters.isEmpty) {
      return currentCharacter.name;
    }
    return groupCharacters.map((c) => c.name).join(', ');
  }

  /// 构建未静音的群聊角色名称列表
  static String _buildGroupNotMutedNames(
    List<Character>? groupCharacters,
    Character currentCharacter,
    List<String> mutedCharacterIds,
  ) {
    if (groupCharacters == null || groupCharacters.isEmpty) {
      return currentCharacter.name;
    }
    return groupCharacters
        .where((c) => !mutedCharacterIds.contains(c.id))
        .map((c) => c.name)
        .join(', ');
  }

  /// 查找最后一条消息内容
  static String _findLastMessage(List<ChatMessage> history) {
    if (history.isEmpty) return '';
    for (var i = history.length - 1; i >= 0; i--) {
      if (!history[i].isHidden && history[i].role != MessageRole.system) {
        return history[i].content;
      }
    }
    return '';
  }

  /// 查找最后一条用户消息
  static String _findLastUserMessage(List<ChatMessage> history) {
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].role == MessageRole.user && !history[i].isHidden) {
        return history[i].content;
      }
    }
    return '';
  }

  /// 查找最后一条角色消息
  static String _findLastCharMessage(List<ChatMessage> history) {
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].role == MessageRole.assistant && !history[i].isHidden) {
        return history[i].content;
      }
    }
    return '';
  }

  /// 首字母大写
  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// 将 MessageRole 转换为 API 字符串
  static String _roleToString(MessageRole role) {
    switch (role) {
      case MessageRole.system:
        return 'system';
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.tool:
        return 'tool';
    }
  }

  /// 构建用于非流式调用的消息列表（同 buildMessages，目前一致）
  static List<Map<String, dynamic>> buildMessagesNonStream({
    required Character character,
    required List<ChatMessage> history,
    required String userMessage,
    Persona? persona,
    Conversation? conversation,
    List<Character>? groupCharacters,
    String? memories,
    String? summary,
    int? wordCountLimit,
    String? systemPromptOverride,
    String? jailbreakPrompt,
  }) {
    return buildMessages(
      character: character,
      history: history,
      userMessage: userMessage,
      persona: persona,
      conversation: conversation,
      groupCharacters: groupCharacters,
      memories: memories,
      summary: summary,
      wordCountLimit: wordCountLimit,
      systemPromptOverride: systemPromptOverride,
      jailbreakPrompt: jailbreakPrompt,
    );
  }
}

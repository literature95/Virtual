import 'package:intl/intl.dart';

import '../models/character.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/lorebook.dart';
import '../models/persona.dart';
import '../models/preset.dart';
import '../utils/image_data.dart';
import 'context_window_service.dart';
import 'preset_service.dart';
import 'world_info_service.dart';

/// 两遍拼装的中间产物:完整 system 文本(已应用宏)+ 已选世界书块 + 宏表。
///
/// 背景:此前 ChatProvider 用「字段长度累加」粗估 system 占用,漏掉预设/
/// 世界书/示例对话等大头,导致历史裁剪预算虚高、总上下文超窗。现在先拼
/// 完整 system 文本再按真实长度估算,拼装结果直接复用进 buildMessages,
/// 避免世界书二次选择(两次掷骰/扫描可能导致估算与实际不一致)。
class AssembledSystem {
  final String text;
  final Map<String, String> macros;
  final WorldInfoBlocks? loreBlocks;

  const AssembledSystem({
    required this.text,
    required this.macros,
    this.loreBlocks,
  });
}

/// Prompt 构建服务
///
/// 根据角色信息、对话历史、Persona 等构建最终发送给 LLM 的消息列表。
/// 支持宏变量替换，兼容主流角色卡格式（SillyTavern / Character.AI）。
/// 支持 46+ 种宏变量，包括身份、时间、条件块、注释等。
class PromptService {
  /// 第一遍拼装:选世界书条目 + 生成完整 system 文本。
  ///
  /// 调用方(ChatProvider)先用返回的 [AssembledSystem.text] 做真实 token
  /// 估算 → 裁剪历史 → 把整个结果传给 [buildMessages] 的 `assembled`
  /// 参数复用,保证估算与最终请求一致。
  static AssembledSystem assembleSystem({
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
    Lorebook? lorebook,
    Preset? preset,
  }) {
    final macros = _buildMacros(
      character: character,
      history: history,
      userMessage: userMessage,
      persona: persona,
      conversation: conversation,
      groupCharacters: groupCharacters,
      memories: memories,
      summary: summary,
      wordCountLimit: wordCountLimit,
    );

    WorldInfoBlocks? blocks;
    if (lorebook != null) {
      final texts = [
        for (final m in history)
          if (!m.isHidden && m.role != MessageRole.system) m.content,
        userMessage,
      ];
      blocks = WorldInfoService.renderBlocks(
          WorldInfoService.selectEntries(lorebook, texts));
    }

    final text = _buildSystemPrompt(
      character: character,
      macros: macros,
      persona: persona,
      conversation: conversation,
      memories: memories,
      summary: summary,
      systemPromptOverride: systemPromptOverride,
      jailbreakPrompt: jailbreakPrompt,
      loreBlocks: blocks,
      preset: preset,
    );
    return AssembledSystem(text: text, macros: macros, loreBlocks: blocks);
  }

  /// 两遍拼装的 system 区 token 预算:system 文本 + beforeUser/afterUser
  /// 世界书块(它们单独成 system 消息,不在 text 里)+ 固定余量。
  /// 结果直接传给 ContextWindowService.trim 的 reservedForSystem。
  static int estimateSystemTokens(AssembledSystem assembled, {int margin = 64}) {
    return ContextWindowService.estimateTokens(assembled.text) +
        ContextWindowService.estimateTokens(
            assembled.loreBlocks?.beforeUser ?? '') +
        ContextWindowService.estimateTokens(
            assembled.loreBlocks?.afterUser ?? '') +
        margin;
  }

  /// 渲染开场白(firstMessage):应用 {{user}}/{{char}}/时间等全部宏。
  ///
  /// {{user}} 的值来自 [persona],调用方先经 ChatProvider.resolvePersona
  /// 链(绑定 > 激活 > 账号昵称 > 'User')解析。开场白在插入消息列表时
  /// 渲染并落库——之后改昵称不会回写旧对话的开场白,符合"当时身份"直觉。
  static String renderGreeting({
    required Character character,
    Persona? persona,
  }) {
    final macros = _buildMacros(
      character: character,
      history: const [],
      userMessage: '',
      persona: persona,
    );
    return _applyMacros(character.firstMessage?.trim() ?? '', macros);
  }

  /// 构建完整的聊天消息列表（OpenAI 格式）
  ///
  /// [character] 角色信息
  /// [history] 历史消息列表
  /// [userMessage] 最新用户消息内容
  /// [userAttachments] 最新用户消息的图片附件(仅此一条随请求上传;
  ///   历史消息中的图片一律降级为 `[图片]` 文本占位,不重复上传)
  /// [assembled] 两遍拼装复用:传入时忽略 [lorebook]/[preset],
  ///   直接使用其 system 文本/宏表/世界书块
  static List<Map<String, dynamic>> buildMessages({
    required Character character,
    required List<ChatMessage> history,
    required String userMessage,
    List<MessageAttachment>? userAttachments,
    Persona? persona,
    Conversation? conversation,
    List<Character>? groupCharacters,
    String? memories,
    String? summary,
    int? wordCountLimit,
    String? systemPromptOverride,
    String? jailbreakPrompt,
    Lorebook? lorebook,
    Preset? preset,
    AssembledSystem? assembled,
  }) {
    final macros = assembled?.macros ??
        _buildMacros(
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

    // ── 世界书（绑定与切换：会话 > 角色卡，由 ChatProvider 解析后传入）──
    // 常驻条目恒注入；关键词条目按最近 scanDepth 条消息命中触发。
    WorldInfoBlocks? loreBlocks;
    if (assembled != null) {
      loreBlocks = assembled.loreBlocks;
    } else if (lorebook != null) {
      final texts = [
        for (final m in history)
          if (!m.isHidden && m.role != MessageRole.system) m.content,
        userMessage,
      ];
      loreBlocks = WorldInfoService.renderBlocks(
          WorldInfoService.selectEntries(lorebook, texts));
    }

    final systemContent = assembled?.text ??
        _buildSystemPrompt(
          character: character,
          macros: macros,
          persona: persona,
          conversation: conversation,
          memories: memories,
          summary: summary,
          systemPromptOverride: systemPromptOverride,
          jailbreakPrompt: jailbreakPrompt,
          loreBlocks: loreBlocks,
          preset: preset,
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

      // 历史图片不随每轮请求重复上传(base64 内联体积大、token 成本高):
      // 统一降级为文本占位,只有最新一条用户消息的图片才真正上传。
      if (images.isNotEmpty) {
        final withMedia = content.isEmpty ? '[图片]' : '$content\n[图片]';
        messages.add({'role': role, 'content': withMedia});
        continue;
      }
      messages.add({
        'role': role,
        'content': content,
      });
    }

    // 最新用户消息(世界书 AN/深度类条目插在其前后;图片附件随本次
    // 请求上传一次,图片生成场景复用「最新对话文本 + 图片」这一口径)
    if (loreBlocks != null && loreBlocks.beforeUser.trim().isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': _applyMacros(loreBlocks.beforeUser, macros),
      });
    }
    final userImages = (userAttachments ?? const [])
        .where((a) => a.type == MessageAttachmentType.image)
        .toList();
    if (userImages.isNotEmpty) {
      final parts = <Map<String, dynamic>>[];
      final text = _applyMacros(userMessage, macros);
      if (text.isNotEmpty) {
        parts.add({'type': 'text', 'text': text});
      }
      for (final a in userImages) {
        final url = imageDataUrlFromPath(a.path);
        if (url != null) {
          parts.add({
            'type': 'image_url',
            'image_url': {'url': url},
          });
        }
      }
      if (parts.isNotEmpty) {
        messages.add({'role': 'user', 'content': parts});
      } else {
        // 图片全部读取失败:保底发文本,不让用户消息凭空消失
        final text = _applyMacros(userMessage, macros);
        messages.add({
          'role': 'user',
          'content': text.isEmpty ? '[图片]' : text,
        });
      }
    } else {
      messages.add({
        'role': 'user',
        'content': _applyMacros(userMessage, macros),
      });
    }
    if (loreBlocks != null && loreBlocks.afterUser.trim().isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': _applyMacros(loreBlocks.afterUser, macros),
      });
    }

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
    WorldInfoBlocks? loreBlocks,
    Preset? preset,
  }) {
    final parts = <String>[];

    // 预设（全局激活 / 会话绑定）：全局风格层，置于最前
    if (preset != null) {
      final merged = presetPrompt(preset, macros: macros);
      if (merged.trim().isNotEmpty) {
        parts.add(merged);
      }
    }

    // 世界书 beforeSystem 块（before_char / top：角色定义之前）
    final loreBeforeSystem =
        _applyMacros(loreBlocks?.beforeSystem ?? '', macros);
    if (loreBeforeSystem.trim().isNotEmpty) {
      parts.add(loreBeforeSystem.trim());
    }

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

    // 世界书 afterSystem 块（after_char：角色定义之后、深度提示之前）
    final loreAfterSystem =
        _applyMacros(loreBlocks?.afterSystem ?? '', macros);
    if (loreAfterSystem.trim().isNotEmpty) {
      parts.add(loreAfterSystem.trim());
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
    List<MessageAttachment>? userAttachments,
    Persona? persona,
    Conversation? conversation,
    List<Character>? groupCharacters,
    String? memories,
    String? summary,
    int? wordCountLimit,
    String? systemPromptOverride,
    String? jailbreakPrompt,
    Lorebook? lorebook,
    Preset? preset,
    AssembledSystem? assembled,
  }) {
    return buildMessages(
      character: character,
      history: history,
      userMessage: userMessage,
      userAttachments: userAttachments,
      persona: persona,
      conversation: conversation,
      groupCharacters: groupCharacters,
      memories: memories,
      summary: summary,
      wordCountLimit: wordCountLimit,
      systemPromptOverride: systemPromptOverride,
      jailbreakPrompt: jailbreakPrompt,
      lorebook: lorebook,
      preset: preset,
      assembled: assembled,
    );
  }

  /// 渲染预设为 prompt 文本（条目排序 + 宏替换）
  ///
  /// 公开给测试与调用方复用；宏替换用 [macros] 提供的变量表，
  /// 未提供的变量保持原样（与 _applyMacros 行为一致）。
  static String presetPrompt(Preset preset, {Map<String, String> macros = const {}}) {
    final merged = PresetService().mergePrompt(preset);
    return _applyMacros(merged, macros);
  }
}

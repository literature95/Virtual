# Tavo 源码还原 + 功能补全计划

> **For agentic workers:** 使用 subagent-driven-development 或 executing-plans 逐步执行。

**Goal:** 结合 Blutter 逆向提取、SillyTavern 参考、APK 资源，将还原度从 35% 提升至 ~60-65%

**Architecture:** 分 8 个阶段，每个阶段独立可构建可测试。优先恢复核心链路（API→Prompt→聊天），再扩展辅助功能。

**Tech Stack:** Flutter 3.47.1, Dart, Provider, go_router, SharedPreferences, dio

---

## 当前状态

| 文件 | 行数 | 状态 |
|------|------|------|
| lib/data/app_database.dart | 414 | ✅ 完整 CRUD |
| lib/models/ (11 files) | 3,442 | ✅ 字段完整 |
| lib/providers/ (5 files) | 1,235 | ⚠️ 部分逻辑缺失 |
| lib/services/ (6 files) | 981 | ⚠️ 仅 OpenAI 兼容 |
| lib/views/ (10 files) | 3,599 | ⚠️ 缺少多个页面 |
| lib/utils/ (4 files) | 147 | ✅ 基础工具 |
| lib/theme/ (1 file) | 58 | ⚠️ 仅基础亮暗色 |
| lib/route/ (1 file) | 68 | ⚠️ 缺少多个路由 |

---

## Phase 1: API 多平台适配

> 目标：支持 OpenAI / Anthropic / Gemini / DeepSeek / Grok 等主要平台

### Task 1.1: 统一 API 适配器架构

**Files:**
- Modify: `lib/services/api_service.dart`
- Create: `lib/services/adapters/openai_adapter.dart`
- Create: `lib/services/adapters/anthropic_adapter.dart`
- Create: `lib/services/adapters/gemini_adapter.dart`

- [ ] **Step 1: 定义适配器接口**

```dart
// lib/services/adapters/llm_adapter.dart
import '../api_service.dart';

abstract class LLMAdapter {
  /// 构建请求体
  Map<String, dynamic> buildRequest({
    required List<ChatMessage> messages,
    required String model,
    required String systemPrompt,
    Map<String, dynamic>? parameters,
  });

  /// 解析流式 SSE 行
  Stream<ChatChunk> parseSSEStream(Stream<String> lines);

  /// 解析非流式响应
  ChatResponse parseResponse(Map<String, dynamic> json);

  /// 获取协议标识
  String get protocol;
}
```

- [ ] **Step 2: 实现 OpenAI 适配器**

```dart
// lib/services/adapters/openai_adapter.dart
import 'dart:async';
import 'dart:convert';
import '../api_service.dart';
import 'llm_adapter.dart';

class OpenAIAdapter extends LLMAdapter {
  @override
  String get protocol => 'openai_chat';

  @override
  Map<String, dynamic> buildRequest({
    required List<ChatMessage> messages,
    required String model,
    required String systemPrompt,
    Map<String, dynamic>? parameters,
  }) {
    final msgs = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => {
        'role': m.role == MessageRole.user ? 'user' : 'assistant',
        'content': m.content,
      }),
    ];
    return {
      'model': model,
      'messages': msgs,
      'stream': true,
      if (parameters != null) ...parameters,
    };
  }

  @override
  Stream<ChatChunk> parseSSEStream(Stream<String> lines) async* {
    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            if (delta != null) {
              final content = delta['content'] as String?;
              final reasoning = delta['reasoning_content'] as String?;
              if (content != null || reasoning != null) {
                yield ChatChunk(
                  content: content ?? '',
                  reasoningContent: reasoning,
                  finishReason: choices[0]['finish_reason'] as String?,
                );
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  ChatResponse parseResponse(Map<String, dynamic> json) {
    final choices = json['choices'] as List;
    final message = choices[0]['message'] as Map<String, dynamic>;
    final usage = json['usage'] as Map<String, dynamic>?;
    return ChatResponse(
      content: message['content'] as String? ?? '',
      reasoningContent: message['reasoning_content'] as String?,
      promptTokens: usage?['prompt_tokens'] as int? ?? 0,
      completionTokens: usage?['completion_tokens'] as int? ?? 0,
    );
  }
}
```

- [ ] **Step 3: 实现 Anthropic 适配器**

```dart
// lib/services/adapters/anthropic_adapter.dart
import 'dart:async';
import 'dart:convert';
import '../api_service.dart';
import 'llm_adapter.dart';

class AnthropicAdapter extends LLMAdapter {
  @override
  String get protocol => 'anthropic_messages';

  @override
  Map<String, dynamic> buildRequest({
    required List<ChatMessage> messages,
    required String model,
    required String systemPrompt,
    Map<String, dynamic>? parameters,
  }) {
    final msgs = <Map<String, dynamic>>[
      ...messages.map((m) => {
        'role': m.role == MessageRole.user ? 'user' : 'assistant',
        'content': m.content,
      }),
    ];
    return {
      'model': model,
      'system': systemPrompt,
      'messages': msgs,
      'stream': true,
      'max_tokens': parameters?['max_tokens'] ?? 4096,
      if (parameters != null) ...parameters,
    };
  }

  @override
  Stream<ChatChunk> parseSSEStream(Stream<String> lines) async* {
    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'content_block_delta') {
            final delta = json['delta'] as Map<String, dynamic>?;
            if (delta?['type'] == 'text_delta') {
              yield ChatChunk(content: delta?['text'] as String? ?? '');
            } else if (delta?['type'] == 'thinking_delta') {
              yield ChatChunk(reasoningContent: delta?['thinking'] as String? ?? '');
            }
          } else if (type == 'message_stop') {
            return;
          }
        } catch (_) {}
      }
    }
  }

  @override
  ChatResponse parseResponse(Map<String, dynamic> json) {
    final content = json['content'] as List;
    final text = content.where((b) => b['type'] == 'text').map((b) => b['text']).join();
    final thinking = content.where((b) => b['type'] == 'thinking').map((b) => b['thinking']).join();
    final usage = json['usage'] as Map<String, dynamic>?;
    return ChatResponse(
      content: text,
      reasoningContent: thinking.isNotEmpty ? thinking : null,
      promptTokens: usage?['input_tokens'] as int? ?? 0,
      completionTokens: usage?['output_tokens'] as int? ?? 0,
    );
  }
}
```

- [ ] **Step 4: 实现 Gemini 适配器**

```dart
// lib/services/adapters/gemini_adapter.dart
import 'dart:async';
import 'dart:convert';
import '../api_service.dart';
import 'llm_adapter.dart';

class GeminiAdapter extends LLMAdapter {
  @override
  String get protocol => 'gemini_generate_content';

  @override
  Map<String, dynamic> buildRequest({
    required List<ChatMessage> messages,
    required String model,
    required String systemPrompt,
    Map<String, dynamic>? parameters,
  }) {
    final contents = <Map<String, dynamic>>[];
    // Gemini uses alternating user/model turns
    for (final m in messages) {
      final role = m.role == MessageRole.user ? 'user' : 'model';
      contents.add({
        'role': role,
        'parts': [{'text': m.content}],
      });
    }
    return {
      'contents': contents,
      'systemInstruction': {
        'parts': [{'text': systemPrompt}],
      },
      'generationConfig': {
        if (parameters?['max_tokens'] != null)
          'maxOutputTokens': parameters!['max_tokens'],
        if (parameters?['temperature'] != null)
          'temperature': parameters!['temperature'],
        if (parameters?['top_p'] != null)
          'topP': parameters!['top_p'],
      },
    };
  }

  @override
  Stream<ChatChunk> parseSSEStream(Stream<String> lines) async* {
    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final candidates = json['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts != null) {
              for (final part in parts) {
                final text = part['text'] as String?;
                if (text != null) {
                  yield ChatChunk(content: text);
                }
              }
            }
          }
          // Check for usage
          final usage = json['usageMetadata'] as Map<String, dynamic>?;
          if (usage != null) {
            yield ChatChunk(
              promptTokens: usage['promptTokenCount'] as int?,
              completionTokens: usage['candidatesTokenCount'] as int?,
            );
          }
        } catch (_) {}
      }
    }
  }

  @override
  ChatResponse parseResponse(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List;
    final parts = candidates[0]['content']['parts'] as List;
    final text = parts.where((p) => p['text'] != null).map((p) => p['text']).join();
    final usage = json['usageMetadata'] as Map<String, dynamic>?;
    return ChatResponse(
      content: text,
      promptTokens: usage?['promptTokenCount'] as int? ?? 0,
      completionTokens: usage?['candidatesTokenCount'] as int? ?? 0,
    );
  }
}
```

- [ ] **Step 5: 重构 ApiService 使用适配器**

在 `api_service.dart` 中添加适配器注册和选择逻辑。根据 endpoint 的 protocol 字段选择对应适配器。

- [ ] **Step 6: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

### Task 1.2: 平台预设配置

**Files:**
- Modify: `lib/services/api_service.dart` (添加平台配置)
- Modify: `lib/models/endpoint.dart` (添加平台枚举值)

- [ ] **Step 1: 添加完整平台配置**

从 Blutter 提取的 URL 和模型列表，添加所有平台的默认配置：

```dart
// lib/services/platform_presets.dart
class PlatformPreset {
  final String id;
  final String name;
  final String baseUrl;
  final String protocol; // openai_chat, anthropic_messages, gemini_generate_content
  final List<String> models;
  final Map<String, String> headers;
  final String? authPrefix; // "Bearer ", "x-goog-api-key ", etc.

  const PlatformPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.protocol,
    required this.models,
    this.headers = const {},
    this.authPrefix = 'Bearer ',
  });
}

const platformPresets = <PlatformPreset>[
  PlatformPreset(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    protocol: 'openai_chat',
    models: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'o1', 'o1-mini', 'o3-mini'],
  ),
  PlatformPreset(
    id: 'anthropic',
    name: 'Anthropic',
    baseUrl: 'https://api.anthropic.com/v1',
    protocol: 'anthropic_messages',
    models: ['claude-opus-4-20250514', 'claude-sonnet-4-20250514', 'claude-3-5-haiku-20241022'],
    headers: {'anthropic-version': '2023-06-01'},
  ),
  PlatformPreset(
    id: 'gemini',
    name: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    protocol: 'gemini_generate_content',
    models: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'],
    authPrefix: '',
    headers: {'x-goog-api-key': ''},
  ),
  PlatformPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    protocol: 'openai_chat',
    models: ['deepseek-chat', 'deepseek-reasoner'],
  ),
  PlatformPreset(
    id: 'grok',
    name: 'Grok (xAI)',
    baseUrl: 'https://api.x.ai/v1',
    protocol: 'openai_chat',
    models: ['grok-3', 'grok-3-mini', 'grok-2'],
  ),
  PlatformPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    protocol: 'openai_chat',
    models: ['anthropic/claude-3.5-sonnet', 'openai/gpt-4o', 'google/gemini-2.5-flash'],
  ),
  PlatformPreset(
    id: 'minimax',
    name: 'MiniMax',
    baseUrl: 'https://api.minimax.io/v1',
    protocol: 'openai_chat',
    models: ['MiniMax-Text-01', 'abab6.5s-chat'],
  ),
  PlatformPreset(
    id: 'volink',
    name: 'Volink',
    baseUrl: 'https://api.volink.org',
    protocol: 'openai_chat',
    models: [],
  ),
];
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Phase 2: Prompt 引擎（46 宏变量）

> 目标：实现完整的宏变量替换系统

### Task 2.1: 宏变量引擎

**Files:**
- Modify: `lib/services/prompt_service.dart`

- [ ] **Step 1: 扩展宏变量注册表**

```dart
// 在 prompt_service.dart 中，添加完整宏列表
final _macros = <String, String Function(BuildContext, ChatContext)>{
  // 身份类
  'char': (ctx, c) => c.character.nickname ?? c.character.name,
  'user': (ctx, c) => c.persona?.name ?? 'User',
  'group': (ctx, c) => c.groupCharacters.join(', '),
  'charIfNotGroup': (ctx, c) => c.isGroupChat
      ? c.groupCharacters.join(', ')
      : (c.character.nickname ?? c.character.name),
  'groupNotMuted': (ctx, c) => c.groupCharacters
      .where((name) => !c.conversation.mutedCharacterIds.contains(name))
      .join(', '),

  // 角色上下文
  'charPrompt': (ctx, c) => c.character.systemPrompt ?? '',
  'charInstruction': (ctx, c) => c.character.postHistoryInstructions ?? '',
  'description': (ctx, c) => c.character.description ?? '',
  'charDescription': (ctx, c) => c.character.description ?? '',
  'personality': (ctx, c) => c.character.personality ?? '',
  'charPersonality': (ctx, c) => c.character.personality ?? '',
  'scenario': (ctx, c) => c.conversation.overrideScenario ?? c.character.scenario ?? '',
  'charScenario': (ctx, c) => c.conversation.overrideScenario ?? c.character.scenario ?? '',
  'persona': (ctx, c) => c.persona?.description ?? '',
  'mesExamples': (ctx, c) => _renderExamples(c.character.mesExample ?? ''),
  'mesExamplesRaw': (ctx, c) => c.character.mesExample ?? '',
  'charVersion': (ctx, c) => c.character.characterVersion ?? '',
  'charDepthPrompt': (ctx, c) => c.character.depthPrompt ?? '',
  'charCreatorNotes': (ctx, c) => c.character.creatorNotes ?? '',
  'charNickname': (ctx, c) => c.character.nickname ?? '',
  'charTags': (ctx, c) => (c.character.tags ?? []).join(', '),

  // 时间类
  'time': (ctx, c) => DateFormat('HH:mm').format(DateTime.now()),
  'date': (ctx, c) => DateFormat('yyyy-MM-dd').format(DateTime.now()),
  'weekday': (ctx, c) => _weekdayName(DateTime.now().weekday),
  'isotime': (ctx, c) => DateTime.now().toIso8601String(),
  'isodate': (ctx, c) => DateTime.now().toIso8601String().split('T')[0],

  // 对话上下文
  'lastMessage': (ctx, c) => c.lastMessage ?? '',
  'lastUserMessage': (ctx, c) => c.lastUserMessage ?? '',
  'lastCharMessage': (ctx, c) => c.lastCharMessage ?? '',
  'input': (ctx, c) => c.currentInput ?? '',

  // 工具类
  'newline': (ctx, c) => '\n',
  'memories': (ctx, c) => c.memories ?? '',
  'summary': (ctx, c) => c.summary ?? '',
  'original': (ctx, c) => c.originalPrompt ?? '',
  'words': (ctx, c) => c.wordCount?.toString() ?? '',
};
```

- [ ] **Step 2: 实现条件块解析**

```dart
String _parseConditionals(String text, ChatContext ctx) {
  // {{#if char}}...{{/if}}
  final ifPattern = RegExp(r'\{\{#if\s+(\w+)\}\}([\s\S]*?)\{\{/if\}\}');
  return text.replaceAllMapped(ifPattern, (match) {
    final variable = match.group(1)!;
    final content = match.group(2)!;
    final value = _resolveVariable(variable, ctx);
    return value.isNotEmpty ? content : '';
  });
}
```

- [ ] **Step 3: 实现注释块移除**

```dart
String _removeComments(String text) {
  // {{// ... }}
  return text.replaceAll(RegExp(r'\{\{//[\s\S]*?\}\}'), '');
}
```

- [ ] **Step 4: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Phase 3: 角色系统补全

> 目标：角色导入/导出、CCv3 格式支持、来源平台适配

### Task 3.1: 角色导入服务

**Files:**
- Create: `lib/services/character_import_service.dart`

- [ ] **Step 1: 实现多来源导入**

```dart
// lib/services/character_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/character.dart';

class CharacterImportSource {
  final String name;
  final String Function(String id) urlBuilder;
  final Character Function(Map<String, dynamic> json) parser;

  const CharacterImportSource({
    required this.name,
    required this.urlBuilder,
    required this.parser,
  });
}

class CharacterImportService {
  final Dio _dio;

  CharacterImportService(this._dio);

  static const sources = <String, CharacterImportSource>{
    'chub': CharacterImportSource(
      name: 'Chub.ai',
      urlBuilder: (id) => 'https://api.chub.ai/api/characters/$id',
      parser: _parseChubV2,
    ),
    'risu': CharacterImportSource(
      name: 'RisuAI',
      urlBuilder: (id) => 'https://realm.risuai.net/api/v1/download/png-v3/$id',
      parser: _parseRisuPng,
    ),
    'janny': CharacterImportSource(
      name: 'JannyAI',
      urlBuilder: (id) => 'https://api.jannyai.com/api/v1/download',
      parser: _parseJanny,
    ),
    'pygmalion': CharacterImportSource(
      name: 'Pygmalion',
      urlBuilder: (id) => 'https://server.pygmalion.chat/api/export/character/$id',
      parser: _parsePygmalion,
    ),
  };

  /// 从 URL 导入角色
  Future<Character> importFromUrl(String url, {String? source}) async {
    // 检测来源
    final detectedSource = source ?? _detectSource(url);
    final importSource = sources[detectedSource];
    if (importSource == null) throw Exception('不支持的来源: $detectedSource');

    final response = await _dio.get(url);
    return importSource.parser(response.data);
  }

  /// 从本地 PNG 文件导入（含嵌入的 CCv3 数据）
  Future<Character> importFromPng(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return _extractCharacterFromPng(bytes);
  }

  /// 从 JSON 导入（CCv2/CCv3 格式）
  Character importFromJson(Map<String, dynamic> json) {
    // 检测格式
    if (json.containsKey('spec') && json['spec'] == 'chara_card_v3') {
      return _parseCCv3(json);
    } else if (json.containsKey('data')) {
      return _parseCCv2(json);
    }
    throw Exception('未知的角色卡格式');
  }

  String _detectSource(String url) {
    if (url.contains('chub.ai')) return 'chub';
    if (url.contains('risuai.net')) return 'risu';
    if (url.contains('jannyai.com')) return 'janny';
    if (url.includes('pygmalion.chat')) return 'pygmalion';
    throw Exception('无法检测来源');
  }

  static Character _parseChubV2(Map<String, dynamic> json) {
    final data = json['node'] ?? json;
    return Character(
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      personality: data['personality'] ?? '',
      scenario: data['scenario'] ?? '',
      firstMes: data['first_mes'] ?? '',
      mesExample: data['mes_example'] ?? '',
      systemPrompt: data['system_prompt'] ?? '',
      postHistoryInstructions: data['post_history_instructions'] ?? '',
      creatorNotes: data['creator_notes'] ?? '',
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
      creator: data['creator'] ?? '',
    );
  }

  static Character _parseCCv3(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return Character(
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      personality: data['personality'] ?? '',
      scenario: data['scenario'] ?? '',
      firstMes: data['first_mes'] ?? '',
      mesExample: data['mes_example'] ?? '',
      systemPrompt: data['system_prompt'] ?? '',
      postHistoryInstructions: data['post_history_instructions'] ?? '',
      creatorNotes: data['creator_notes'] ?? '',
      creator: data['creator'] ?? '',
      characterVersion: data['character_version']?.toString() ?? '',
      nickname: data['nickname'] ?? '',
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
    );
  }

  static Character _parseCCv2(Map<String, dynamic> json) {
    final data = json['data'];
    if (data == null) throw Exception('无效的 CCv2 格式');
    return _parseCCv3({'data': data, 'spec': 'chara_card_v3'});
  }

  static Character _parseRisuPng(Map<String, dynamic> json) {
    // RisuAI 返回 PNG，需要提取嵌入的 JSON
    return _parseCCv3(json);
  }

  static Character _parseJanny(Map<String, dynamic> json) {
    return _parseCCv3(json);
  }

  static Character _parsePygmalion(Map<String, dynamic> json) {
    return _parseCCv2(json);
  }

  Character _extractCharacterFromPng(List<int> bytes) {
    // PNG 文件中嵌入的 tEXt chunk 包含 chara_card_v2 JSON
    // 查找末尾的 chara 数据
    final String content = String.fromCharCodes(bytes);
    // 寻找 JSON 块
    final jsonPattern = RegExp(r'\{[\s\S]*"spec"\s*:\s*"chara_card_v[23]"[\s\S]*\}');
    final match = jsonPattern.firstMatch(content);
    if (match != null) {
      final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      return importFromJson(json);
    }
    throw Exception('PNG 中未找到角色卡数据');
  }
}
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

### Task 3.2: 角色导出服务

**Files:**
- Create: `lib/services/character_export_service.dart`

- [ ] **Step 1: 实现 CCv3 导出**

```dart
// lib/services/character_export_service.dart
import 'dart:convert';
import 'dart:io';
import '../models/character.dart';

class CharacterExportService {
  /// 导出为 CCv3 JSON
  Map<String, dynamic> toCCv3(Character character) {
    return {
      'spec': 'chara_card_v3',
      'data': {
        'name': character.name,
        'description': character.description,
        'personality': character.personality,
        'scenario': character.scenario,
        'first_mes': character.firstMes,
        'mes_example': character.mesExample,
        'system_prompt': character.systemPrompt,
        'post_history_instructions': character.postHistoryInstructions,
        'creator_notes': character.creatorNotes,
        'creator': character.creator,
        'character_version': character.characterVersion,
        'nickname': character.nickname,
        'tags': character.tags,
        'extensions': character.extensions,
      },
    };
  }

  /// 导出为 SillyTavern 格式
  Map<String, dynamic> toSillyTavern(Character character) {
    return {
      'name': character.name,
      'description': character.description,
      'personality': character.personality,
      'scenario': character.scenario,
      'first_mes': character.firstMes,
      'mes_example': character.mesExample,
      'system_prompt': character.systemPrompt,
      'post_history_instructions': character.postHistoryInstructions,
      'creator_notes': character.creatorNotes,
      'tags': character.tags,
    };
  }

  /// 保存为 JSON 文件
  Future<void> saveToFile(Character character, String path, {String format = 'ccv3'}) async {
    final Map<String, dynamic> data;
    switch (format) {
      case 'ccv3':
        data = toCCv3(character);
        break;
      case 'sillytavern':
        data = toSillyTavern(character);
        break;
      default:
        data = toCCv3(character);
    }
    final file = File(path);
    await file.writeAsString(jsonEncode(data));
  }
}
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Phase 4: Lorebook 系统

> 目标：关键词匹配、注入位置控制、正则支持

### Task 4.1: Lorebook 匹配引擎

**Files:**
- Create: `lib/services/lorebook_service.dart`

- [ ] **Step 1: 实现关键词匹配**

```dart
// lib/services/lorebook_service.dart
import '../models/lorebook.dart';
import '../models/chat_message.dart';

class LorebookMatchResult {
  final String entryId;
  final String content;
  final int position;

  const LorebookMatchResult({
    required this.entryId,
    required this.content,
    required this.position,
  });
}

class LorebookService {
  /// 从聊天消息中匹配所有激活的 Lorebook 条目
  List<LorebookMatchResult> matchEntries({
    required Lorebook lorebook,
    required List<ChatMessage> messages,
    int depth = 2,
  }) {
    final results = <LorebookMatchResult>[];
    // 获取最近 N 条消息作为扫描文本
    final scanMessages = messages.length > depth
        ? messages.sublist(messages.length - depth)
        : messages;
    final scanText = scanMessages.map((m) => m.content).join('\n').toLowerCase();

    for (final entry in lorebook.entries) {
      if (!entry.enabled) continue;

      bool matched = false;

      if (entry.constant) {
        // 常量条目始终匹配
        matched = true;
      } else if (entry.useRegex && entry.selectiveRegex != null) {
        // 正则匹配
        try {
          final regex = RegExp(entry.selectiveRegex!, caseSensitive: false);
          matched = regex.hasMatch(scanText);
        } catch (_) {}
      } else {
        // 关键词匹配
        for (final key in entry.keys) {
          if (key.trim().isEmpty) continue;
          if (scanText.contains(key.toLowerCase())) {
            matched = true;
            break;
          }
        }
      }

      if (matched) {
        results.add(LorebookMatchResult(
          entryId: entry.id,
          content: entry.content,
          position: entry.position == LorebookPosition.before ? 0 : 1,
        ));
      }
    }

    // 按 insertOrder 排序
    results.sort((a, b) => a.position.compareTo(b.position));
    return results;
  }

  /// 将匹配结果注入到 prompt 中
  String injectLorebook({
    required String systemPrompt,
    required List<LorebookMatchResult> matches,
  }) {
    if (matches.isEmpty) return systemPrompt;

    final before = matches.where((m) => m.position == 0).map((m) => m.content).join('\n\n');
    final after = matches.where((m) => m.position == 1).map((m) => m.content).join('\n\n');

    final parts = <String>[
      if (before.isNotEmpty) '[Lorebook entries]\n$before',
      systemPrompt,
      if (after.isNotEmpty) '[Lorebook entries]\n$after',
    ];

    return parts.join('\n\n');
  }
}
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Phase 5: Regex 替换系统

### Task 5.1: 正则替换引擎

**Files:**
- Create: `lib/services/regex_service.dart`

- [ ] **Step 1: 实现正则替换**

```dart
// lib/services/regex_service.dart
import '../models/regex_rule.dart';

class RegexService {
  /// 对消息内容应用所有匹配的正则规则
  String applyRules({
    required String content,
    required List<RegexRule> rules,
    required String role, // 'user', 'assistant', 'system'
  }) {
    String result = content;

    for (final rule in rules) {
      if (!rule.enabled) continue;
      // 检查目标角色
      if (rule.targetRoles != null && !rule.targetRoles!.contains(role)) continue;

      try {
        final regex = RegExp(
          rule.pattern,
          caseSensitive: rule.caseSensitive ?? false,
          multiline: rule.multiline ?? true,
        );

        if (rule.isSplit) {
          // 分割模式：按 pattern 分割，对每段应用 replacement
          final parts = result.split(regex);
          result = parts.join(rule.replacement ?? '');
        } else {
          // 替换模式
          result = result.replaceAllMapped(regex, (match) {
            String replacement = rule.replacement ?? '';
            // 替换 $1, $2 等捕获组
            for (var i = 1; i <= match.groupCount; i++) {
              replacement = replacement.replaceAll('\$$i', match.group(i) ?? '');
            }
            return replacement;
          });
        }
      } catch (_) {
        // 正则语法错误，跳过
      }
    }

    return result;
  }
}
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Phase 6: Preset 系统

### Task 6.1: Preset 管理

**Files:**
- Create: `lib/services/preset_service.dart`
- Modify: `lib/models/preset.dart`

- [ ] **Step 1: 实现 Preset 加载和应用**

```dart
// lib/services/preset_service.dart
import '../models/preset.dart';

class PresetService {
  /// 构建最终的 prompt 顺序
  List<PromptEntry> buildPromptOrder({
    required Preset preset,
    required Map<String, String> variables,
  }) {
    final entries = <PromptEntry>[];

    for (final orderEntry in preset.promptOrder) {
      final entry = preset.entries.firstWhere(
        (e) => e.identifier == orderEntry.identifier,
        orElse: () => throw Exception('Prompt entry not found: ${orderEntry.identifier}'),
      );

      if (!entry.enabled || !orderEntry.enabled) continue;

      // 替换变量
      String content = entry.content;
      for (final variable in variables.entries) {
        content = content.replaceAll('{{${variable.key}}}', variable.value);
      }

      entries.add(PromptEntry(
        identifier: entry.identifier,
        name: entry.name,
        content: content,
        role: entry.role,
        marker: entry.marker,
      ));
    }

    return entries;
  }

  /// 合并多个 Preset 的 prompt
  String mergePrompts(List<PromptEntry> entries) {
    return entries.map((e) => e.content).join('\n\n');
  }
}
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Phase 7: 主题系统增强

### Task 7.1: 自定义主题

**Files:**
- Modify: `lib/theme/app_theme.dart`

- [ ] **Step 1: 扩展主题配置**

```dart
// 在 app_theme.dart 中添加自定义主题支持
class TavoTheme {
  final String id;
  final String name;
  final Color primaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textColor;
  final String? backgroundImagePath;
  final ThemeMode mode;

  const TavoTheme({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textColor,
    this.backgroundImagePath,
    this.mode = ThemeMode.system,
  });

  /// 从 JSON 构建
  factory TavoTheme.fromJson(Map<String, dynamic> json) {
    return TavoTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryColor: Color(json['primaryColor'] as int),
      backgroundColor: Color(json['backgroundColor'] as int),
      surfaceColor: Color(json['surfaceColor'] as int),
      textColor: Color(json['textColor'] as int),
      backgroundImagePath: json['backgroundImagePath'] as String?,
      mode: ThemeMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ThemeMode.system,
      ),
    );
  }

  /// 预设主题
  static const defaultThemes = <TavoTheme>[
    TavoTheme(
      id: 'default_light',
      name: '默认浅色',
      primaryColor: Color(0xFF6750A4),
      backgroundColor: Color(0xFFFFFBFE),
      surfaceColor: Color(0xFFF7F2FA),
      textColor: Color(0xFF1C1B1F),
    ),
    TavoTheme(
      id: 'default_dark',
      name: '默认深色',
      primaryColor: Color(0xFFD0BCFF),
      backgroundColor: Color(0xFF1C1B1F),
      surfaceColor: Color(0xFF1C1B1F),
      textColor: Color(0xFFE6E1E5),
    ),
    TavoTheme(
      id: 'sakura',
      name: '樱花粉',
      primaryColor: Color(0xFFE91E63),
      backgroundColor: Color(0xFFFFF0F5),
      surfaceColor: Color(0xFFFFE4EC),
      textColor: Color(0xFF212121),
    ),
    TavoTheme(
      id: 'ocean',
      name: '深海蓝',
      primaryColor: Color(0xFF2196F3),
      backgroundColor: Color(0xFF0D1B2A),
      surfaceColor: Color(0xFF1B2838),
      textColor: Color(0xFFE0E0E0),
    ),
  ];
}
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Phase 8: 数据备份/恢复

### Task 8.1: 导出/导入服务

**Files:**
- Create: `lib/services/backup_service.dart`

- [ ] **Step 1: 实现完整数据导出**

```dart
// lib/services/backup_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/app_database.dart';

class BackupService {
  final AppDatabase _database;

  BackupService(this._database);

  /// 导出所有数据为 JSON
  Future<Map<String, dynamic>> exportAll() async {
    return {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'characters': await _database.getAllCharacters(),
      'conversations': await _database.getAllConversations(),
      'messages': await _database.getAllMessages(),
      'endpoints': await _database.getAllEndpoints(),
      'lorebooks': await _database.getAllLorebooks(),
      'presets': await _database.getAllPresets(),
      'regexRules': await _database.getAllRegexRules(),
      'themes': await _database.getAllThemes(),
      'personas': await _database.getAllPersonas(),
    };
  }

  /// 导出到文件
  Future<String> exportToFile(String path) async {
    final data = await exportAll();
    final file = File(path);
    await file.writeAsString(jsonEncode(data));
    return path;
  }

  /// 从 JSON 恢复数据
  Future<void> importAll(Map<String, dynamic> data) async {
    final version = data['version'] as int? ?? 1;
    // 版本兼容处理
    if (version >= 1) {
      if (data['characters'] != null) {
        for (final char in data['characters'] as List) {
          await _database.saveCharacter(char);
        }
      }
      // ... 其他实体类似
    }
  }

  /// 从文件恢复
  Future<void> importFromFile(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    await importAll(data);
  }

  /// 获取备份文件大小
  Future<int> getBackupSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }
}
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Phase 9: 集成和最终构建

### Task 9.1: 路由注册

**Files:**
- Modify: `lib/route/app_router.dart`

- [ ] **Step 1: 添加新页面路由**

在 app_router.dart 中添加以下路由：

```dart
// 角色导入
GoRoute(
  path: '/character/import',
  builder: (context, state) => const CharacterImportPage(),
),
// Lorebook 管理
GoRoute(
  path: '/lorebook',
  builder: (context, state) => const LorebookListPage(),
),
GoRoute(
  path: '/lorebook/edit/:id?',
  builder: (context, state) => LorebookEditPage(
    lorebookId: state.pathParameters['id'],
  ),
),
// Preset 管理
GoRoute(
  path: '/preset',
  builder: (context, state) => const PresetListPage(),
),
// Regex 管理
GoRoute(
  path: '/regex',
  builder: (context, state) => const RegexListPage(),
),
// 数据备份
GoRoute(
  path: '/settings/backup',
  builder: (context, state) => const BackupPage(),
),
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

### Task 9.2: 最终 Release 构建

- [ ] **Step 1: 全量编译**

Run: `flutter build apk --release --no-tree-shake-icons`
Expected: BUILD SUCCESSFUL, APK ~50MB

- [ ] **Step 2: 签名验证**

Run: `$env:JAVA_HOME = "D:\Documents\Desktop\Virtual\.jdk-tools\jdk-21.0.12+8"; & "$env:JAVA_HOME\bin\jarsigner" -verify "build\app\outputs\flutter-apk\app-release.apk"`
Expected: `jar verified.`

---

## 预估还原度

| 阶段 | 完成后还原度 | 说明 |
|------|------------|------|
| Phase 1 (API多平台) | +15% | 从35%→50% |
| Phase 2 (Prompt引擎) | +10% | 从50%→60% |
| Phase 3 (角色系统) | +5% | 从60%→65% |
| Phase 4 (Lorebook) | +3% | 从65%→68% |
| Phase 5 (Regex) | +2% | 从68%→70% |
| Phase 6 (Preset) | +2% | 从70%→72% |
| Phase 7 (主题) | +2% | 从72%→74% |
| Phase 8 (备份) | +2% | 从74%→76% |
| **总计** | **~76%** | 功能层面接近可用 |

**剩余24%是：**
- UI像素级还原（0%→无法从APK提取）
- 插件系统QuickJS沙盒（需逆向Native层）
- MCP Server完整实现
- 图片生成/识别集成
- 群聊完整交互逻辑

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/models/chat_message.dart';
import 'package:virtual/models/lorebook.dart';
import 'package:virtual/models/persona.dart';
import 'package:virtual/models/preset.dart';
import 'package:virtual/providers/chat_provider.dart';
import 'package:virtual/services/prompt_service.dart';

/// 上下文编译系统两遍拼装 + 图片上传策略 + 开场白宏渲染 的回归防线。
///
/// 三条约定(2026-09-14 与用户对齐):
/// 1. 历史图片绝不随每轮请求重复上传 → 降级为 `[图片]` 文本占位;
///    只有最新一条用户消息的图片真正上传(图片生成场景复用此口径)。
/// 2. system 区 token 用**拼装后的完整文本**估算(含预设/世界书/示例对话),
///    替代旧「字段累加」漏项估算,避免总上下文超窗。
/// 3. 开场白插入消息列表时经 resolvePersona 链渲染 {{user}} 等宏。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Character character({String firstMessage = ''}) => Character(
        id: 'char-1',
        name: '夜织',
        description: '一位沉默的织梦师',
        firstMessage: firstMessage.isEmpty ? null : firstMessage,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  ChatMessage msg(
    String id,
    String role,
    String content, {
    List<MessageAttachment> attachments = const [],
  }) =>
      ChatMessage(
        id: id,
        conversationId: 'conv',
        role: role == 'user' ? MessageRole.user : MessageRole.assistant,
        source: role == 'user' ? MessageSource.user : MessageSource.model,
        variant: MessageVariant.standard,
        content: content,
        attachments: attachments,
        isGenerating: false,
        createdAt: DateTime(2026),
      );

  group('两遍拼装:assembleSystem 覆盖全部 system 大头', () {
    test('system 文本包含预设与示例对话(旧估算完全漏掉的两项)', () {
      final preset = Preset(
        id: 'p1',
        name: '文风预设',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        entries: [
          PresetEntry(
            id: 'e1',
            label: '风格',
            type: PresetEntryType.systemPrompt,
            role: PresetEntryRole.system,
            position: PresetEntryPosition.beforeSystem,
            content: '你将始终保持文言文风格',
            order: 0,
          ),
        ],
      );
      final char = Character(
        id: 'char-1',
        name: '夜织',
        exampleMessages: [
          CharacterExampleMessage(userMessage: '你好', assistantMessage: '……嗯。'),
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final assembled = PromptService.assembleSystem(
        character: char,
        history: const [],
        userMessage: 'hi',
        preset: preset,
      );

      expect(assembled.text, contains('文言文风格'));
      expect(assembled.text, contains('对话示例'));
      expect(assembled.text, contains('……嗯。'));
    });

    test('buildMessages(assembled) 与 buildMessages(lorebook) 输出一致', () {
      final book = Lorebook(
        id: 'b1',
        name: '测试书',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        entries: [
          LorebookEntry(
            id: 'e1',
            key: '织梦',
            content: '织梦师是古老职业',
            constant: true,
          ),
        ],
      );
      final char = character();
      final history = [msg('m1', 'user', '说起织梦')];

      final assembled = PromptService.assembleSystem(
        character: char,
        history: history,
        userMessage: '继续',
        lorebook: book,
      );
      final viaAssembled = PromptService.buildMessages(
        character: char,
        history: history,
        userMessage: '继续',
        assembled: assembled,
      );
      final viaDirect = PromptService.buildMessages(
        character: char,
        history: history,
        userMessage: '继续',
        lorebook: book,
      );

      expect(viaAssembled.first['content'], viaDirect.first['content']);
      expect(viaAssembled.first['content'], contains('织梦师是古老职业'));
    });

    test('estimateSystemTokens 把预设/示例计入(旧字段累加估算会漏掉)', () {
      final preset = Preset(
        id: 'p1',
        name: '大预设',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        entries: [
          PresetEntry(
            id: 'e1',
            label: '长文本',
            type: PresetEntryType.systemPrompt,
            role: PresetEntryRole.system,
            position: PresetEntryPosition.beforeSystem,
            content: 'x' * 2000,
            order: 0,
          ),
        ],
      );
      final assembled = PromptService.assembleSystem(
        character: character(),
        history: const [],
        userMessage: 'hi',
        preset: preset,
      );

      expect(PromptService.estimateSystemTokens(assembled), greaterThan(1000));
    });
  });

  group('图片上传策略', () {
    test('历史消息中的图片降级为 [图片] 占位,不产生 image_url', () {
      final history = [
        msg('m1', 'user', '看这张图', attachments: [
          MessageAttachment(
            id: 'a1',
            type: MessageAttachmentType.image,
            path: '/nonexistent/old.png',
          ),
        ]),
        msg('m2', 'assistant', '好的'),
      ];
      final messages = PromptService.buildMessages(
        character: character(),
        history: history,
        userMessage: '继续',
      );

      final historyTexts = messages
          .skip(1)
          .take(2)
          .map((m) => m['content'])
          .whereType<String>()
          .toList();
      expect(historyTexts[0], contains('[图片]'));
      expect(jsonEncode(messages), isNot(contains('image_url')));
    });

    test('最新用户消息的图片随本次请求上传一次(data URL)', () {
      final tmp = File(
          '${Directory.systemTemp.createTempSync('ctx').path}${Platform.pathSeparator}pic.png')
        ..writeAsBytesSync(List<int>.filled(8, 1));
      addTearDown(() {
        try {
          tmp.parent.deleteSync(recursive: true);
        } catch (_) {}
      });

      final messages = PromptService.buildMessages(
        character: character(),
        history: const [],
        userMessage: '这是什么',
        userAttachments: [
          MessageAttachment(
            id: 'a1',
            type: MessageAttachmentType.image,
            path: tmp.path,
          ),
        ],
      );

      final last = messages.last;
      expect(last['role'], 'user');
      final parts = last['content'] as List;
      expect(parts.first['type'], 'text');
      expect(
        (parts.last['image_url'] as Map)['url'],
        startsWith('data:image/png'),
      );
    });

    test('最新消息图片全部读取失败时保底发文本,用户消息不消失', () {
      final messages = PromptService.buildMessages(
        character: character(),
        history: const [],
        userMessage: '',
        userAttachments: [
          MessageAttachment(
            id: 'a1',
            type: MessageAttachmentType.image,
            path: '/nonexistent/x.png',
          ),
        ],
      );

      final last = messages.last;
      expect(last['role'], 'user');
      expect(last['content'], isA<String>());
    });
  });

  group('开场白宏渲染', () {
    test('renderGreeting:{{user}} 用 persona 名,{{char}} 用角色名', () {
      final char = character(firstMessage: '{{user}} 你好,我是 {{char}}。');
      final out = PromptService.renderGreeting(
        character: char,
        persona: Persona(
          id: 'p1',
          name: '阿澈',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      expect(out, '阿澈 你好,我是 夜织。');
    });

    test('loadMessages 插入开场白时已经渲染宏(账号昵称兜底)', () async {
      SharedPreferences.setMockInitialValues({});
      final db = await AppDatabase.init();
      for (final p in db.getPersonas()) {
        await db.deletePersona(p.id);
      }
      final provider = ChatProvider(db);
      provider.updateDependenciesForTest(userNickname: '阿澈');

      final char = Character(
        id: 'char-greet',
        name: '夜织',
        firstMessage: '{{user}},欢迎来到织梦屋。',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await db.saveCharacter(char);
      final conv = await provider.createConversation(characterId: char.id);
      await provider.loadMessages(conv.id);

      expect(provider.messages, isNotEmpty);
      expect(provider.messages.first.content, '阿澈,欢迎来到织梦屋。');
    });
  });
}

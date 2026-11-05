import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/models/chat_message.dart';
import 'package:virtual/services/local_prompt_builder.dart';

/// 假 tokenizer：按字符数计数（1 字符 = 1 token），便于稳定断言。
Future<int> fakeCount(String text) async => text.runes.length;

ChatMessage _msg(String role, String content, int index) => ChatMessage(
      id: 'm$index',
      conversationId: 'c1',
      role: role == 'user' ? MessageRole.user : MessageRole.assistant,
      content: content,
      createdAt: DateTime(2026, 1, 1, 0, 0, index),
    );

Character _character({
  String description = '一名谨慎的助理。',
  String personality = '冷淡、克制。',
  String? scenario,
}) =>
    Character(
      id: 'char-1',
      name: '刘岚',
      description: description,
      personality: personality,
      scenario: scenario,
      systemPrompt: null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('LocalPromptBuilder', () {
    test('超长角色卡被压缩到 ≤300 token，且不再包含整张卡', () async {
      final character = _character(
        description: '设定正文' * 2000, // 8000 字
        personality: '性格描述' * 500, // 2000 字
        scenario: '场景描述' * 500, // 2000 字
      );

      final plan = await LocalPromptBuilder.build(
        character: character,
        history: const [],
        userMessage: '你是谁',
        countTokens: fakeCount,
        contextSize: 4096,
        maxTokens: 768,
      );

      expect(plan.systemTokens, lessThanOrEqualTo(300));
      expect(plan.systemPrompt.length, lessThanOrEqualTo(300));
      expect(plan.systemPrompt, contains('刘岚'));
      // 整张卡 12000 字，压缩后必须远小于原文
      expect(plan.systemPrompt.length, lessThan(2000));
    });

    test('极短输入（≤6 字）追加澄清提示', () async {
      final plan = await LocalPromptBuilder.build(
        character: _character(),
        history: const [],
        userMessage: '你是',
        countTokens: fakeCount,
        contextSize: 4096,
        maxTokens: 768,
      );

      expect(plan.shortInput, isTrue);
      expect(plan.currentTurn['content'], contains('用户只说了很短的几个字'));
      expect(plan.currentTurn['content'], contains('你是'));
      expect(plan.currentTurn['content'], contains('直接回应用户这句话'));
      // 提示必须在用户原文之后（顺序固定：用户输入 → 本轮指令）
      final inputIndex = plan.currentTurn['content']!.indexOf('你是');
      final hintIndex =
          plan.currentTurn['content']!.indexOf('用户只说了很短的几个字');
      expect(hintIndex, greaterThan(inputIndex));

      // 正常长度输入不带短输入提示
      final long = await LocalPromptBuilder.build(
        character: _character(),
        history: const [],
        userMessage: '今天天气不错，我们出去走走吧',
        countTokens: fakeCount,
        contextSize: 4096,
        maxTokens: 768,
      );
      expect(long.shortInput, isFalse);
      expect(long.currentTurn['content'], isNot(contains('用户只说了很短的几个字')));
    });

    test('历史超过 4 轮时只保留最近 4 轮，system 始终保留', () async {
      final history = <ChatMessage>[];
      for (var i = 0; i < 6; i++) {
        history.add(_msg('user', '第$i轮问题', i * 2));
        history.add(_msg('assistant', '第$i轮回答', i * 2 + 1));
      }

      final plan = await LocalPromptBuilder.build(
        character: _character(),
        history: history,
        userMessage: '新问题',
        countTokens: fakeCount,
        contextSize: 4096,
        maxTokens: 768,
      );

      expect(plan.history.length, 8); // 4 轮 × 2 条
      expect(plan.droppedMessages, 4); // 丢掉最老 2 轮
      expect(plan.history.first['content'], '第2轮问题');
      expect(plan.history.last['content'], '第5轮回答');
      expect(plan.systemPrompt, isNotEmpty);
      expect(plan.systemTokens, greaterThan(0));
    });

    test('裁剪按整轮进行，不切断 user/assistant 配对', () async {
      final history = <ChatMessage>[];
      for (var i = 0; i < 5; i++) {
        history.add(_msg('user', '问题$i', i * 2));
        history.add(_msg('assistant', '回答$i', i * 2 + 1));
      }

      final plan = await LocalPromptBuilder.build(
        character: _character(),
        history: history,
        userMessage: '继续',
        countTokens: fakeCount,
        contextSize: 4096,
        maxTokens: 768,
      );

      // 保留段必须以 user 开头，且 user/assistant 严格成对出现
      expect(plan.history.first['role'], 'user');
      for (var i = 0; i < plan.history.length; i += 2) {
        expect(plan.history[i]['role'], 'user');
        if (i + 1 < plan.history.length) {
          expect(plan.history[i + 1]['role'], 'assistant');
          // 同一轮内容必须来自同一序号（配对未被切断）
          final userText = plan.history[i]['content']!;
          final assistantText = plan.history[i + 1]['content']!;
          expect(userText.replaceAll('问题', ''), assistantText.replaceAll('回答', ''));
        }
      }
    });
  });
}

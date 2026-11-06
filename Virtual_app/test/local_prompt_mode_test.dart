import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/models/chat_message.dart';
import 'package:virtual/models/endpoint.dart';
import 'package:virtual/services/local_prompt_builder.dart';

Future<int> _fakeCount(String text) async => text.runes.length;

ChatMessage _msg(String role, String content, int index) => ChatMessage(
      id: 'm$index',
      conversationId: 'c1',
      role: role == 'user' ? MessageRole.user : MessageRole.assistant,
      content: content,
      createdAt: DateTime(2026, 1, 1, 0, 0, index),
    );

Character _character() => Character(
      id: 'char-1',
      name: '刘岚',
      description: '一名谨慎的助理。',
      personality: '冷淡、克制。',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

LlmEndpoint _endpoint({
  EndpointMode mode = EndpointMode.deploy,
  LocalPromptMode promptMode = LocalPromptMode.concise,
}) => LlmEndpoint(
      id: 'e1',
      name: '本地端',
      platform: 'openai',
      baseUrl: '',
      apiKey: '',
      mode: mode,
      localPromptMode: promptMode,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('提示词模式选择', () {
    test('默认精简；部署端点可切完整', () {
      expect(_endpoint().localPromptMode, LocalPromptMode.concise);
      expect(_endpoint().usesFullLocalPrompt, isFalse);
      expect(
        _endpoint(promptMode: LocalPromptMode.full).usesFullLocalPrompt,
        isTrue,
      );
      // 接入型端点即使字段是 full 也不走本地完整路径
      expect(
        _endpoint(mode: EndpointMode.access, promptMode: LocalPromptMode.full)
            .usesFullLocalPrompt,
        isFalse,
      );
    });

    test('JSON 往返保留模式；旧数据无字段回落精简', () {
      final full = _endpoint(promptMode: LocalPromptMode.full);
      final decoded = LlmEndpoint.fromJson(full.toJson());
      expect(decoded.localPromptMode, LocalPromptMode.full);
      expect(decoded.usesFullLocalPrompt, isTrue);

      final legacy = full.toJson()..remove('localPromptMode');
      final legacyEndpoint = LlmEndpoint.fromJson(legacy);
      expect(legacyEndpoint.localPromptMode, LocalPromptMode.concise);
    });
  });

  group('精简模式：用户输入不被裁剪', () {
    test('极小上下文下仍完整保留用户最新输入', () async {
      // ctx 很小，历史预算被压到下限，且本轮内容远超预算
      const contextSize = 512;
      const maxTokens = 460;
      const input = '请用一句话告诉我，你刚才为什么把茶杯放在了窗边那个旧木架上？'
          '我想知道具体原因，而不是笼统的设定复述，也不要替我回答。';

      final history = [
        for (var i = 0; i < 12; i++)
          _msg(i.isEven ? 'user' : 'assistant', '历史消息 $i：${'内容' * 40}', i),
      ];

      final plan = await LocalPromptBuilder.build(
        character: _character(),
        history: history,
        userMessage: input,
        countTokens: _fakeCount,
        contextSize: contextSize,
        maxTokens: maxTokens,
      );

      // 用户原文必须 1:1 完整保留（后面只允许追加本轮指令）
      expect(plan.currentTurn['role'], 'user');
      expect(plan.currentTurn['content'], startsWith(input));
      expect(plan.currentTurn['content'], contains(LocalPromptBuilder.turnInstruction));
      // 历史被裁剪，但 system 与历史是分离的
      expect(plan.history.length, lessThan(history.length));
      expect(plan.systemPrompt, isNotEmpty);
      expect(plan.history.any((m) => m['role'] == 'user' || m['role'] == 'assistant'), isTrue);
      expect(plan.history.any((m) => m['role'] == 'system'), isFalse);
    });

    test('只保留最近 4 轮历史（8 条以内）', () async {
      final history = [
        for (var i = 0; i < 12; i++)
          _msg(i.isEven ? 'user' : 'assistant', '第 $i 条短消息', i),
      ];

      final plan = await LocalPromptBuilder.build(
        character: _character(),
        history: history,
        userMessage: '继续说',
        countTokens: _fakeCount,
        contextSize: 8192,
        maxTokens: 512,
      );

      expect(plan.history.length, lessThanOrEqualTo(LocalPromptBuilder.recentTurns * 2));
      // 保留的是最新一段，而不是最早的
      expect(plan.history.last['content'], contains('第 11 条'));
    });
  });
}

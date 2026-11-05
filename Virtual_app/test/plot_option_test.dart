import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/models/chat_message.dart';
import 'package:virtual/providers/chat_provider.dart';
import 'package:virtual/services/chat_action_policy.dart';
import 'package:virtual/services/plot_option_parser.dart';
import 'package:virtual/services/prompt_service.dart';

/// 记录 sendMessage 入参的测试用 Provider：验证「点选项 = 原样发送」。
class _RecordingChatProvider extends ChatProvider {
  _RecordingChatProvider() : super(AppDatabase.instance);

  final List<String> sent = [];

  @override
  Future<bool> sendMessage(String content,
      {List<String>? images, bool hidden = false}) async {
    sent.add(content);
    return true;
  }
}

/// 「剧情选项 + 继续生成」的回归防线。
///
/// 三条约定（与用户对齐）：
/// 1. 选项请求输出严格 JSON，但必须能容忍代码块/编号/引号等噪声（三级降级）；
/// 2. 点击选项 = 普通用户消息，走同一条 sendMessage 链路；
/// 3. 「继续」写入隐藏消息：界面不渲染，但必须进入上下文。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
  });

  ChatMessage msg(
    String id,
    MessageRole role,
    String content, {
    bool isHidden = false,
    bool isError = false,
    bool isGenerating = false,
  }) =>
      ChatMessage(
        id: id,
        conversationId: 'conv',
        role: role,
        source: role == MessageRole.user
            ? MessageSource.user
            : MessageSource.model,
        variant: MessageVariant.standard,
        content: content,
        isHidden: isHidden,
        isError: isError,
        isGenerating: isGenerating,
        createdAt: DateTime(2026),
      );

  group('选项 JSON 解析', () {
    test('严格 JSON：取全部 options', () {
      final list = parsePlotOptions('{"options":["我要拔剑","我要后退","我要谈判"]}');
      expect(list, ['我要拔剑', '我要后退', '我要谈判']);
    });

    test('```json 代码块包裹也能解析', () {
      final list = parsePlotOptions(
        '```json\n{"options":["我要推门进去","我要敲窗试探","我要绕到后院"]}\n```',
      );
      expect(list, hasLength(3));
      expect(list.first, '我要推门进去');
    });

    test('JSON 解析失败 → 按行/编号降级', () {
      final list = parsePlotOptions('1. 我要先观察四周\n2. 我要直接问他\n3. 我要转身离开');
      expect(list, ['我要先观察四周', '我要直接问他', '我要转身离开']);
    });

    test('单行编号也能拆成多条', () {
      final list = parsePlotOptions('1. 我要点火把 2. 我要找同伴 3. 我要躲起来');
      expect(list, ['我要点火把', '我要找同伴', '我要躲起来']);
    });

    test('项目符号与引号会被清洗', () {
      final list = parsePlotOptions('- “我要留下来”\n- 「我要追出去」\n- “我要先冷静”');
      expect(list, ['我要留下来', '我要追出去', '我要先冷静']);
    });

    test('最多 3 条且去重', () {
      final list = parsePlotOptions(
        '1. 我要等待\n2. 我要等待\n3. 我要离开\n4. 我要战斗',
      );
      expect(list, ['我要等待', '我要离开', '我要战斗']);
    });

    test('全部失败返回空列表（上层提示重试）', () {
      expect(parsePlotOptions(''), isEmpty);
      expect(parsePlotOptions('……'), isEmpty);
      expect(parsePlotOptions('抱歉，我无法生成选项。'), isEmpty);
    });
  });

  group('继续生成按钮显示条件', () {
    test('最后一条是已完成 AI 回复才显示', () {
      final ai = msg('a1', MessageRole.assistant, '……');
      expect(canActOnLastReply([ai], isGenerating: false), isTrue);
    });

    test('最后一条是用户消息时不显示', () {
      final user = msg('u1', MessageRole.user, '你好');
      expect(canActOnLastReply([user], isGenerating: false), isFalse);
    });

    test('生成中 / 错误气泡 / 空列表都不显示', () {
      final ai = msg('a1', MessageRole.assistant, '……');
      expect(canActOnLastReply([ai], isGenerating: true), isFalse);
      final err = msg('e1', MessageRole.assistant, '生成失败', isError: true);
      expect(canActOnLastReply([err], isGenerating: false), isFalse);
      final placeholder =
          msg('p1', MessageRole.assistant, '', isGenerating: true);
      expect(canActOnLastReply([placeholder], isGenerating: false), isFalse);
      expect(canActOnLastReply(const [], isGenerating: false), isFalse);
    });
  });

  group('选项点击 = 普通发送', () {
    test('sendPlotOption 原样把选项文字交给 sendMessage', () async {
      final provider = _RecordingChatProvider();
      final ok = await provider.sendPlotOption('我要拔剑');
      expect(ok, isTrue);
      expect(provider.sent, ['我要拔剑']);
    });
  });

  group('隐藏消息约定', () {
    test('isHidden 默认 false，JSON 往返保持隐藏标记', () {
      final normal = msg('m1', MessageRole.user, '普通消息');
      expect(normal.isHidden, isFalse);

      final hidden = msg('m2', MessageRole.user, kContinueInstruction,
          isHidden: true);
      final restored = ChatMessage.fromJson(hidden.toJson());
      expect(restored.isHidden, isTrue);
      expect(restored.content, kContinueInstruction);
    });

    test('隐藏指令进入 Prompt，但不属于可见渲染列表', () {
      final visible = [
        msg('u1', MessageRole.user, '我推开门'),
        msg('a1', MessageRole.assistant, '门后是一片黑暗。'),
        msg('h1', MessageRole.user, kContinueInstruction, isHidden: true),
      ];
      final rendered = visible.where((m) => !m.isHidden).toList();
      expect(rendered, hasLength(2));
      expect(rendered.map((m) => m.content), isNot(contains(kContinueInstruction)));

      final character = Character(
        id: 'char-1',
        name: '夜织',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final messages = PromptService.buildMessages(
        character: character,
        history: visible,
        userMessage: '我继续往里走',
      );
      expect(
        messages.any((m) => m['content'] == kContinueInstruction),
        isTrue,
        reason: '隐藏指令必须在上下文里，否则「继续」不生效',
      );
      expect(
        messages.any((m) => m['content'] == '我继续往里走'),
        isTrue,
      );
    });
  });
}

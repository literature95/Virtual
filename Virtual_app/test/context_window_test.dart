import 'package:flutter_test/flutter_test.dart';

import 'package:virtual/models/chat_message.dart';
import 'package:virtual/services/context_window_service.dart';

ChatMessage msg(
  String id,
  MessageRole role,
  String content, {
  int minutesOffset = 0,
  String? reasoning,
}) =>
    ChatMessage(
      id: id,
      conversationId: 'c1',
      role: role,
      content: content,
      reasoning: reasoning,
      isGenerating: false,
      createdAt: DateTime(2026, 9, 14, 8, 0 + minutesOffset),
    );

void main() {
  group('estimateTokens', () {
    test('中文按 2 字符 ≈ 1 token 保守估算', () {
      expect(ContextWindowService.estimateTokens('12345678'), 4);
      expect(ContextWindowService.estimateTokens('a'), 1);
      expect(ContextWindowService.estimateTokens(''), 0);
    });
  });

  group('trim 滑动窗口', () {
    test('全部在预算内：原样保留', () {
      final history = [
        msg('u1', MessageRole.user, '你好'),
        msg('a1', MessageRole.assistant, '你好呀'),
      ];
      final out = ContextWindowService.trim(
        history,
        maxTokens: 1000,
        reservedForSystem: 100,
        reservedForReply: 100,
      );
      expect(out.map((m) => m.id), ['u1', 'a1']);
    });

    test('超预算：从最新往旧保留，旧端对齐到 user 开始', () {
      final history = [
        msg('u1', MessageRole.user, '一' * 20),
        msg('a1', MessageRole.assistant, '二' * 20),
        msg('u2', MessageRole.user, '三' * 20),
        msg('a2', MessageRole.assistant, '四' * 20),
        msg('u3', MessageRole.user, '五' * 20),
      ];
      // 每条 10 token；预算 30 → 从新往旧 u3+a2+u2 恰好 30 token，
      // u1 挤不下；旧端 u2 是 user 消息，无需对齐丢弃
      final out = ContextWindowService.trim(
        history,
        maxTokens: 30,
        reservedForSystem: 0,
        reservedForReply: 0,
      );
      expect(out.map((m) => m.id), ['u2', 'a2', 'u3']);
    });

    test('旧端为 assistant 时对齐丢弃到 user 开始', () {
      final history = [
        msg('u1', MessageRole.user, '一' * 20),
        msg('a1', MessageRole.assistant, '二' * 20),
        msg('u2', MessageRole.user, '三' * 20),
        msg('a2', MessageRole.assistant, '四' * 20),
        msg('u3', MessageRole.user, '五' * 20),
      ];
      // 预算 20 → 从新往旧 u3+a2=20；旧端 a2 非 user → 对齐丢弃 → 只剩 u3
      final out = ContextWindowService.trim(
        history,
        maxTokens: 20,
        reservedForSystem: 0,
        reservedForReply: 0,
      );
      expect(out.map((m) => m.id), ['u3']);
    });

    test('对齐后仍以 user 开头：成对保留多轮', () {
      final history = [
        msg('u1', MessageRole.user, 'a' * 20),
        msg('a1', MessageRole.assistant, 'b' * 20),
        msg('u2', MessageRole.user, 'c' * 20),
        msg('a2', MessageRole.assistant, 'd' * 20),
      ];
      // 预算 30 token：从新往旧 a2(10)+u2(10)+a1(10)=30 全塞进，
      // 但旧端 a1 非 user → 丢 → 剩 u2+a2
      final out = ContextWindowService.trim(
        history,
        maxTokens: 30,
        reservedForSystem: 0,
        reservedForReply: 0,
      );
      expect(out.map((m) => m.id), ['u2', 'a2']);
    });

    test('单条独超预算：截断最新一条 content 前缀兜底', () {
      final history = [msg('u1', MessageRole.user, '长' * 1000)];
      final out = ContextWindowService.trim(
        history,
        maxTokens: 20,
        reservedForSystem: 0,
        reservedForReply: 0,
      );
      expect(out, hasLength(1));
      expect(out.single.content.length, 40); // 20 token × 2 字符
    });

    test('预算被 system 挤到 ≤0：返回空', () {
      final history = [msg('u1', MessageRole.user, 'hello')];
      final out = ContextWindowService.trim(
        history,
        maxTokens: 100,
        reservedForSystem: 1000,
      );
      expect(out, isEmpty);
    });

    test('reasoning 也计入成本', () {
      final history = [
        msg('u1', MessageRole.user, 'x' * 20),
        msg('a1', MessageRole.assistant, '', reasoning: 'y' * 20),
        msg('u2', MessageRole.user, 'z' * 20),
      ];
      // 三条各 10 token（a1 的 reasoning 计入成本），预算 30 恰好全装下；
      // 若 reasoning 不计成本，a1 只算 0 token，这里就无法验证差异——
      // 换预算 25：从新往旧 u2(10)+a1(10)=20，u1 挤不下 → 只剩 u2
      final out = ContextWindowService.trim(
        history,
        maxTokens: 25,
        reservedForSystem: 0,
        reservedForReply: 0,
      );
      expect(out.map((m) => m.id), ['u2']);
    });
  });
}

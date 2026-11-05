import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:virtual/services/conversation_request_lock.dart';
import 'package:virtual/services/retry_policy.dart';

/// 上游 429 / 5xx 重试策略与「同一对话串行」锁的回归防线。
///
/// 背景：免费模型档同账号并发为 1，旧实现重试间隔过密（1s/2s/2s），
/// 相当于连续撞同一限流窗口。这里钉死可重试清单、退避表、Retry-After
/// 优先级与最大尝试次数，避免日后被“顺手优化”改回高频重试。
void main() {
  group('RetryPolicy 可重试判定', () {
    test('429 重试，首次等待为 2s ±20%', () {
      final d = RetryPolicy.decide(
        attempt: 1,
        statusCode: 429,
        random: Random(42),
      );
      expect(d.shouldRetry, isTrue);
      expect(d.delay.inMilliseconds, inInclusiveRange(1600, 2400));
      expect(d.usedRetryAfter, isFalse);
    });

    test('400 / 401 / 403 / 404 / 422 不重试', () {
      for (final code in [400, 401, 403, 404, 422]) {
        final d = RetryPolicy.decide(attempt: 1, statusCode: code);
        expect(d.shouldRetry, isFalse, reason: 'HTTP $code 不应重试');
      }
    });

    test('500 / 502 / 503 / 504 重试，其余 5xx 不重试', () {
      for (final code in [500, 502, 503, 504]) {
        expect(
          RetryPolicy.decide(attempt: 1, statusCode: code).shouldRetry,
          isTrue,
          reason: 'HTTP $code 应重试',
        );
      }
      expect(RetryPolicy.decide(attempt: 1, statusCode: 501).shouldRetry,
          isFalse);
    });

    test('超时与网络中断重试', () {
      expect(
        RetryPolicy.decide(
          attempt: 1,
          category: UpstreamErrorCategory.timeout,
        ).shouldRetry,
        isTrue,
      );
      expect(
        RetryPolicy.decide(
          attempt: 1,
          category: UpstreamErrorCategory.network,
        ).shouldRetry,
        isTrue,
      );
    });

    test('最多 4 次尝试：第 4 次失败后不再重试', () {
      expect(RetryPolicy.maxAttempts, 4);
      expect(
        RetryPolicy.decide(attempt: 3, statusCode: 429).shouldRetry,
        isTrue,
        reason: '第 3 次重试仍允许（总共第 4 次尝试）',
      );
      expect(
        RetryPolicy.decide(attempt: 4, statusCode: 429).shouldRetry,
        isFalse,
      );
    });
  });

  group('RetryPolicy 退避与 Retry-After', () {
    test('退避表为 2s / 6s / 15s，抖动不超过 ±20%', () {
      final expected = [2, 6, 15];
      for (var i = 0; i < expected.length; i++) {
        final attempt = i + 1;
        for (final seed in [1, 2, 3]) {
          final d = RetryPolicy.decide(
            attempt: attempt,
            statusCode: 429,
            random: Random(seed),
          );
          final baseMs = expected[i] * 1000;
          expect(
            d.delay.inMilliseconds,
            inInclusiveRange(
              (baseMs * 0.8).round(),
              (baseMs * 1.2).round(),
            ),
            reason: '第 $attempt 次重试应围绕 ${expected[i]}s',
          );
        }
      }
    });

    test('抖动实际覆盖 ±20% 区间的两端', () {
      var minMs = 1 << 30;
      var maxMs = 0;
      final rnd = Random(20261104);
      for (var i = 0; i < 500; i++) {
        final d = RetryPolicy.decide(
          attempt: 1,
          statusCode: 429,
          random: rnd,
        );
        final ms = d.delay.inMilliseconds;
        if (ms < minMs) minMs = ms;
        if (ms > maxMs) maxMs = ms;
      }
      expect(minMs, lessThanOrEqualTo(1700));
      expect(maxMs, greaterThanOrEqualTo(2300));
      expect(minMs, greaterThanOrEqualTo(1600));
      expect(maxMs, lessThanOrEqualTo(2400));
    });

    test('响应头 Retry-After 优先于指数退避', () {
      final d = RetryPolicy.decide(
        attempt: 1,
        statusCode: 429,
        retryAfter: const Duration(seconds: 10),
        random: Random(1),
      );
      expect(d.shouldRetry, isTrue);
      expect(d.usedRetryAfter, isTrue);
      expect(d.delay, const Duration(seconds: 10));
    });

    test('Retry-After 上限 30 秒', () {
      final d = RetryPolicy.decide(
        attempt: 1,
        statusCode: 429,
        retryAfter: const Duration(seconds: 120),
      );
      expect(d.delay, const Duration(seconds: 30));
    });

    test('parseRetryAfterHeader 解析秒数并钳制到 1–30 秒', () {
      expect(parseRetryAfterHeader('8'), const Duration(seconds: 8));
      expect(parseRetryAfterHeader('0'), const Duration(seconds: 1));
      expect(parseRetryAfterHeader('999'), const Duration(seconds: 30));
      expect(parseRetryAfterHeader(null), isNull);
      expect(parseRetryAfterHeader('Wed, 21 Oct 2015 07:28:00 GMT'), isNull,
          reason: 'HTTP-date 形式不在支持范围，回落到退避');
    });
  });

  group('错误归类', () {
    test('免费模型 Too many requests 纯文本也判为限流', () {
      expect(
        classifyMessage('Too many requests for this free model'),
        UpstreamErrorCategory.throttled,
      );
      expect(
        classifyMessage('reached max organization concurrency: 1'),
        UpstreamErrorCategory.throttled,
      );
    });

    test('4xx 文本不误判为可重试', () {
      expect(
        classifyMessage('invalid temperature: only 1 is allowed'),
        UpstreamErrorCategory.unknown,
      );
    });

    test('HTTP 状态码归类', () {
      expect(categoryFromStatus(429), UpstreamErrorCategory.throttled);
      expect(categoryFromStatus(503), UpstreamErrorCategory.server);
      expect(categoryFromStatus(400), UpstreamErrorCategory.client);
      expect(categoryFromStatus(401), UpstreamErrorCategory.client);
    });

    test('LlmRequestException 只把限流/5xx/超时/网络视为可重试', () {
      const throttled = LlmRequestException(
        message: 'too many requests',
        category: UpstreamErrorCategory.throttled,
        statusCode: 429,
      );
      const client = LlmRequestException(
        message: 'bad request',
        category: UpstreamErrorCategory.client,
        statusCode: 400,
      );
      expect(throttled.isRetryable, isTrue);
      expect(client.isRetryable, isFalse);
      expect(throttled.toString(), 'too many requests');
    });
  });

  group('同一对话并发锁', () {
    test('同一对话二次占锁被拦截，释放后可再次获取', () {
      final lock = ConversationRequestLock();
      expect(lock.tryAcquire('conv-1'), isTrue);
      expect(lock.isLocked('conv-1'), isTrue);

      expect(lock.tryAcquire('conv-1'), isFalse);
      expect(lock.activeCount, 1);

      lock.release('conv-1');
      expect(lock.isLocked('conv-1'), isFalse);
      expect(lock.tryAcquire('conv-1'), isTrue);
    });

    test('不同对话可并行占锁（不存在全局并发上限）', () {
      final lock = ConversationRequestLock();
      expect(lock.tryAcquire('conv-a'), isTrue);
      expect(lock.tryAcquire('conv-b'), isTrue);
      expect(lock.activeCount, 2);
    });

    test('run 正常完成后 finally 释放锁', () async {
      final lock = ConversationRequestLock();
      final result = await lock.run('conv-2', () async => 42);
      expect(result, 42);
      expect(lock.isLocked('conv-2'), isFalse);
    });

    test('run 内抛异常时 finally 仍释放锁', () async {
      final lock = ConversationRequestLock();
      await expectLater(
        lock.run<void>('conv-3', () async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      expect(lock.isLocked('conv-3'), isFalse);
      // 异常路径没有泄漏：同一对话可以继续发起下一次请求
      expect(lock.tryAcquire('conv-3'), isTrue);
    });

    test('并发 run 同一对话：第二个立即被拒绝', () async {
      final lock = ConversationRequestLock();
      final gate = Completer<void>();
      final first = lock.run('conv-4', () => gate.future);
      await expectLater(
        lock.run<void>('conv-4', () async {}),
        throwsA(isA<ConversationBusyException>()),
      );
      gate.complete();
      await first;
      expect(lock.isLocked('conv-4'), isFalse);
    });
  });
}

import 'dart:math';

import 'package:dio/dio.dart';

import 'adapters/llm_adapter.dart';

/// 上游错误的可重试类别。
///
/// 只有 [throttled]、[server]、[timeout]、[network] 四类会触发自动重试；
/// 其余 4xx（400/401/403/404/422 等）属于请求本身有问题，重发只会浪费额度。
enum UpstreamErrorCategory {
  /// 429 / 并发已满 / rate limit：稍等后可恢复
  throttled,

  /// 500 / 502 / 503 / 504：上游临时故障
  server,

  /// 连接 / 发送 / 接收超时
  timeout,

  /// 网络中断、DNS、连接被重置等
  network,

  /// 4xx 请求错误（参数、鉴权、路径、语义不合法）
  client,

  /// 无法归类：保守起见不重试
  unknown,
}

/// 上游请求异常：在可读错误信息之外，附带重试决策所需的结构化信息。
///
/// 适配器此前统一 `throw Exception(message)`，导致上层只能猜文本。
/// 这里保留原始信息（[message]），同时携带 HTTP 状态码与 `Retry-After`。
class LlmRequestException implements Exception {
  final String message;
  final int? statusCode;
  final Duration? retryAfter;
  final UpstreamErrorCategory category;

  const LlmRequestException({
    required this.message,
    required this.category,
    this.statusCode,
    this.retryAfter,
  });

  bool get isRetryable =>
      category == UpstreamErrorCategory.throttled ||
      category == UpstreamErrorCategory.server ||
      category == UpstreamErrorCategory.timeout ||
      category == UpstreamErrorCategory.network;

  @override
  String toString() => message;
}

/// 已收到首 token 后生成中断：不自动重试，直接告知用户。
class GenerationInterruptedException implements Exception {
  final String message;

  const GenerationInterruptedException(this.message);

  @override
  String toString() => message;
}

/// 把 [DioException] 转成带状态码 / `Retry-After` 的结构化异常。
///
/// 消息解析复用各适配器的 [extractDioErrorMessage]（流式响应需先读 ResponseBody）。
Future<LlmRequestException> createLlmRequestException(DioException e) async {
  final message = await extractDioErrorMessage(e);
  final headers = e.response?.headers;
  return LlmRequestException(
    message: message,
    statusCode: e.response?.statusCode,
    retryAfter: parseRetryAfterHeader(headers?.value('retry-after')),
    category: classifyDioException(e, message),
  );
}

/// HTTP 状态码 → 错误类别（判定规则以任务约定为准）。
UpstreamErrorCategory categoryFromStatus(int status) {
  if (status == 429) return UpstreamErrorCategory.throttled;
  if (status == 500 ||
      status == 502 ||
      status == 503 ||
      status == 504) {
    return UpstreamErrorCategory.server;
  }
  if (status >= 400) return UpstreamErrorCategory.client;
  return UpstreamErrorCategory.unknown;
}

/// Dio 异常类型 + 错误文本 → 错误类别。
UpstreamErrorCategory classifyDioException(DioException e, [String message = '']) {
  final status = e.response?.statusCode;
  if (status != null) return categoryFromStatus(status);

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return UpstreamErrorCategory.timeout;
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return UpstreamErrorCategory.network;
    case DioExceptionType.cancel:
      return UpstreamErrorCategory.client;
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }
  return classifyMessage(message);
}

/// 仅凭错误文本归类（兼容被包装成普通 Exception 的场景）。
///
/// 免费模型常见的 `Too many requests for this free model` 即使拿不到
/// 状态码，也必须判成限流，否则会退化成「直接报错、不等待」。
UpstreamErrorCategory classifyMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('429') ||
      lower.contains('too many requests') ||
      lower.contains('rate limit') ||
      lower.contains('ratelimit') ||
      lower.contains('concurrency')) {
    return UpstreamErrorCategory.throttled;
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return UpstreamErrorCategory.timeout;
  }
  if (lower.contains('connection') ||
      lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('网络错误') ||
      lower.contains('connection error')) {
    return UpstreamErrorCategory.network;
  }
  if (lower.contains('500') ||
      lower.contains('502') ||
      lower.contains('503') ||
      lower.contains('504') ||
      lower.contains('bad gateway') ||
      lower.contains('service unavailable') ||
      lower.contains('internal server error')) {
    return UpstreamErrorCategory.server;
  }
  return UpstreamErrorCategory.unknown;
}

/// 解析 `Retry-After` 响应头（秒数形式）。
///
/// 只支持 `delta-seconds`（绝大多数 OpenAI 兼容服务使用这种形式）；
/// HTTP-date 形式不解析，回落到指数退避。返回值上限 30 秒、下限 1 秒。
Duration? parseRetryAfterHeader(String? raw) {
  if (raw == null) return null;
  final seconds = int.tryParse(raw.trim());
  if (seconds == null) return null;
  return Duration(seconds: seconds.clamp(1, 30));
}

/// 一次重试决策的结果。
class RetryDecision {
  final bool shouldRetry;
  final Duration delay;
  final bool usedRetryAfter;
  final String reason;

  const RetryDecision({
    required this.shouldRetry,
    this.delay = Duration.zero,
    this.usedRetryAfter = false,
    this.reason = '',
  });

  const RetryDecision.giveUp(this.reason)
      : shouldRetry = false,
        delay = Duration.zero,
        usedRetryAfter = false;
}

/// 上游重试策略：可重试判定 + 指数退避 + `Retry-After` 优先。
///
/// 退避表：第 1 / 2 / 3 次重试等待 2s / 6s / 15s，叠 ±20% 抖动；
/// 响应头 `Retry-After` 存在时直接采用（上限 30s）。
/// 最大尝试 4 次（首次 + 3 次重试）。
class RetryPolicy {
  const RetryPolicy._();

  static const int maxAttempts = 4;
  static const List<int> backoffSeconds = [2, 6, 15];
  static const double jitterRatio = 0.2;
  static const Duration maxRetryAfter = Duration(seconds: 30);

  /// [attempt] 为**已进行的尝试次数**（1 表示首次请求刚失败）。
  ///
  /// [retryAfter] 仅在响应头存在时传入；[random] 供测试注入固定种子。
  static RetryDecision decide({
    required int attempt,
    int? statusCode,
    UpstreamErrorCategory? category,
    Duration? retryAfter,
    Random? random,
  }) {
    final cat = category ??
        (statusCode != null
            ? categoryFromStatus(statusCode)
            : UpstreamErrorCategory.unknown);
    final retryable = cat == UpstreamErrorCategory.throttled ||
        cat == UpstreamErrorCategory.server ||
        cat == UpstreamErrorCategory.timeout ||
        cat == UpstreamErrorCategory.network;
    if (!retryable) {
      return const RetryDecision.giveUp('不可重试错误');
    }
    if (attempt >= maxAttempts) {
      return const RetryDecision.giveUp('已达最大尝试次数');
    }

    if (retryAfter != null) {
      final capped =
          retryAfter > maxRetryAfter ? maxRetryAfter : retryAfter;
      return RetryDecision(
        shouldRetry: true,
        delay: capped,
        usedRetryAfter: true,
        reason: 'retry-after',
      );
    }

    final index = (attempt - 1).clamp(0, backoffSeconds.length - 1);
    final base = backoffSeconds[index];
    final jittered = base *
        (1 - jitterRatio + (random ?? Random()).nextDouble() * jitterRatio * 2);
    return RetryDecision(
      shouldRetry: true,
      delay: Duration(milliseconds: (jittered * 1000).round()),
      reason: 'exponential-backoff',
    );
  }
}

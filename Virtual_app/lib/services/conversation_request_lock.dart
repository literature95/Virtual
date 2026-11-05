/// 同一对话的请求锁：同一时刻只允许一个进行中的上游请求。
///
/// 锁按时长极短的同步 `tryAcquire` 获取 —— 必须发生在任何 `await` 之前，
/// 否则快速连点两次时两条请求都会先穿过「是否正在生成」的检查。
///
/// 不同对话使用不同的 key，不存在全局上限：一个对话在生成时，
/// 另一个对话的请求可以正常发起（是否真并发由宿主决定）。
///
/// 释放统一走 `run` 的 `finally`，成功 / 失败 / 取消都不会泄漏锁。
class ConversationRequestLock {
  final Set<String> _active = {};

  bool isLocked(String conversationId) =>
      _active.contains(conversationId);

  /// 返回 true 表示本次成功占锁；false 表示该对话已有请求在进行。
  bool tryAcquire(String conversationId) => _active.add(conversationId);

  void release(String conversationId) {
    _active.remove(conversationId);
  }

  /// 当前占锁的对话数（测试与诊断用）。
  int get activeCount => _active.length;

  /// 占锁执行 [task]，无论成功、抛异常还是被取消都会在 finally 释放。
  Future<T> run<T>(
    String conversationId,
    Future<T> Function() task,
  ) async {
    if (!tryAcquire(conversationId)) {
      throw ConversationBusyException(conversationId);
    }
    try {
      return await task();
    } finally {
      release(conversationId);
    }
  }
}

/// 同一对话已有进行中的请求时抛出。
class ConversationBusyException implements Exception {
  final String conversationId;

  const ConversationBusyException(this.conversationId);

  @override
  String toString() => '上一条还在生成（conversation=$conversationId）';
}

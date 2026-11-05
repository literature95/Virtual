import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nobodywho/nobodywho.dart' as nobodywho;

import '../../models/conversation.dart';
import '../../models/endpoint.dart';
import 'llm_adapter.dart';

/// 本地模型适配器 —— nobodywho 6.x（捆绑 llama.cpp）实现。
///
/// 仅在 io 平台（Android / iOS / Windows / macOS / Linux）编译；
/// web 端没有 nobodywho 实现，由条件导入切到 `nobodywho_adapter_stub.dart`
/// （见 api_service.dart 顶部 import）。
///
/// 上下文策略（真机「答非所问 / 裁剪混乱」修复）：
/// - **增量上下文**：同一对话（`endpointId::conversationId`）复用同一个 Chat，
///   不再每轮 `resetHistory`/重传全部历史；每轮只发送本轮用户消息，
///   历史留在引擎内部，首字延迟不再每轮全额重付。
/// - **75% 阈值裁剪**：用 `getStats().contextUsed` 监控，超过预算 75% 时才用
///   `setChatHistory` 保留「system(压缩角色卡) + 最近 4 轮」。
/// - **降级路径**：裁剪后仍报 `context_shift_too_few_messages` 时，重建 Chat
///   并只带最近 4 轮重发一次，日志前缀 `[LocalPrompt]` 可见。
/// - **会话隔离**：切换/删除对话时释放对应 Chat（库无公开 dispose，
///   `resetHistory()` 后移出缓存，由 Rust 侧析构）。
/// - **性能统计**：最终块携带首字延迟与 tok/s，供气泡下方展示。
class NobodyWhoAdapter implements LLMAdapter, LocalContextAdapter {
  NobodyWhoAdapter(this.endpoint);

  final LlmEndpoint endpoint;

  static bool _inited = false;

  /// key = `endpointId::conversationId`
  static final Map<String, _CachedChat> _cache = {};

  /// 被上层在「本轮」设置的压缩角色卡（Chat.fromPath 的 systemPrompt）。
  String? _nextSystemPrompt;

  /// 裁剪触发阈值：上下文用量超过该比例才丢弃旧轮次。
  static const double _trimThreshold = 0.75;

  @override
  String get protocol => 'nobodywho';

  @override
  void setNextSystemPrompt(String? prompt) => _nextSystemPrompt = prompt;

  /// 返回当前会话的 token 计数器（供提示词组装层压缩角色卡/裁历史）。
  ///
  /// 模型路径未配置时返回 null，让上层回退到保守的字符估算。
  @override
  Future<Future<int> Function(String)?> tokenCounter(
    String conversationId,
  ) async {
    if (endpoint.localModelPath.trim().isEmpty) return null;
    await _ensureInit();
    final resolved = await _resolveChat(conversationId, _nextSystemPrompt);
    final chat = resolved.chat;
    return (String text) async {
      try {
        return (await chat.tokenize(text)).length;
      } catch (_) {
        return (text.length / 2).ceil();
      }
    };
  }

  /// 释放指定会话的推理上下文（切换/删除/清空对话时调用）。
  @override
  Future<void> releaseLocalContext(String conversationId) async {
    final suffix = '::$conversationId';
    final keys = _cache.keys.where((k) => k.endsWith(suffix)).toList();
    for (final key in keys) {
      final stale = _cache.remove(key);
      try {
        await stale?.chat.resetHistory();
      } catch (e) {
        debugPrint('[LocalPrompt] 释放旧 Chat($key) 失败：$e');
      }
      debugPrint('[LocalPrompt] 已释放会话上下文：$key');
    }
  }

  @override
  Stream<ChatChunk> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
    String? conversationId,
  }) {
    final controller = StreamController<ChatChunk>();
    nobodywho.Chat? activeChat;

    controller.onCancel = () {
      // 上层停止生成（或流结束）时，别让引擎继续烧 CPU
      activeChat?.stopGeneration();
    };

    _generate(
      controller,
      messages,
      conversationId ?? 'default',
      (c) => activeChat = c,
    );
    return controller.stream;
  }

  @override
  Future<ChatResponse> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    required ChatSettings settings,
    String? conversationId,
  }) async {
    final content = StringBuffer();
    final reasoning = StringBuffer();
    int? promptTokens;
    int? completionTokens;
    String? finishReason;
    int? firstTokenMs;
    double? tokensPerSecond;
    await for (final chunk in chatStream(
      model: model,
      messages: messages,
      settings: settings,
      conversationId: conversationId,
    )) {
      content.write(chunk.content);
      reasoning.write(chunk.reasoning);
      promptTokens = chunk.promptTokens ?? promptTokens;
      completionTokens = chunk.completionTokens ?? completionTokens;
      finishReason = chunk.finishReason ?? finishReason;
      firstTokenMs = chunk.firstTokenMs ?? firstTokenMs;
      tokensPerSecond = chunk.tokensPerSecond ?? tokensPerSecond;
    }
    return ChatResponse(
      content: content.toString(),
      reasoning: reasoning.isEmpty ? null : reasoning.toString(),
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      finishReason: finishReason,
      firstTokenMs: firstTokenMs,
      tokensPerSecond: tokensPerSecond,
    );
  }

  Future<void> _generate(
    StreamController<ChatChunk> controller,
    List<Map<String, dynamic>> messages,
    String conversationId,
    void Function(nobodywho.Chat chat) onChat,
  ) async {
    try {
      if (endpoint.localModelPath.trim().isEmpty) {
        throw const _ConfigError('本地模型路径未配置，请在端点「部署」设置中填写 GGUF 文件路径');
      }
      await _ensureInit();

      final systemPrompt = _nextSystemPrompt ?? _leadingSystem(messages);
      final incoming = _stripLeadingSystem(messages);
      if (incoming.isEmpty) {
        throw const _ConfigError('本轮消息为空，无法生成');
      }

      var resolved = await _resolveChat(conversationId, systemPrompt);
      var chat = resolved.chat;
      onChat(chat);

      // 增量模式：引擎已持有历史时用 `ask` 追加本轮（`complete` 会整段替换历史，
      // 只适合新建 / 重建 / 降级路径）。
      var sentList = incoming;
      var useAsk = false;
      String askText = '';
      if (!resolved.created) {
        final tail = _tailAfterLastAssistant(incoming);
        final lastSent = resolved.state.lastTurnContent;
        if (tail.isEmpty || tail.last['content']?.toString() == lastSent) {
          // 重新生成同一条用户消息：引擎里还留着旧回复，必须重建后重发
          debugPrint('[LocalPrompt] 检测到重新生成/历史改写，重建 Chat 并携带最近 '
              '${incoming.length} 条消息');
          resolved = await _rebuildChat(conversationId, systemPrompt);
          chat = resolved.chat;
          onChat(chat);
          sentList = incoming;
        } else {
          sentList = tail;
          useAsk = true;
          askText = tail.last['content']?.toString() ?? '';
          // 75% 阈值裁剪：只保留 system + 最近 4 轮
          try {
            final stats = await chat.getStats();
            final ratio = stats.contextSize <= 0
                ? 0.0
                : stats.contextUsed / stats.contextSize;
            debugPrint('[LocalPrompt] contextUsed=${stats.contextUsed}/'
                '${stats.contextSize}（${(ratio * 100).toStringAsFixed(1)}%）');
            if (ratio > _trimThreshold) {
              final historyBlock =
                  incoming.sublist(0, incoming.length - sentList.length);
              final before = stats.contextUsed;
              await chat.setChatHistory([
                if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
                  nobodywho.systemMessage(systemPrompt),
                for (final m in historyBlock)
                  _toMessage(m['role']?.toString() ?? 'user',
                      m['content']?.toString() ?? ''),
              ]);
              final after = await chat.getStats();
              debugPrint('[LocalPrompt] 触发裁剪：${historyBlock.length} 条历史 → '
                  '保留最近轮次，contextUsed $before → ${after.contextUsed}');
            }
          } catch (e) {
            // 裁剪失败不阻断生成：直接沿用引擎已有上下文
            debugPrint('[LocalPrompt] 裁剪失败（继续生成）：$e');
          }
        }
      } else {
        debugPrint('[LocalPrompt] 新建 Chat，携带 ${incoming.length} 条消息');
      }

      final sw = Stopwatch()..start();
      int? firstTokenMs;
      var genTokens = 0;
      final content = StringBuffer();
      final reasoning = StringBuffer();
      var inReasoning = false;
      var finish = 'stop';
      var fallbackTried = false;

      Future<void> run(
        nobodywho.Chat target,
        List<Map<String, dynamic>> toSend, {
        bool ask = false,
        String askContent = '',
      }) async {
        final stream = ask
            ? target.ask(askContent)
            : target.complete(
                [
                  for (final m in toSend)
                    _toMessage(m['role']?.toString() ?? 'user',
                        m['content']?.toString() ?? '')
                ],
                sampler: _sampler(),
              );
        await for (final token in stream) {
          firstTokenMs ??= sw.elapsedMilliseconds;
          var toReasoning = inReasoning;
          if (!inReasoning && _reasoningOpen.any(token.contains)) {
            inReasoning = true;
            toReasoning = true;
          } else if (inReasoning && _reasoningClose.any(token.contains)) {
            inReasoning = false;
          }

          if (toReasoning) {
            reasoning.write(token);
            controller.add(ChatChunk(reasoning: token));
          } else {
            content.write(token);
            controller.add(ChatChunk(content: token));
          }

          genTokens++;
          if (genTokens >= endpoint.maxTokens && finish == 'stop') {
            finish = 'length';
            target.stopGeneration(); // 达到端点 maxTokens，要求引擎收尾
          }
        }
      }

      try {
        await run(chat, sentList, ask: useAsk, askContent: askText);
      } catch (e) {
        final shiftError = _isShiftError(e);
        if (shiftError && !fallbackTried && content.isEmpty) {
          // 降级：重建 Chat + 只带最近 4 轮（组装层已保证不多于 4 轮）
          fallbackTried = true;
          debugPrint('[LocalPrompt] 裁剪后仍报 context_shift，降级重建 Chat，'
              '重发 ${incoming.length} 条消息');
          resolved = await _rebuildChat(conversationId, systemPrompt);
          chat = resolved.chat;
          onChat(chat);
          sw
            ..reset()
            ..start();
          firstTokenMs = null;
          genTokens = 0;
          content.clear();
          reasoning.clear();
          inReasoning = false;
          finish = 'stop';
          await run(chat, incoming);
        } else {
          rethrow;
        }
      }

      // 记录本轮用户输入，供下一轮判断「新增 / 重新生成」
      final lastUser = incoming.lastWhere(
        (m) => (m['role']?.toString() ?? '') == 'user',
        orElse: () => incoming.last,
      );
      resolved.state.lastTurnContent = lastUser['content']?.toString();

      final elapsedMs = sw.elapsedMilliseconds;
      final firstMs = firstTokenMs;
      final genMs = firstMs == null ? 0 : elapsedMs - firstMs;
      final tps = genMs > 0 ? genTokens * 1000.0 / genMs : null;

      // 生成后记录真实上下文占用（调试用；失败不影响主流程）
      try {
        final stats = await chat.getStats();
        debugPrint('[LocalPrompt] 生成结束：contextUsed=${stats.contextUsed}'
            '/${stats.contextSize}，completionTokens=$genTokens，'
            '首字 ${firstTokenMs ?? -1}ms，${tps?.toStringAsFixed(1) ?? '-'} tok/s');
      } catch (e) {
        debugPrint('[LocalPrompt] getStats 失败：$e');
      }

      controller.add(ChatChunk(
        isFinal: true,
        finishReason: finish,
        completionTokens: genTokens,
        firstTokenMs: firstTokenMs,
        tokensPerSecond: tps,
      ));
    } catch (e) {
      debugPrint('[LocalModel] 原始错误：$e');
      if (!controller.isClosed) {
        final message = e is _ConfigError ? e.message : _readableError(e);
        controller.addError(StateError(message));
      }
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  Future<void> _ensureInit() async {
    if (_inited) return;
    await nobodywho.NobodyWho.init();
    _inited = true;
  }

  /// 缓存/复用 Chat：按「端点 + 会话」隔离。systemPrompt 变化即重建。
  Future<_ResolvedChat> _resolveChat(
    String conversationId,
    String? systemPrompt,
  ) async {
    final key = '${endpoint.id}::$conversationId';
    final cached = _cache[key];
    if (cached != null && cached.matches(endpoint)) {
      if (cached.systemPrompt == systemPrompt) {
        return _ResolvedChat(cached.chat, cached, created: false);
      }
      // tokenizer 预热时 Chat 可能还没拿到压缩卡：历史为空则直接换 system，
      // 避免为了设置 systemPrompt 重建一次 Chat（首字延迟敏感）。
      try {
        final existing = await cached.chat.getChatHistory();
        if (existing.isEmpty) {
          await cached.chat.setSystemPrompt(systemPrompt ?? '');
          cached.systemPrompt = systemPrompt;
          debugPrint('[LocalPrompt] 复用空上下文 Chat，仅更新 system prompt');
          return _ResolvedChat(cached.chat, cached, created: true);
        }
      } catch (e) {
        debugPrint('[LocalPrompt] 读取已有历史失败（按重建处理）：$e');
      }
    }

    // 会话切换：释放该端点下其它会话的 Chat（库无公开 dispose）
    final staleKeys = _cache.keys
        .where((k) => k.startsWith('${endpoint.id}::') && k != key)
        .toList();
    for (final staleKey in staleKeys) {
      final stale = _cache.remove(staleKey);
      try {
        await stale?.chat.resetHistory();
      } catch (e) {
        debugPrint('[LocalPrompt] 释放旧 Chat($staleKey) 失败：$e');
      }
      debugPrint('[LocalPrompt] 会话切换，已释放旧 Chat：$staleKey');
    }

    if (cached != null) {
      _cache.remove(key);
      try {
        await cached.chat.resetHistory();
      } catch (_) {}
    }

    final chat = await nobodywho.Chat.fromPath(
      modelPath: endpoint.localModelPath.trim(),
      systemPrompt:
          systemPrompt != null && systemPrompt.trim().isNotEmpty
              ? systemPrompt
              : null,
      contextSize: endpoint.contextSize,
      useGpu: endpoint.useGpu,
      threadCount: endpoint.threadCount > 0 ? endpoint.threadCount : null,
      // 引擎自动丢中段旧轮次：首轮 + 最近 8 轮（远大于我们只带的 4 轮）
      contextShift: const nobodywho.ContextShiftOptions(
        keepFirstTurns: 1,
        keepLastTurns: 8,
      ),
      sampler: _sampler(),
    );
    final state = _CachedChat(
      chat: chat,
      modelPath: endpoint.localModelPath.trim(),
      contextSize: endpoint.contextSize,
      useGpu: endpoint.useGpu,
      threadCount: endpoint.threadCount,
      systemPrompt: systemPrompt,
    );
    _cache[key] = state;
    return _ResolvedChat(chat, state, created: true);
  }

  /// 强制重建并替换缓存（降级路径 / 重新生成）。
  Future<_ResolvedChat> _rebuildChat(
    String conversationId,
    String? systemPrompt,
  ) async {
    final key = '${endpoint.id}::$conversationId';
    final old = _cache.remove(key);
    try {
      await old?.chat.resetHistory();
    } catch (_) {}
    return _resolveChat(conversationId, systemPrompt);
  }

  static bool _isShiftError(Object e) {
    final low = e.toString().toLowerCase();
    return low.contains('context_shift_too_few_messages') ||
        low.contains('not enough messages to shift');
  }

  /// 取消息列表开头的 system 内容（上层未单独传 systemPrompt 时的兜底）。
  static String? _leadingSystem(List<Map<String, dynamic>> messages) {
    for (final m in messages) {
      if ((m['role']?.toString() ?? '') == 'system') {
        final text = m['content']?.toString() ?? '';
        return text.trim().isEmpty ? null : text;
      }
      break;
    }
    return null;
  }

  static List<Map<String, dynamic>> _stripLeadingSystem(
      List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return messages;
    if ((messages.first['role']?.toString() ?? '') == 'system') {
      return messages.sublist(1);
    }
    return messages;
  }

  /// 本轮消息：最后一条 assistant 之后的部分（增量模式下只发这些）。
  static List<Map<String, dynamic>> _tailAfterLastAssistant(
      List<Map<String, dynamic>> messages) {
    var lastAssistant = -1;
    for (var i = messages.length - 1; i >= 0; i--) {
      if ((messages[i]['role']?.toString() ?? '') == 'assistant') {
        lastAssistant = i;
        break;
      }
    }
    if (lastAssistant < 0) return messages;
    return messages.sublist(lastAssistant + 1);
  }

  /// 采样器：重复惩罚 → 温度 → top-p 层叠后由 `dist()` 收口。
  nobodywho.SamplerConfig _sampler() => nobodywho.SamplerBuilder()
      .penalties(
        penaltyLastN: 64,
        penaltyRepeat: endpoint.repetitionPenalty,
        penaltyFreq: 0,
        penaltyPresent: 0,
      )
      .temperature(temperature: endpoint.temperature)
      .topP(topP: endpoint.topP, minKeep: 1)
      .dist();

  /// 把引擎异常映射成可读中文；原始错误已由调用方写入日志。
  String _readableError(Object e) {
    final raw = e.toString();
    final low = raw.toLowerCase();
    if (low.contains('context_shift_too_few_messages') ||
        low.contains('not enough messages to shift')) {
      return '对话历史过长，本地模型无法自动压缩上下文：'
          '请缩短角色卡、减少历史轮数，或调大「上下文长度」'
          '（当前 ${endpoint.contextSize}）。';
    }
    if (low.contains('model_not_found') || low.contains('model not found')) {
      return '未找到本地模型文件：请到端点设置重新选择/安装内置模型。';
    }
    if (low.contains('out of memory') ||
        low.contains('oom') ||
        low.contains('failed to allocate') ||
        low.contains('memory allocation')) {
      return '设备内存不足：请关闭后台应用，或关闭 GPU 加速/换更小模型后重试。';
    }
    final short = raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
    return '本地模型推理失败：$short（详情见日志）';
  }

  nobodywho.Message _toMessage(String role, String text) => switch (role) {
        'system' => nobodywho.systemMessage(text),
        'assistant' => nobodywho.assistantMessage(text),
        _ => nobodywho.userMessage(text),
      };

  static const List<String> _reasoningOpen = [
    '<｜begin▁of▁thought｜>',
    '<think>',
    '<thought>',
    '<thinking>',
  ];
  static const List<String> _reasoningClose = [
    '<｜end▁of▁thought｜>',
    '</think>',
    '</thought>',
    '</thinking>',
  ];
}

class _ResolvedChat {
  final nobodywho.Chat chat;
  final _CachedChat state;
  final bool created;

  const _ResolvedChat(this.chat, this.state, {required this.created});
}

class _ConfigError implements Exception {
  final String message;

  const _ConfigError(this.message);
}

class _CachedChat {
  final nobodywho.Chat chat;
  final String modelPath;
  final int contextSize;
  final bool useGpu;
  final int threadCount;
  String? systemPrompt;

  /// 上一轮发送的最后一条用户消息（用于区分「新增消息 / 重新生成」）。
  String? lastTurnContent;

  _CachedChat({
    required this.chat,
    required this.modelPath,
    required this.contextSize,
    required this.useGpu,
    required this.threadCount,
    required this.systemPrompt,
  });

  bool matches(LlmEndpoint endpoint) =>
      modelPath == endpoint.localModelPath.trim() &&
      contextSize == endpoint.contextSize &&
      useGpu == endpoint.useGpu &&
      threadCount == endpoint.threadCount;
}

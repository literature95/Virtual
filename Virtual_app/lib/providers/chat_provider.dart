import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_feature_flags.dart';
import '../data/app_database.dart';
import '../models/character.dart';
import '../models/chat_message.dart';
import '../models/chat_theme.dart';
import '../models/conversation.dart';
import '../models/endpoint.dart';
import '../models/lorebook.dart';
import '../models/persona.dart';
import '../models/preset.dart';
import '../services/api_service.dart';
import '../services/chat_action_policy.dart';
import '../services/context_window_service.dart';
import '../services/conversation_request_lock.dart';
import '../services/local_prompt_builder.dart';
import '../services/plot_option_parser.dart';
import '../services/prompt_service.dart';
import '../services/retry_policy.dart';
import 'settings_provider.dart';
import 'character_provider.dart';
import 'endpoint_provider.dart';

/// 聊天状态管理
///
/// 管理当前对话的消息列表、生成状态，并协调 API 流式调用。
/// 使用 Provider + ChangeNotifier 模式。
class ChatProvider extends ChangeNotifier {
  final AppDatabase _db;
  final ApiService _apiService;
  final _uuid = const Uuid();

  CharacterProvider? _characterProvider;
  EndpointProvider? _endpointProvider;

  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;

  Conversation? _currentConversation;
  Conversation? get currentConversation => _currentConversation;

  /// 按 id 读取对话（含非当前对话），供背景设置页定位角色立绘
  Conversation? conversationById(String id) => _db.getConversation(id);

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  /// 同一对话的串行锁：快速连点 / 重入时只允许一个上游请求在跑。
  final ConversationRequestLock _requestLock = ConversationRequestLock();

  /// 当前对话是否已有进行中的请求（供 UI 提示使用）。
  bool get isCurrentConversationBusy {
    final id = _currentConversation?.id;
    return id != null && _requestLock.isLocked(id);
  }

  /// 渲染用消息列表：隐藏消息（如「继续上文」指令）仍进上下文，但不显示。
  List<ChatMessage> get visibleMessages =>
      _messages.where((m) => !m.isHidden).toList();

  /// 剧情选项缓存：key = AI 消息 id（同一消息生成一次后复用，切页面不丢）。
  final Map<String, List<String>> _plotOptions = {};
  final Map<String, String> _plotOptionsError = {};
  final Set<String> _plotOptionsLoading = {};

  List<String> plotOptionsFor(String messageId) =>
      _plotOptions[messageId] ?? const [];

  String? plotOptionsErrorFor(String messageId) =>
      _plotOptionsError[messageId];

  bool isPlotOptionsLoading(String messageId) =>
      _plotOptionsLoading.contains(messageId);

  /// 是否有选项请求在跑（任一消息）。与聊天请求共用对话锁，故两者互斥。
  bool get isGeneratingOptions => _plotOptionsLoading.isNotEmpty;

  bool _isStopRequested = false;

  String? _currentEndpointId;
  String? get currentEndpointId => _currentEndpointId;

  String? _currentModelId;
  String? get currentModelId => _currentModelId;

  ChatProvider(this._db) : _apiService = ApiService();

  /// 更新依赖的 Provider
  String? _userNickname;

  void updateDependencies(
    SettingsProvider settings,
    CharacterProvider characterProvider,
    EndpointProvider endpointProvider, [
    String? userNickname,
  ]) {
    _userNickname = userNickname;
    _characterProvider = characterProvider;
    _endpointProvider = endpointProvider;
    loadConversations();
  }

  /// 仅供测试：只注入账号昵称，不触发完整依赖装载（loadConversations 等）
  @visibleForTesting
  void updateDependenciesForTest({String? userNickname}) {
    _userNickname = userNickname;
  }

  /// 解析当前会话生效的人设卡：显式绑定 > 全局激活 > 账号昵称兜底。
  ///
  /// `{{user}}` 宏的值就取自这里的 persona.name。用户直觉是「角色卡里的
  /// {{user}} 就是我（账号昵称）」——所以在没有人设卡时不能硬编码回
  /// 'User'，应当用登录账号的昵称兜底。返回的是临时 Persona（含账号
  /// 昵称兜底时不会落库），仅用于 Prompt 组装。
  @visibleForTesting
  Persona resolvePersona(String? personaId) {
    if (personaId != null && personaId.isNotEmpty) {
      for (final p in _db.getPersonas()) {
        if (p.id == personaId) return p;
      }
    }
    final active = _db.getActivePersona();
    if (active != null) return active;
    final nick = _userNickname?.trim();
    if (nick != null && nick.isNotEmpty) {
      return Persona(
        id: 'account',
        name: nick,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return Persona(
      id: 'default',
      name: 'User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 解析会话生效的世界书：会话显式绑定 > 角色卡绑定。
  ///
  /// 「启用角色卡」时卡上的 `lorebookId` 必须跟随进 Prompt 并随切换角色
  /// 而切换（此前它只存在于编辑页展示，从未参与组装）；书被整体停用
  /// (`enabled == false`) 或已被删除时返回 null。
  @visibleForTesting
  Lorebook? resolveLorebook(String? lorebookId) {
    if (lorebookId == null || lorebookId.isEmpty) return null;
    for (final b in _db.getLorebooks()) {
      if (b.id == lorebookId) return b.enabled ? b : null;
    }
    return null;
  }

  /// 解析会话生效的预设：会话显式绑定 > 全局激活预设。
  @visibleForTesting
  Preset? resolvePreset(String? presetId) {
    if (presetId != null && presetId.isNotEmpty) {
      for (final p in _db.getPresets()) {
        if (p.id == presetId) return p;
      }
    }
    return _db.getActivePreset();
  }

  // ========== 对话列表 ==========

  /// 加载所有对话
  Future<void> loadConversations() async {
    _conversations = _db.getConversations();
    notifyListeners();
  }

  /// 创建新对话
  Future<Conversation> createConversation({
    required String characterId,
    String? modelId,
    String? endpointId,
    String title = '新对话',
    ChatSettings? settings,
  }) async {
    final now = DateTime.now();
    final conv = Conversation(
      id: _uuid.v4(),
      title: title,
      characterId: characterId,
      modelId: modelId,
      endpointId: endpointId,
      settings: settings ?? ChatSettings(),
      createdAt: now,
      updatedAt: now,
    );

    await _db.saveConversation(conv);
    await loadConversations();
    return conv;
  }

  /// 查找某角色最近更新的对话（用于「已导入角色 → 续聊」而非新建空会话）
  ///
  /// 一键导入若每次都 createConversation，用户重复点同一张卡就会攒出一串
  /// 空对话。命中已有对话时应当直接回到那一条。
  Conversation? latestConversationOf(String characterId) {
    final list =
        _conversations.where((c) => c.characterId == characterId).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.first;
  }

  /// 删除对话
  Future<void> deleteConversation(String id) async {
    await _db.deleteConversation(id);
    // 连带清掉该对话的背景设置，避免主题表里留下孤儿条目
    await _db.deleteTheme(backgroundThemeId(id));
    // 释放本地模型上下文，避免同一端点下残留该会话的推理历史
    await _apiService.releaseLocalContext(id);
    if (_currentConversation?.id == id) {
      _currentConversation = null;
      _messages = [];
    }
    await loadConversations();
  }

  /// 切换对话置顶状态
  Future<void> pinConversation(String id, bool pinned) async {
    final conv = _db.getConversation(id);
    if (conv != null) {
      await _db.saveConversation(conv.copyWith(isPinned: pinned));
      await loadConversations();
    }
  }

  /// 重命名对话
  Future<void> renameConversation(String id, String title) async {
    final conv = _db.getConversation(id);
    if (conv != null && title.trim().isNotEmpty) {
      await _db.saveConversation(conv.copyWith(title: title.trim()));
      await loadConversations();
    }
  }

  /// 清空指定对话的所有消息（保留对话本身）
  Future<void> clearMessages(String conversationId) async {
    _db.clearMessages(conversationId);
    // 清空历史后引擎侧上下文也必须重置，否则会出现「界面为空但模型记得」
    await _apiService.releaseLocalContext(conversationId);
    if (_currentConversation?.id == conversationId) {
      _messages = [];
      notifyListeners();
    }
  }

  // ========== 对话背景 ==========
  //
  // 背景按「对话」维度存储，且**不新增数据表 / 不改 Conversation 模型**：
  // 复用既有的主题表（`db_themes` → `ChatTheme`），用**由对话 id 派生的固定主题 id**
  // 建立归属关系 —— 主题存在 == 该对话设过背景，主题不存在 == 未设置。
  //
  // 这样做的理由：
  //  1. `ChatTheme` 已经内建 `backgroundImage / backgroundOpacity / backgroundBlur`
  //     三个字段，语义完全吻合，不必重造结构；
  //  2. 避免往 `Conversation.toJson()` 里加字段（会牵动备份 / 导出的兼容性）；
  //  3. 归属由 id 推导，无需读对话即可判断，省掉一次写回。

  /// 由对话 id 派生出的背景主题 id（固定前缀，勿随意改动以免存量设置失联）
  static String backgroundThemeId(String conversationId) =>
      'conv-bg-$conversationId';

  /// 读取指定对话的背景设置；未设置返回 null
  ChatTheme? conversationBackground(String conversationId) {
    final themes = _db.getThemes();
    if (themes.isEmpty) return null;
    final id = backgroundThemeId(conversationId);
    for (final t in themes) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 保存指定对话的背景设置
  ///
  /// `isActive` 恒为 false：`isActive` 是「全局生效主题」的标记，
  /// 对话背景绝不能抢走它，否则会污染 `getActiveTheme()`。
  Future<void> saveConversationBackground(
    String conversationId,
    ChatTheme background,
  ) async {
    await _db.saveTheme(
      background.copyWith(
        id: backgroundThemeId(conversationId),
        name: '对话背景',
        isActive: false,
        isBuiltIn: false,
      ),
    );
    notifyListeners();
  }

  /// 清除指定对话的背景设置
  Future<void> clearConversationBackground(String conversationId) async {
    await _db.deleteTheme(backgroundThemeId(conversationId));
    notifyListeners();
  }

  // ========== 消息加载 ==========

  /// 加载指定对话的消息
  Future<void> loadMessages(String conversationId) async {
    final conv = _db.getConversation(conversationId);
    if (conv == null) return;

    // 切换会话：释放上一个会话的本地上下文，避免跨会话串场
    final previousId = _currentConversation?.id;
    if (previousId != null && previousId != conversationId) {
      await _apiService.releaseLocalContext(previousId);
    }

    _currentConversation = conv;
    _messages = _db.getMessages(conversationId);
    _currentModelId = conv.modelId;
    _currentEndpointId = conv.endpointId;

    // 如果对话无消息且角色有首条消息，自动插入
    if (_messages.isEmpty) {
      final character = _characterProvider?.getCharacter(conv.characterId) ??
          _db.getCharacter(conv.characterId);
      if (character != null &&
          character.firstMessage != null &&
          character.firstMessage!.trim().isNotEmpty) {
        // 开场白渲染 {{user}} 等宏:persona 走 resolvePersona 链
        // (绑定 > 激活 > 账号昵称 > 'User'),插入时渲染并落库。
        final persona =
            resolvePersona(conv.settings.personaId ?? character.personaId);
        final greetingText = PromptService.renderGreeting(
          character: character,
          persona: persona,
        );
        final greetingMsg = ChatMessage(
          id: _uuid.v4(),
          conversationId: conv.id,
          role: MessageRole.assistant,
          source: MessageSource.model,
          variant: MessageVariant.standard,
          content: greetingText,
          isGenerating: false,
          createdAt: DateTime.now(),
        );
        _messages.add(greetingMsg);
        await _db.saveMessage(conv.id, greetingMsg);

        // 更新对话的最后消息时间和预览
        final updatedConv = conv.copyWith(
          lastMessageAt: DateTime.now(),
          lastMessagePreview: _truncatePreview(greetingText),
        );
        _currentConversation = updatedConv;
        await _db.saveConversation(updatedConv);
      }
    }

    notifyListeners();
  }

  // ========== 消息发送 ==========

  /// 发送消息并流式生成回复
  ///
  /// 返回 false 表示**同一对话已有进行中的请求**，本次发送被拦截
  /// （UI 据此提示「上一条还在生成」）；其余情况（包括参数校验失败）返回 true。
  ///
  /// [content] 用户消息内容
  /// [images] 附带的图片路径列表
  Future<bool> sendMessage(String content,
      {List<String>? images, bool hidden = false}) async {
    final current = _currentConversation;
    if (current == null) return false;

    // 同步占锁，必须早于任何 await：否则快速连点两次时，两条请求都会在
    // `_isGenerating` 置 true 之前穿过检查，形成真实的并发上游调用。
    if (!_requestLock.tryAcquire(current.id)) {
      debugPrint('[Retry] 对话 ${current.id} 已有进行中的请求，拦截本次发送');
      notifyListeners();
      return false;
    }
    try {
      await _sendMessageInner(content, images: images, hidden: hidden);
      return true;
    } finally {
      // 成功 / 失败 / 取消 / 提前 return 都必须释放，异常路径不得泄漏。
      _requestLock.release(current.id);
    }
  }

  /// [sendMessage] 的实际执行体（调用方已持有该对话的请求锁）。
  Future<void> _sendMessageInner(String content,
      {List<String>? images, bool hidden = false}) async {
    final conv = _currentConversation!;

    // 1. 获取角色信息
    final character = _characterProvider?.getCharacter(conv.characterId) ??
        _db.getCharacter(conv.characterId);
    if (character == null) {
      _addErrorMessage('未找到角色信息');
      return;
    }

    // 2. 获取端点和模型
    final endpoint = _resolveEndpoint();
    if (endpoint == null) {
      _addErrorMessage('未配置 API 端点，请先在设置中添加');
      return;
    }
    // 本地部署已停用：保留旧端点在列表里，但不做本地推理
    if (!AppFeatureFlags.localDeployEnabled &&
        endpoint.mode == EndpointMode.deploy) {
      _addErrorMessage('本地部署已停用，请改用接入型端点');
      return;
    }

    final modelId = _resolveModelId(endpoint);
    if (modelId == null) {
      _addErrorMessage('未选择模型');
      return;
    }

    // 3. 获取 Persona（绑定 > 激活 > 账号昵称兜底，见 resolvePersona）
    final persona = resolvePersona(conv.settings.personaId ?? character.personaId);

    // 4. 添加用户消息
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conv.id,
      role: MessageRole.user,
      source: MessageSource.user,
      variant: MessageVariant.standard,
      content: content.trim(),
      attachments: images
              ?.map((path) => MessageAttachment(
                    id: _uuid.v4(),
                    type: MessageAttachmentType.image,
                    path: path,
                  ))
              .toList() ??
          [],
      isGenerating: false,
      // 隐藏消息（如「继续上文」）仍写入数据库并参与上下文，只是不在列表渲染
      isHidden: hidden,
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);
    await _db.saveMessage(conv.id, userMsg);

    // 5. 添加 assistant 占位消息
    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conv.id,
      role: MessageRole.assistant,
      source: MessageSource.model,
      variant: MessageVariant.standard,
      content: '',
      reasoning: '',
      isGenerating: true,
      createdAt: DateTime.now(),
    );
    _messages.add(assistantMsg);
    _isGenerating = true;
    _isStopRequested = false;
    notifyListeners();

    // 6. 组装本轮请求：
    //    本地模型（0.8B）走独立组装层（压缩角色卡 + 最近 4 轮 + 本轮指令），
    //    云端沿用原有「完整角色卡 + 预设/世界书 + 全局裁剪」流程。
    final visibleHistory = _messages
        .where((m) => m.id != userMsg.id && m.id != assistantMsg.id)
        .toList();
    final adapter = _apiService.getAdapter(endpoint);
    final localPrompt = await _buildLocalPrompt(
      adapter: adapter,
      endpoint: endpoint,
      conversationId: conv.id,
      character: character,
      history: visibleHistory,
      userMessage: content.trim(),
      settings: conv.settings,
    );

    final List<Map<String, dynamic>> messages;
    if (localPrompt != null) {
      messages = localPrompt.messages;
      adapter.setLocalSystemPrompt(localPrompt.systemPrompt);
    } else {
      // 两遍拼装第一遍:先拼出完整 system 文本(含预设/世界书/示例对话),
      // 用真实文本估算 token,避免旧「字段累加」估算漏项导致超窗
      final assembled = PromptService.assembleSystem(
        character: character,
        history: visibleHistory,
        userMessage: content.trim(),
        persona: persona,
        systemPromptOverride: conv.settings.systemPrompt,
        jailbreakPrompt: conv.settings.jailbreakPrompt,
        lorebook:
            resolveLorebook(conv.settings.lorebookId ?? character.lorebookId),
        preset: resolvePreset(conv.settings.presetId),
      );

      // system 区真实占用(含预设/世界书/示例,beforeUser/afterUser 块与余量)
      final reservedForSystem =
          PromptService.estimateSystemTokens(assembled);

      // 历史消息（排除刚添加的两条）+ 上下文窗口裁剪
      final historyMessages = ContextWindowService.trim(
        visibleHistory,
        maxTokens: _resolveContextWindow(endpoint, modelId),
        reservedForSystem: reservedForSystem,
      );

      // 复用第一遍拼装结果,世界书只选一次
      messages = PromptService.buildMessages(
        character: character,
        history: historyMessages,
        userMessage: content.trim(),
        userAttachments: userMsg.attachments,
        persona: persona,
        systemPromptOverride: conv.settings.systemPrompt,
        jailbreakPrompt: conv.settings.jailbreakPrompt,
        assembled: assembled,
      );
    }

    final chatSettings = conv.settings;

    int promptTokens = 0;
    int completionTokens = 0;
    int? firstTokenMs;
    double? tokensPerSecond;
    String accumulatedContent = '';
    String accumulatedReasoning = '';

    // 单次流式消费。采样参数被模型拒绝时可带钳制后的设置重试（见下方 catch）。
    Future<void> consume(ChatSettings s) async {
      final stream = s.enableStream
          ? adapter.chatCompletionsStream(
              model: modelId,
              messages: messages,
              settings: s,
              conversationId: conv.id,
            )
          : _nonStreamToStream(adapter, modelId, messages, s,
              conversationId: conv.id);

      await for (final chunk in stream) {
        if (_isStopRequested) break;

        if (chunk.promptTokens != null) {
          promptTokens = chunk.promptTokens!;
        }
        if (chunk.completionTokens != null) {
          completionTokens = chunk.completionTokens!;
        }
        if (chunk.firstTokenMs != null) {
          firstTokenMs = chunk.firstTokenMs;
        }
        if (chunk.tokensPerSecond != null) {
          tokensPerSecond = chunk.tokensPerSecond;
        }

        if (chunk.content.isNotEmpty) {
          accumulatedContent += chunk.content;
        }
        if (chunk.reasoning.isNotEmpty) {
          accumulatedReasoning += chunk.reasoning;
        }

        // 更新消息内容（流式更新）
        final index = _messages.indexWhere((m) => m.id == assistantMsg.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            content: accumulatedContent,
            reasoning:
                accumulatedReasoning.isNotEmpty ? accumulatedReasoning : null,
          );
          notifyListeners();
        }
      }
    }

    var waitedSeconds = 0.0;
    try {
      // 统一重试入口：仅 429 / 5xx / 超时 / 网络中断按退避重试，
      // 其余 4xx 直接报错；已收到首 token 的流式中断不重试（见 _consumeWithRetry）。
      await _consumeWithRetry(
        endpointName: endpoint.name,
        initialSettings: chatSettings,
        consume: consume,
        hasOutput: () =>
            accumulatedContent.isNotEmpty || accumulatedReasoning.isNotEmpty,
        resetOutput: () {
          accumulatedContent = '';
          accumulatedReasoning = '';
          promptTokens = 0;
          completionTokens = 0;
          firstTokenMs = null;
          tokensPerSecond = null;
        },
        onWaited: (d) => waitedSeconds += d.inMilliseconds / 1000.0,
      );

      // 生成完成，保存到数据库
      final finalIndex = _messages.indexWhere((m) => m.id == assistantMsg.id);
      if (finalIndex != -1) {
        final finalMsg = _messages[finalIndex].copyWith(
          isGenerating: false,
          promptTokens: promptTokens > 0 ? promptTokens : null,
          completionTokens: completionTokens > 0 ? completionTokens : null,
          firstTokenMs: firstTokenMs,
          tokensPerSecond: tokensPerSecond,
          updatedAt: DateTime.now(),
        );
        _messages[finalIndex] = finalMsg;
        await _db.saveMessage(conv.id, finalMsg);
      }

      // 更新对话的最后消息时间
      final updatedConv = conv.copyWith(
        lastMessageAt: DateTime.now(),
        lastMessagePreview: _truncatePreview(accumulatedContent),
      );
      _currentConversation = updatedConv;
      await _db.saveConversation(updatedConv);
    } catch (e) {
      // 错误处理
      final errorIndex = _messages.indexWhere((m) => m.id == assistantMsg.id);
      if (errorIndex != -1) {
        _messages[errorIndex] = _messages[errorIndex].copyWith(
          content: accumulatedContent.isNotEmpty
              ? '$accumulatedContent\n\n**生成失败**: '
                  '${_formatError(e, waitedSeconds: waitedSeconds)}'
              : '生成失败: ${_formatError(e, waitedSeconds: waitedSeconds)}',
          isError: true,
          isGenerating: false,
          variant: MessageVariant.error,
          updatedAt: DateTime.now(),
        );
        await _db.saveMessage(conv.id, _messages[errorIndex]);
      }
    } finally {
      _isGenerating = false;
      _isStopRequested = false;
      await loadConversations();
      notifyListeners();
    }
  }

  /// 重新生成指定消息
  ///
  /// 返回 false 表示同一对话已有进行中的请求（被串行锁拦截）。
  Future<bool> regenerateMessage(String messageId) async {
    final current = _currentConversation;
    if (current == null) return false;

    if (!_requestLock.tryAcquire(current.id)) {
      debugPrint('[Retry] 对话 ${current.id} 已有进行中的请求，拦截本次重新生成');
      notifyListeners();
      return false;
    }
    try {
      await _regenerateMessageInner(messageId);
      return true;
    } finally {
      _requestLock.release(current.id);
    }
  }

  /// [regenerateMessage] 的实际执行体（调用方已持有该对话的请求锁）。
  Future<void> _regenerateMessageInner(String messageId) async {
    final msgIndex = _messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final targetMsg = _messages[msgIndex];
    if (targetMsg.role != MessageRole.assistant) return;

    // 找到该消息之前的最后一条用户消息
    ChatMessage? userMsg;
    for (int i = msgIndex - 1; i >= 0; i--) {
      if (_messages[i].role == MessageRole.user) {
        userMsg = _messages[i];
        break;
      }
    }
    if (userMsg == null) return;

    // 重置目标消息
    _messages[msgIndex] = targetMsg.copyWith(
      content: '',
      reasoning: '',
      isError: false,
      isGenerating: true,
      variant: MessageVariant.standard,
      promptTokens: null,
      completionTokens: null,
      updatedAt: DateTime.now(),
    );
    _isGenerating = true;
    _isStopRequested = false;
    notifyListeners();

    // 获取上下文
    final conv = _currentConversation!;
    final character = _characterProvider?.getCharacter(conv.characterId) ??
        _db.getCharacter(conv.characterId);
    if (character == null) {
      _finishWithError(targetMsg.id, '未找到角色信息');
      return;
    }

    final endpoint = _resolveEndpoint();
    if (endpoint == null) {
      _finishWithError(targetMsg.id, '未配置 API 端点');
      return;
    }
    if (!AppFeatureFlags.localDeployEnabled &&
        endpoint.mode == EndpointMode.deploy) {
      _finishWithError(targetMsg.id, '本地部署已停用，请改用接入型端点');
      return;
    }

    final modelId = _resolveModelId(endpoint);
    if (modelId == null) {
      _finishWithError(targetMsg.id, '未选择模型');
      return;
    }

    // Persona（重新生成与发送同源：绑定 > 激活 > 账号昵称兜底）
    final persona = resolvePersona(conv.settings.personaId ?? character.personaId);

    // 组装请求：本地模型走独立组装层（与发送路径同口径）
    final visibleHistory = _messages
        .sublist(0, msgIndex)
        .toList();
    final adapter = _apiService.getAdapter(endpoint);
    final localPrompt = await _buildLocalPrompt(
      adapter: adapter,
      endpoint: endpoint,
      conversationId: conv.id,
      character: character,
      history: visibleHistory,
      userMessage: userMsg.content,
      settings: conv.settings,
    );

    final List<Map<String, dynamic>> messages;
    if (localPrompt != null) {
      messages = localPrompt.messages;
      adapter.setLocalSystemPrompt(localPrompt.systemPrompt);
    } else {
      // 两遍拼装第一遍:先拼完整 system 文本(与发送路径同口径)
      final assembled = PromptService.assembleSystem(
        character: character,
        history: visibleHistory,
        userMessage: userMsg.content,
        persona: persona,
        systemPromptOverride: conv.settings.systemPrompt,
        jailbreakPrompt: conv.settings.jailbreakPrompt,
        lorebook:
            resolveLorebook(conv.settings.lorebookId ?? character.lorebookId),
        preset: resolvePreset(conv.settings.presetId),
      );

      // system 区真实占用(与发送路径同口径)
      final reservedForSystem =
          PromptService.estimateSystemTokens(assembled);

      // 历史消息（用户消息之前的 + 用户消息本身）+ 上下文窗口裁剪
      final historyMessages = ContextWindowService.trim(
        visibleHistory,
        maxTokens: _resolveContextWindow(endpoint, modelId),
        reservedForSystem: reservedForSystem,
      );

      // 复用第一遍拼装结果
      messages = PromptService.buildMessages(
        character: character,
        history: historyMessages,
        userMessage: userMsg.content,
        userAttachments: userMsg.attachments,
        persona: persona,
        systemPromptOverride: conv.settings.systemPrompt,
        jailbreakPrompt: conv.settings.jailbreakPrompt,
        assembled: assembled,
      );
    }

    final chatSettings = conv.settings;

    int? firstTokenMs;
    double? tokensPerSecond;
    String accumulatedContent = '';
    String accumulatedReasoning = '';

    // 单次流式消费。采样参数被模型拒绝时可带钳制后的设置重试（见下方 catch）。
    Future<void> consume(ChatSettings s) async {
      final stream = s.enableStream
          ? adapter.chatCompletionsStream(
              model: modelId,
              messages: messages,
              settings: s,
              conversationId: conv.id,
            )
          : _nonStreamToStream(adapter, modelId, messages, s,
              conversationId: conv.id);

      await for (final chunk in stream) {
        if (_isStopRequested) break;

        if (chunk.content.isNotEmpty) accumulatedContent += chunk.content;
        if (chunk.reasoning.isNotEmpty) {
          accumulatedReasoning += chunk.reasoning;
        }
        if (chunk.firstTokenMs != null) firstTokenMs = chunk.firstTokenMs;
        if (chunk.tokensPerSecond != null) {
          tokensPerSecond = chunk.tokensPerSecond;
        }

        final idx = _messages.indexWhere((m) => m.id == targetMsg.id);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            content: accumulatedContent,
            reasoning:
                accumulatedReasoning.isNotEmpty ? accumulatedReasoning : null,
          );
          notifyListeners();
        }
      }
    }

    var waitedSeconds = 0.0;
    try {
      // 与发送路径共用同一重试策略（失效判定 / 退避 / Retry-After）。
      await _consumeWithRetry(
        endpointName: endpoint.name,
        initialSettings: chatSettings,
        consume: consume,
        hasOutput: () =>
            accumulatedContent.isNotEmpty || accumulatedReasoning.isNotEmpty,
        resetOutput: () {
          accumulatedContent = '';
          accumulatedReasoning = '';
          firstTokenMs = null;
          tokensPerSecond = null;
        },
        onWaited: (d) => waitedSeconds += d.inMilliseconds / 1000.0,
      );

      final finalIndex = _messages.indexWhere((m) => m.id == targetMsg.id);
      if (finalIndex != -1) {
        final finalMsg = _messages[finalIndex].copyWith(
          isGenerating: false,
          updatedAt: DateTime.now(),
          revision: targetMsg.revision + 1,
          firstTokenMs: firstTokenMs,
          tokensPerSecond: tokensPerSecond,
        );
        _messages[finalIndex] = finalMsg;
        await _db.saveMessage(conv.id, finalMsg);
      }
    } catch (e) {
      _finishWithError(
        targetMsg.id,
        '生成失败: ${_formatError(e, waitedSeconds: waitedSeconds)}',
      );
    } finally {
      _isGenerating = false;
      _isStopRequested = false;
      await loadConversations();
      notifyListeners();
    }
  }

  /// 停止生成
  void stopGeneration() {
    _isStopRequested = true;
    // 标记最后一条生成中的消息
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isGenerating) {
        _messages[i] = _messages[i].copyWith(
          isGenerating: false,
          updatedAt: DateTime.now(),
        );
        break;
      }
    }
    notifyListeners();
  }

  /// 删除消息
  Future<void> deleteMessage(String messageId) async {
    if (_currentConversation == null) return;
    _messages.removeWhere((m) => m.id == messageId);
    await _db.deleteMessage(_currentConversation!.id, messageId);
    notifyListeners();
  }

  /// 复制消息内容
  String getMessageContent(String messageId) {
    try {
      return _messages.firstWhere((m) => m.id == messageId).content;
    } catch (_) {
      return '';
    }
  }

  // ========== 设置 ==========

  /// 设置当前使用的模型
  void setCurrentModel(String modelId) {
    _currentModelId = modelId;
    if (_currentConversation != null) {
      final updated = _currentConversation!.copyWith(modelId: modelId);
      _currentConversation = updated;
      _db.saveConversation(updated);
    }
    notifyListeners();
  }

  /// 设置当前使用的端点
  void setCurrentEndpoint(String endpointId) {
    _currentEndpointId = endpointId;
    if (_currentConversation != null) {
      final updated = _currentConversation!.copyWith(endpointId: endpointId);
      _currentConversation = updated;
      _db.saveConversation(updated);
    }
    notifyListeners();
  }

  // ========== 内部方法 ==========

  /// 解析要使用的端点
  LlmEndpoint? _resolveEndpoint() {
    final ep = _endpointProvider;
    if (ep == null) return null;

    // 优先使用对话绑定的端点
    final endpointId = _currentEndpointId ?? _currentConversation?.endpointId;
    if (endpointId != null && endpointId.isNotEmpty) {
      try {
        return ep.llmEndpoints.firstWhere((e) => e.id == endpointId);
      } catch (_) {
        // 没找到，fallthrough
      }
    }

    // 使用默认端点
    return ep.defaultLlmEndpoint;
  }

  /// 解析要使用的模型 ID
  ///
  /// 优先级：对话绑定 > 接口默认模型（defaultModelId）> 列表第一个
  String? _resolveModelId(LlmEndpoint endpoint) {
    final modelId = _currentModelId ?? _currentConversation?.modelId;
    if (modelId != null && modelId.isNotEmpty) return modelId;

    final effective = endpoint.effectiveModel;
    return effective?.id;
  }

  /// 模型上下文长度（未知时给保守值 8192）
  int _resolveContextWindow(LlmEndpoint endpoint, String modelId) {
    for (final m in endpoint.models) {
      if (m.id == modelId) return m.contextLength;
    }
    return 8192;
  }

  /// 将非流式调用转换为单块流
  Stream<StreamChatChunk> _nonStreamToStream(
    LlmApiAdapter adapter,
    String modelId,
    List<Map<String, dynamic>> messages,
    ChatSettings settings, {
    String? conversationId,
  }) async* {
    final response = await adapter.chatCompletions(
      model: modelId,
      messages: messages,
      settings: settings,
      conversationId: conversationId,
    );
    yield StreamChatChunk(
      content: response.content,
      reasoning: response.reasoning ?? '',
      promptTokens: response.promptTokens,
      completionTokens: response.completionTokens,
      firstTokenMs: response.firstTokenMs,
      tokensPerSecond: response.tokensPerSecond,
    );
    yield const StreamChatChunk(isFinal: true);
  }

  /// 本地模型（部署端点）专用组装：压缩角色卡 + 最近 4 轮 + 本轮指令。
  ///
  /// 返回 null 表示走通用 PromptService 路径（云端端点，或本地 tokenizer
  /// 不可用时降级）。上下文生命周期（复用 / 裁剪）由适配器负责。
  Future<_LocalPromptResult?> _buildLocalPrompt({
    required LlmApiAdapter adapter,
    required LlmEndpoint endpoint,
    required String conversationId,
    required Character character,
    required List<ChatMessage> history,
    required String userMessage,
    required ChatSettings settings,
  }) async {
    if (endpoint.mode != EndpointMode.deploy) return null;
    try {
      final counter = await adapter.localTokenCounter(conversationId);
      final countTokens =
          counter ?? (String text) async => (text.length / 2).ceil();
      final plan = await LocalPromptBuilder.build(
        character: character,
        history: history,
        userMessage: userMessage,
        countTokens: countTokens,
        contextSize: endpoint.contextSize,
        maxTokens: endpoint.maxTokens,
        systemPromptOverride: settings.systemPrompt,
      );
      debugPrint('[LocalPrompt] system=${plan.systemTokens} token，'
          '历史 ${plan.history.length} 条（丢 ${plan.droppedMessages}），'
          '预算 ${plan.historyBudget}，短输入=${plan.shortInput}');
      return _LocalPromptResult(
        messages: plan.fullMessages,
        systemPrompt: plan.systemPrompt,
      );
    } catch (e) {
      debugPrint('[LocalPrompt] 组装失败，回退通用路径：$e');
      return null;
    }
  }

  /// 添加错误消息（直接显示，不调用 API）
  void _addErrorMessage(String error) {
    if (_currentConversation == null) return;
    final conv = _currentConversation!;

    final errorMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conv.id,
      role: MessageRole.assistant,
      source: MessageSource.system,
      variant: MessageVariant.error,
      content: error,
      isError: true,
      isGenerating: false,
      createdAt: DateTime.now(),
    );
    _messages.add(errorMsg);
    _db.saveMessage(conv.id, errorMsg);
    notifyListeners();
  }

  /// 上游限流的最大重试次数（首次 + 3 次重试 = 最多尝试 4 次）
  static const int _maxThrottleRetries = 3;

  /// 执行一次上游请求，按统一策略重试。
  ///
  /// - 仅 429 / 5xx(500/502/503/504) / 超时 / 网络中断重试；
  ///   400/401/403/404/422 等其余 4xx 直接抛出，不浪费配额。
  /// - 等待：`Retry-After`（上限 30s）优先，否则 2s / 6s / 15s ±20% 抖动。
  /// - 已收到首 token（[hasOutput] 为 true）时绝不重试，抛
  ///   [GenerationInterruptedException]，由上层展示「生成中断」。
  /// - 采样参数被拒（400 invalid temperature 等）沿用旧的钳制重试，
  ///   单独计数，不占用上面的上游尝试次数。
  Future<void> _consumeWithRetry({
    required String endpointName,
    required ChatSettings initialSettings,
    required Future<void> Function(ChatSettings s) consume,
    required bool Function() hasOutput,
    required void Function() resetOutput,
    void Function(Duration d)? onWaited,
  }) async {
    var attemptSettings = initialSettings;
    var attempt = 0;
    var clampRetries = 0;

    while (true) {
      attempt++;
      try {
        await consume(attemptSettings);
        return;
      } catch (e) {
        final raw = _rawError(e);

        // 流式已产出内容：重发会把半截文本拼成两遍，必须报「生成中断」。
        if (hasOutput()) {
          debugPrint('[Retry] endpoint=$endpointName attempt=$attempt '
              '已收到内容，判定生成中断且不重试。raw=$raw');
          throw GenerationInterruptedException(
            '生成中断：已收到部分内容，未自动重试。\n原始信息：$raw',
          );
        }

        final clamped = _clampedSamplingSettings(attemptSettings, raw);
        if (clamped != null && clampRetries < 3) {
          clampRetries++;
          attemptSettings = clamped;
          resetOutput();
          attempt--; // 参数钳制不是上游重试，不占用尝试次数
          debugPrint('[Retry] endpoint=$endpointName 采样参数钳制后重试 '
              '($clampRetries/3) raw=$raw');
          continue;
        }

        final status = e is LlmRequestException ? e.statusCode : null;
        final category =
            e is LlmRequestException ? e.category : classifyMessage(raw);
        final retryAfter = e is LlmRequestException ? e.retryAfter : null;
        final decision = RetryPolicy.decide(
          attempt: attempt,
          statusCode: status,
          category: category,
          retryAfter: retryAfter,
        );

        if (!decision.shouldRetry) {
          debugPrint('[Retry] endpoint=$endpointName attempt=$attempt/'
              '${RetryPolicy.maxAttempts} status=${status ?? '-'} '
              '放弃：${decision.reason} raw=$raw');
          rethrow;
        }

        debugPrint('[Retry] endpoint=$endpointName attempt=$attempt/'
            '${RetryPolicy.maxAttempts} status=${status ?? '-'} '
            'wait=${(decision.delay.inMilliseconds / 1000).toStringAsFixed(1)}s '
            'retryAfter=${decision.usedRetryAfter ? 'hit' : 'miss'} '
            'reason=${decision.reason} raw=$raw');

        await Future<void>.delayed(decision.delay);
        onWaited?.call(decision.delay);

        if (_isStopRequested) {
          debugPrint('[Retry] endpoint=$endpointName 用户已停止，取消重试');
          return;
        }
      }
    }
  }

  // ========== 剧情选项 / 继续生成 ==========

  /// 选项请求的极简 system 指令（不复用角色卡，避免 token 与角色扮演干扰）。
  static const String _plotOptionsSystemPrompt = '你是剧情助手。根据对话剧情，'
      '为「用户」给出 3 个下一步行动选择。'
      '只输出严格 JSON：{"options":["…","…","…"]}，不要解释、不要代码块、不要续写正文。'
      '每条不超过 20 字，用第一人称「我要……」句式，三条方向要明显不同。';

  /// 为最后一条 AI 回复生成 3 个剧情选项。
  ///
  /// 独立的一次轻量请求：不进对话历史、不写数据库，避免污染与重复计费。
  /// [refresh] 为 true 时忽略缓存（「换一批」）。
  Future<void> generatePlotOptions({bool refresh = false}) async {
    final conv = _currentConversation;
    if (conv == null) return;

    final visible = visibleMessages;
    if (!canActOnLastReply(visible, isGenerating: _isGenerating)) return;
    final target = visible.last;

    if (_plotOptionsLoading.contains(target.id)) return;
    if (!refresh && _plotOptions.containsKey(target.id)) return;

    // 与聊天请求共用同一对话锁：免费模型并发为 1，选项请求也不能与之并行。
    if (_isGenerating || !_requestLock.tryAcquire(conv.id)) {
      _plotOptionsError[target.id] = '上一条还在生成，请稍候';
      notifyListeners();
      return;
    }

    _plotOptionsLoading.add(target.id);
    _plotOptionsError.remove(target.id);
    _isStopRequested = false;
    notifyListeners();

    var raw = '';
    try {
      final endpoint = _resolveEndpoint();
      if (endpoint == null) throw StateError('未配置 API 端点，请先在设置中添加');
      if (!AppFeatureFlags.localDeployEnabled &&
          endpoint.mode == EndpointMode.deploy) {
        throw StateError('本地部署已停用，请改用接入型端点');
      }
      final modelId = _resolveModelId(endpoint);
      if (modelId == null) throw StateError('未选择模型');
      final adapter = _apiService.getAdapter(endpoint);

      // 只带最近若干轮：独立请求不消耗主对话的上下文预算。
      final recent = ContextWindowService.trim(
        _messages
            .where((m) => !m.isHidden && !m.isError && !m.isGenerating)
            .toList(),
        maxTokens: 1200,
        reservedForSystem: 300,
        reservedForReply: 200,
      );
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': _plotOptionsSystemPrompt},
        for (final m in recent)
          {
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        {'role': 'user', 'content': '（仅生成 3 个选项，不要续写正文）'},
      ];

      final settings = ChatSettings(
        temperature: 0.8,
        maxTokens: 200,
        enableStream: false,
        showReasoning: false,
        enableToolCalling: false,
        enableReasoning: false,
      );
      await _consumeWithRetry(
        endpointName: endpoint.name,
        initialSettings: settings,
        consume: (s) async {
          final resp = await adapter.chatCompletions(
            model: modelId,
            messages: messages,
            settings: s,
            conversationId: conv.id,
          );
          raw = resp.content;
        },
        hasOutput: () => raw.trim().isNotEmpty,
        resetOutput: () => raw = '',
      );

      final options = parsePlotOptions(raw);
      if (options.isEmpty) {
        debugPrint('[PlotOptions] endpoint=${endpoint.name} 解析失败 raw=$raw');
        _plotOptionsError[target.id] = '没生成出来，再试一次';
      } else {
        _plotOptions[target.id] = options;
        _plotOptionsError.remove(target.id);
        debugPrint('[PlotOptions] endpoint=${endpoint.name} 生成 ${options.length} 条');
      }
    } catch (e) {
      debugPrint('[PlotOptions] 请求失败：${_rawError(e)}');
      _plotOptionsError[target.id] = '没生成出来，再试一次';
    } finally {
      _plotOptionsLoading.remove(target.id);
      _requestLock.release(conv.id);
      notifyListeners();
    }
  }

  /// 点击选项 = 以普通用户消息发送该条文字（复用完整发送链路）。
  ///
  /// 发送成功后清空来源 AI 消息的选项缓存。
  Future<bool> sendPlotOption(String option) async {
    final visible = visibleMessages;
    final sourceId = visible.isNotEmpty ? visible.last.id : null;
    final ok = await sendMessage(option);
    if (ok && sourceId != null) {
      _plotOptions.remove(sourceId);
      _plotOptionsError.remove(sourceId);
      notifyListeners();
    }
    return ok;
  }

  /// 去掉 "Exception: " 前缀，保留原始错误正文（供日志与用户提示）。
  String _rawError(Object e) =>
      e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  /// 采样参数被模型拒绝时，从错误信息解析服务端允许值并钳制设置。
  /// 例："invalid temperature: only 1 is allowed for this model"
  /// 　→ temperature=1；"invalid top_p: only 0.95 is allowed" → topP=0.95。
  /// 非此类错误、或设置已是允许值（避免死循环）时返回 null。
  ChatSettings? _clampedSamplingSettings(ChatSettings s, String err) {
    final m = RegExp(
      r'invalid\s+(temperature|top_p|topp|presence_penalty|frequency_penalty)\s*:\s*only\s+([\d.]+)\s+is\s+allowed',
      caseSensitive: false,
    ).firstMatch(err);
    if (m == null) return null;
    final param = m.group(1)!.toLowerCase();
    final value = double.tryParse(m.group(2)!);
    if (value == null) return null;
    switch (param) {
      case 'temperature':
        return s.temperature == value ? null : s.copyWith(temperature: value);
      case 'top_p':
      case 'topp':
        return s.topP == value ? null : s.copyWith(topP: value);
      case 'presence_penalty':
        return s.presencePenalty == value
            ? null
            : s.copyWith(presencePenalty: value);
      case 'frequency_penalty':
        return s.frequencyPenalty == value
            ? null
            : s.copyWith(frequencyPenalty: value);
      default:
        return null;
    }
  }

  /// 错误信息展示格式化：去掉 "Exception: " 前缀,保留可读正文。
  /// 限流类错误额外给出中文处置建议，并保留原始信息便于核对上游返回。
  /// [waitedSeconds] 仅在最终失败时传入，用于说明已等待时长。
  String _formatError(Object e, {double waitedSeconds = 0}) {
    final raw = _rawError(e);
    final throttled = e is LlmRequestException
        ? e.category == UpstreamErrorCategory.throttled
        : classifyMessage(raw) == UpstreamErrorCategory.throttled;
    if (throttled) {
      final waited = waitedSeconds > 0
          ? '已等待约 ${waitedSeconds.round()} 秒仍限流，建议换模型或稍后再试。\n'
          : '';
      return '上游限流：当前账号可同时处理的请求数已满，自动重试 '
          '$_maxThrottleRetries 次后仍未成功。\n$waited'
          '请稍等几秒后重新发送，或换用其它模型 / API 端点。\n\n原始信息：$raw';
    }
    return raw;
  }

  void _finishWithError(String messageId, String error) {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(
        content: error,
        isError: true,
        isGenerating: false,
        variant: MessageVariant.error,
        updatedAt: DateTime.now(),
      );
      if (_currentConversation != null) {
        _db.saveMessage(_currentConversation!.id, _messages[idx]);
      }
    }
    _isGenerating = false;
    notifyListeners();
  }

  /// 截断预览文本
  String _truncatePreview(String text, {int maxLen = 50}) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.length <= maxLen) return clean;
    return '${clean.substring(0, maxLen)}...';
  }
}

/// 本地模型单轮组装结果：消息列表（历史 + 本轮）与压缩角色卡。
class _LocalPromptResult {
  final List<Map<String, dynamic>> messages;
  final String systemPrompt;

  const _LocalPromptResult({required this.messages, required this.systemPrompt});
}

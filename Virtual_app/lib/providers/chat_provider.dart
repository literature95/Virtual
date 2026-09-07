import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/endpoint.dart';
import '../models/persona.dart';
import '../services/api_service.dart';
import '../services/prompt_service.dart';
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

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  bool _isStopRequested = false;

  String? _currentEndpointId;
  String? get currentEndpointId => _currentEndpointId;

  String? _currentModelId;
  String? get currentModelId => _currentModelId;

  ChatProvider(this._db) : _apiService = ApiService();

  /// 更新依赖的 Provider
  void updateDependencies(
    SettingsProvider settings,
    CharacterProvider characterProvider,
    EndpointProvider endpointProvider,
  ) {
    _characterProvider = characterProvider;
    _endpointProvider = endpointProvider;
    loadConversations();
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

  /// 删除对话
  Future<void> deleteConversation(String id) async {
    await _db.deleteConversation(id);
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
    if (_currentConversation?.id == conversationId) {
      _messages = [];
      notifyListeners();
    }
  }

  // ========== 消息加载 ==========

  /// 加载指定对话的消息
  Future<void> loadMessages(String conversationId) async {
    final conv = _db.getConversation(conversationId);
    if (conv == null) return;

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
        final greetingMsg = ChatMessage(
          id: _uuid.v4(),
          conversationId: conv.id,
          role: MessageRole.assistant,
          source: MessageSource.model,
          variant: MessageVariant.standard,
          content: character.firstMessage!.trim(),
          isGenerating: false,
          createdAt: DateTime.now(),
        );
        _messages.add(greetingMsg);
        await _db.saveMessage(conv.id, greetingMsg);

        // 更新对话的最后消息时间和预览
        final updatedConv = conv.copyWith(
          lastMessageAt: DateTime.now(),
          lastMessagePreview: _truncatePreview(character.firstMessage!),
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
  /// [content] 用户消息内容
  /// [images] 附带的图片路径列表
  Future<void> sendMessage(String content, {List<String>? images}) async {
    if (_currentConversation == null) return;
    if (_isGenerating) return;

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

    final modelId = _resolveModelId(endpoint);
    if (modelId == null) {
      _addErrorMessage('未选择模型');
      return;
    }

    // 3. 获取 Persona
    Persona? persona;
    final personaId = conv.settings.personaId ?? character.personaId;
    if (personaId != null && personaId.isNotEmpty) {
      persona = _db.getPersonas().firstWhere(
            (p) => p.id == personaId,
            orElse: () =>
                _db.getActivePersona() ??
                Persona(
                  id: 'default',
                  name: 'User',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
          );
    } else {
      persona = _db.getActivePersona();
    }

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

    // 6. 历史消息（排除刚添加的两条）
    final historyMessages = _messages
        .where((m) => m.id != userMsg.id && m.id != assistantMsg.id)
        .where((m) => !m.isHidden)
        .toList();

    // 7. 构建 Prompt
    final messages = PromptService.buildMessages(
      character: character,
      history: historyMessages,
      userMessage: content.trim(),
      persona: persona,
      systemPromptOverride: conv.settings.systemPrompt,
      jailbreakPrompt: conv.settings.jailbreakPrompt,
    );

    // 8. 调用 API 流式生成
    final adapter = _apiService.getAdapter(endpoint);
    final chatSettings = conv.settings;

    int promptTokens = 0;
    int completionTokens = 0;
    String accumulatedContent = '';
    String accumulatedReasoning = '';

    try {
      final stream = chatSettings.enableStream
          ? adapter.chatCompletionsStream(
              model: modelId,
              messages: messages,
              settings: chatSettings,
            )
          : _nonStreamToStream(adapter, modelId, messages, chatSettings);

      await for (final chunk in stream) {
        if (_isStopRequested) break;

        if (chunk.promptTokens != null) {
          promptTokens = chunk.promptTokens!;
        }
        if (chunk.completionTokens != null) {
          completionTokens = chunk.completionTokens!;
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

      // 生成完成，保存到数据库
      final finalIndex = _messages.indexWhere((m) => m.id == assistantMsg.id);
      if (finalIndex != -1) {
        final finalMsg = _messages[finalIndex].copyWith(
          isGenerating: false,
          promptTokens: promptTokens > 0 ? promptTokens : null,
          completionTokens: completionTokens > 0 ? completionTokens : null,
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
              ? '$accumulatedContent\n\n**生成失败**: $e'
              : '生成失败: $e',
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
  Future<void> regenerateMessage(String messageId) async {
    if (_currentConversation == null) return;
    if (_isGenerating) return;

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

    final modelId = _resolveModelId(endpoint);
    if (modelId == null) {
      _finishWithError(targetMsg.id, '未选择模型');
      return;
    }

    // Persona
    Persona? persona = _db.getActivePersona();

    // 历史消息（用户消息之前的 + 用户消息本身）
    final historyMessages =
        _messages.sublist(0, msgIndex).where((m) => !m.isHidden).toList();

    // 构建 Prompt
    final messages = PromptService.buildMessages(
      character: character,
      history: historyMessages,
      userMessage: userMsg.content,
      persona: persona,
      systemPromptOverride: conv.settings.systemPrompt,
      jailbreakPrompt: conv.settings.jailbreakPrompt,
    );

    // 流式生成
    final adapter = _apiService.getAdapter(endpoint);
    final chatSettings = conv.settings;

    String accumulatedContent = '';
    String accumulatedReasoning = '';

    try {
      final stream = chatSettings.enableStream
          ? adapter.chatCompletionsStream(
              model: modelId,
              messages: messages,
              settings: chatSettings,
            )
          : _nonStreamToStream(adapter, modelId, messages, chatSettings);

      await for (final chunk in stream) {
        if (_isStopRequested) break;

        if (chunk.content.isNotEmpty) accumulatedContent += chunk.content;
        if (chunk.reasoning.isNotEmpty) {
          accumulatedReasoning += chunk.reasoning;
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

      final finalIndex = _messages.indexWhere((m) => m.id == targetMsg.id);
      if (finalIndex != -1) {
        final finalMsg = _messages[finalIndex].copyWith(
          isGenerating: false,
          updatedAt: DateTime.now(),
          revision: targetMsg.revision + 1,
        );
        _messages[finalIndex] = finalMsg;
        await _db.saveMessage(conv.id, finalMsg);
      }
    } catch (e) {
      _finishWithError(targetMsg.id, '生成失败: $e');
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
  String? _resolveModelId(LlmEndpoint endpoint) {
    final modelId = _currentModelId ?? _currentConversation?.modelId;
    if (modelId != null && modelId.isNotEmpty) return modelId;

    // 使用端点的第一个模型
    if (endpoint.models.isNotEmpty) {
      return endpoint.models.first.id;
    }

    return null;
  }

  /// 将非流式调用转换为单块流
  Stream<StreamChatChunk> _nonStreamToStream(
    LlmApiAdapter adapter,
    String modelId,
    List<Map<String, dynamic>> messages,
    ChatSettings settings,
  ) async* {
    final response = await adapter.chatCompletions(
      model: modelId,
      messages: messages,
      settings: settings,
    );
    yield StreamChatChunk(
      content: response.content,
      reasoning: response.reasoning ?? '',
      promptTokens: response.promptTokens,
      completionTokens: response.completionTokens,
    );
    yield const StreamChatChunk(isFinal: true);
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

  /// 以错误状态结束生成中的消息
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/character_provider.dart';
import '../../models/chat_message.dart';

/// 聊天页面
///
/// 展示消息列表、输入框，支持 Markdown 渲染、推理过程显示、
/// 消息操作菜单等功能。
class ChatPage extends StatefulWidget {
  final String conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isInputModeKeyboard = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadMessages(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _stopGeneration() async {
    context.read<ChatProvider>().stopGeneration();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer2<ChatProvider, CharacterProvider>(
          builder: (context, chatProvider, charProvider, _) {
            final conv = chatProvider.currentConversation;
            if (conv == null) return const Text('对话');
            final character = charProvider.findById(conv.characterId);
            return Text(character?.name ?? conv.title);
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              // TODO: 更多选项
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                if (provider.messages.isEmpty) {
                  return const Center(
                    child: Text('开始你们的对话吧'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final msg = provider.messages[index];
                    return _MessageBubble(message: msg);
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final canSend =
            !provider.isGenerating && _textController.text.trim().isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(_isInputModeKeyboard
                      ? Icons.keyboard_alt_outlined
                      : Icons.mic_none),
                  onPressed: () {
                    setState(() {
                      _isInputModeKeyboard = !_isInputModeKeyboard;
                    });
                  },
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            // TODO: 添加图片等
                          },
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (canSend) _sendMessage();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                provider.isGenerating
                    ? IconButton(
                        icon: const Icon(Icons.stop_circle),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: _stopGeneration,
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        color: canSend
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        onPressed: canSend ? _sendMessage : null,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 消息气泡组件
///
/// 根据消息角色渲染不同样式的气泡，支持 Markdown、
/// 推理过程折叠、长按操作菜单。
class _MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showReasoning = false;

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.role == MessageRole.user;
    final settings = context.watch<SettingsProvider>();
    final isBubbleStyle = settings.bubbleStyle == 'bubble';
    final showReasoningGlobal = settings.showReasoning;

    final hasReasoning =
        msg.reasoning != null && msg.reasoning!.trim().isNotEmpty;

    return GestureDetector(
      onLongPress: () => _showMessageActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) _buildAvatar(context),
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 推理过程（折叠面板）
                  if (hasReasoning && showReasoningGlobal)
                    _buildReasoningPanel(context),
                  // 消息内容
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: _buildBubbleDecoration(
                        context, isBubbleStyle, isUser, msg.isError),
                    constraints: BoxConstraints(
                      minWidth: 40,
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: _buildMessageContent(
                        context, msg, isBubbleStyle, isUser),
                  ),
                ],
              ),
            ),
            if (isUser) const SizedBox(width: 8),
            if (isUser) _buildAvatar(context),
          ],
        ),
      ),
    );
  }

  /// 构建气泡装饰
  BoxDecoration _buildBubbleDecoration(
    BuildContext context,
    bool isBubbleStyle,
    bool isUser,
    bool isError,
  ) {
    if (isBubbleStyle) {
      return BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.errorContainer
            : isUser
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      );
    } else {
      return BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isError
                ? Theme.of(context).colorScheme.error
                : isUser
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
            width: 3,
          ),
        ),
      );
    }
  }

  /// 构建消息内容
  Widget _buildMessageContent(
    BuildContext context,
    ChatMessage msg,
    bool isBubbleStyle,
    bool isUser,
  ) {
    if (msg.isGenerating && msg.content.isEmpty) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (msg.content.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isBubbleStyle && isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    // 使用 Markdown 渲染
    return MarkdownBody(
      data: msg.content,
      selectable: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: textColor, fontSize: 15, height: 1.5),
        h1: TextStyle(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        code: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: isBubbleStyle && isUser
              ? Colors.white.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        ),
        codeblockDecoration: BoxDecoration(
          color: isBubbleStyle && isUser
              ? Colors.white.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        listBullet: TextStyle(color: textColor),
        blockquote: TextStyle(color: textColor),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: textColor.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
        a: TextStyle(
          color: isBubbleStyle && isUser
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        strong: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        em: TextStyle(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  /// 构建推理过程折叠面板
  Widget _buildReasoningPanel(BuildContext context) {
    final msg = widget.message;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .tertiaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _showReasoning = !_showReasoning;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_alt,
                    size: 16,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '推理过程',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showReasoning ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ],
              ),
            ),
          ),
          if (_showReasoning)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: MarkdownBody(
                data: msg.reasoning!,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onTertiaryContainer
                        .withValues(alpha: 0.85),
                    fontStyle: FontStyle.italic,
                  ),
                  code: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    backgroundColor: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
          if (msg.isGenerating && _showReasoning)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatar(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.role == MessageRole.user;
    final charProvider = context.watch<CharacterProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final conv = chatProvider.currentConversation;

    String? avatarPath;
    String initial = '';

    if (isUser) {
      initial = 'U';
    } else if (conv != null) {
      final character = charProvider.getCharacter(conv.characterId);
      avatarPath = character?.avatarPath;
      initial = character?.name.isNotEmpty == true
          ? character!.name.substring(0, 1).toUpperCase()
          : 'AI';
    } else {
      initial = 'AI';
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: avatarPath != null ? null : null, // TODO: 文件路径头像支持
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isUser
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  /// 显示消息操作菜单
  void _showMessageActions(BuildContext context) {
    final msg = widget.message;
    final chatProvider = context.read<ChatProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制内容'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已复制到剪贴板'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (msg.role == MessageRole.assistant && !msg.isGenerating)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新生成'),
                onTap: () {
                  Navigator.pop(context);
                  chatProvider.regenerateMessage(msg.id);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text('删除消息',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, chatProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 确认删除消息
  void _confirmDelete(BuildContext context, ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              chatProvider.deleteMessage(widget.message.id);
              Navigator.pop(context);
            },
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

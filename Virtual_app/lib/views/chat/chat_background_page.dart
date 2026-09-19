import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/chat_theme.dart';
import '../../providers/chat_provider.dart';
import '../../theme/design_tokens.dart';
import '../common/inset_app_bar.dart';
import 'chat_background.dart';

/// 「对话背景」设置页
///
/// 按**对话**维度设置背景：内置渐变预设 / 图片 URL / 本地图片，
/// 叠加不透明度与模糊档位。存储走 `ChatProvider.saveConversationBackground`，
/// 最终落在主题表里由对话 id 派生的条目上（不新增数据表、不改 Conversation 模型）。
class ChatBackgroundPage extends StatefulWidget {
  final String conversationId;

  const ChatBackgroundPage({super.key, required this.conversationId});

  @override
  State<ChatBackgroundPage> createState() => _ChatBackgroundPageState();
}

class _ChatBackgroundPageState extends State<ChatBackgroundPage> {
  String? _image;
  double _opacity = 1.0;
  ChatBackgroundBlur _blur = ChatBackgroundBlur.none;
  final _urlController = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final bg = context
        .read<ChatProvider>()
        .conversationBackground(widget.conversationId);
    if (bg != null) {
      _image = bg.backgroundImage;
      _opacity = bg.backgroundOpacity;
      _blur = bg.backgroundBlur;
      final raw = bg.backgroundImage ?? '';
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        _urlController.text = raw;
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  ChatTheme get _draft => ChatTheme(
        id: '',
        name: '对话背景',
        backgroundImage: _image,
        backgroundOpacity: _opacity,
        backgroundBlur: _blur,
      );

  Future<void> _pickLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        dialogTitle: '选择背景图片',
      );
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      setState(() {
        _image = path;
        _urlController.clear();
      });
    } catch (_) {
      // 用户取消或平台不支持
    }
  }

  void _applyUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入以 http:// 或 https:// 开头的图片直链')),
      );
      return;
    }
    setState(() => _image = url);
  }

  Future<void> _clear() async {
    await context
        .read<ChatProvider>()
        .clearConversationBackground(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _image = null;
      _opacity = 1.0;
      _blur = ChatBackgroundBlur.none;
      _urlController.clear();
    });
  }

  Future<void> _save() async {
    await context
        .read<ChatProvider>()
        .saveConversationBackground(widget.conversationId, _draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('对话背景已保存'), duration: Duration(seconds: 1)),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasBackground = _image != null && _image!.trim().isNotEmpty;

    return Scaffold(
      appBar: InsetAppBar(
        title: const Text('对话背景'),
        actions: [
          IconButton(
            tooltip: '清除背景',
            icon: const Icon(Icons.layers_clear_outlined),
            onPressed: hasBackground ? _clear : null,
          ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── 预览 ──
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              height: 168,
              width: double.infinity,
              color: scheme.surfaceContainerHighest,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasBackground)
                    ChatBackgroundLayer(theme: _draft)
                  else
                    Center(
                      child: Text(
                        '无背景',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  // 模拟气泡，便于判断对比度是否合适
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _previewBubble('这是角色的回复', scheme.secondaryContainer,
                            scheme.onSecondaryContainer),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _previewBubble('这是我的消息',
                              scheme.primaryContainer, scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '当前来源：${ChatBackgroundLayer.describeSource(_image)}',
            style: TextStyle(fontSize: AppFontSize.caption,
                color: scheme.onSurfaceVariant),
          ),

          _sectionTitle(context, '渐变预设'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final preset in kChatBackgroundPresets)
                _PresetSwatch(
                  preset: preset,
                  selected: _image ==
                      '${ChatBackgroundLayer.presetPrefix}${preset.id}',
                  onTap: () => setState(() {
                    _image =
                        '${ChatBackgroundLayer.presetPrefix}${preset.id}';
                    _urlController.clear();
                  }),
                ),
            ],
          ),

          _sectionTitle(context, '图片'),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: '图片直链（http/https）',
              hintText: 'https://example.com/bg.jpg',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: '应用',
                icon: const Icon(Icons.check),
                onPressed: _applyUrl,
              ),
            ),
            onSubmitted: (_) => _applyUrl(),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _pickLocalFile,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('从本地选择图片'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '提示：本地图片路径仅在桌面 / 移动端可用；网页版请使用图片直链或渐变预设。',
              style: TextStyle(fontSize: AppFontSize.caption,
                  color: scheme.onSurfaceVariant),
            ),
          ),

          _sectionTitle(context, '不透明度'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  label: '${(_opacity * 100).round()}%',
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text('${(_opacity * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),

          _sectionTitle(context, '模糊'),
          SegmentedButton<ChatBackgroundBlur>(
            segments: const [
              ButtonSegment(value: ChatBackgroundBlur.none, label: Text('无')),
              ButtonSegment(value: ChatBackgroundBlur.light, label: Text('轻')),
              ButtonSegment(value: ChatBackgroundBlur.medium, label: Text('中')),
              ButtonSegment(value: ChatBackgroundBlur.heavy, label: Text('重')),
            ],
            selected: {_blur},
            onSelectionChanged: (s) => setState(() => _blur = s.first),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _previewBubble(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: AppFontSize.body)),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.sm),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppFontSize.label,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  final ChatBackgroundPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        width: 86,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 36,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: preset.colors,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(preset.label, style: const TextStyle(fontSize: AppFontSize.caption)),
          ],
        ),
      ),
    );
  }
}

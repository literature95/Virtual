import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/amap_location_service.dart';
import '../../services/community_api_service.dart';
import '../../theme/design_tokens.dart';
import '../common/inset_app_bar.dart';

/// 全页「发布动态」——替代原先的 AlertDialog。
///
/// 布局对齐常见社区 App：顶栏返回 + 发布，大标题栏 + 正文区，
/// 底部分区/话题 chips。发布成功时 `Navigator.pop` 返回新建帖子。
class ComposePostPage extends StatefulWidget {
  const ComposePostPage({super.key});

  @override
  State<ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends State<ComposePostPage> {
  static const int _titleMax = 30;

  final _titleC = TextEditingController();
  final _contentC = TextEditingController();
  final _api = CommunityApiService();
  String _community = '综合';
  bool _submitting = false;
  AmapPlace? _place;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录后再发动态')),
        );
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _titleC.dispose();
    _contentC.dispose();
    super.dispose();
  }

  Future<void> _toggleLocation() async {
    if (_locating) return;
    if (_place != null) {
      setState(() => _place = null);
      return;
    }
    // 高德隐私合规：首次使用前需用户同意
    if (!await AmapLocationService.isPrivacyAccepted()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('使用定位'),
          content: const Text(
            '发动态时可附加当前位置。\n\n'
            '定位用于高德地图基础定位/逆地理服务，'
            '将获取设备位置并转换为可读地址。是否同意？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('暂不'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('同意并继续'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await AmapLocationService.acceptPrivacy();
    }

    setState(() => _locating = true);
    try {
      final place = await AmapLocationService.locate();
      if (!mounted) return;
      setState(() => _place = place);
      if (place != null && place.isCoordsOnly && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '已获取坐标。若需街道地址，请在高德控制台新建「Web服务」Key 并配置到 App',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _publish() async {
    if (_submitting) return;
    final title = _titleC.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写标题')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>();
    final token = auth.token;
    if (token == null) {
      context.go('/login');
      return;
    }

    setState(() => _submitting = true);
    try {
      final post = await _api.createPost(
        settings.backendBaseUrl,
        token,
        title: title,
        content: _contentC.text.trim(),
        community: _community,
        location: _place?.toJson(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发布到社区')),
      );
      Navigator.of(context).pop(post);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: InsetAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('发布动态'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _submitting ? null : _publish,
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '发布',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                AppSpacing.lg, 0),
            child: TextField(
              controller: _titleC,
              maxLength: _titleMax,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: '填写标题',
                border: InputBorder.none,
                counterText: '',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // 字数
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_titleC.text.characters.length}/$_titleMax',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          // 正文
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: TextField(
                controller: _contentC,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '添加正文…\n\n可以分享你的角色卡、对话片段或心情',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          // 分区 / 话题 + 定位
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '添加分区及话题',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ActionChip(
                  avatar: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _place == null
                              ? Icons.location_on_outlined
                              : Icons.location_on,
                          size: 18,
                          color: _place == null
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      _locating
                          ? '定位中…'
                          : (_place?.label ?? '所在位置'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _place == null
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  onPressed: _toggleLocation,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: communityCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = communityCategories[i];
                final selected = c.name == _community;
                return ChoiceChip(
                  label: Text(c.name),
                  selected: selected,
                  onSelected: (_) => setState(() => _community = c.name),
                  selectedColor: c.color.withValues(alpha: 0.22),
                  labelStyle: TextStyle(
                    color: selected ? c.color : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: selected
                        ? c.color
                        : scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
        ],
      ),
    );
  }
}

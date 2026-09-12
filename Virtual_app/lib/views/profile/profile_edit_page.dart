import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_api_service.dart';
import '../../theme/tavo_brand.dart';

/// 个人信息编辑（点击「我的」页头像 / 昵称进入）
///
/// 可编辑：昵称、个人简介、头像 URL。保存后通过 AuthProvider 即时同步本地登录态，
/// 「我的」页头像与昵称随之刷新（无需重新登录）。
/// 已登录专属页；未登录进入会被引导回登录页。
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nickname;
  late final TextEditingController _bio;
  late final TextEditingController _avatar;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user;
    _nickname = TextEditingController(text: u?.nickname ?? '');
    _bio = TextEditingController(text: u?.bio ?? '');
    _avatar = TextEditingController(text: u?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = '昵称不能为空');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final backend = context.read<SettingsProvider>().backendBaseUrl;
      await context.read<AuthProvider>().updateProfile(
            backend,
            nickname: nickname,
            bio: _bio.text.trim(),
            avatarUrl: _avatar.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
      context.pop();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('个人信息')),
        body: _loginPrompt(context, scheme),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人信息'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _avatarPreview(scheme, auth.user),
          const SizedBox(height: 20),
          if (_error != null) ...[
            _errorBanner(scheme, _error!),
            const SizedBox(height: 14),
          ],
          _fieldLabel(scheme, '昵称'),
          const SizedBox(height: 6),
          TextField(
            controller: _nickname,
            maxLength: 24,
            decoration: _inputDecoration(scheme, '展示给他人的名字'),
          ),
          const SizedBox(height: 10),
          _fieldLabel(scheme, '个人简介'),
          const SizedBox(height: 6),
          TextField(
            controller: _bio,
            maxLines: 4,
            maxLength: 200,
            decoration: _inputDecoration(scheme, '一句话介绍自己（可留空）'),
          ),
          const SizedBox(height: 10),
          _fieldLabel(scheme, '头像图片 URL'),
          const SizedBox(height: 6),
          TextField(
            controller: _avatar,
            decoration: _inputDecoration(scheme, 'https://…（留空则用品牌首字母头像）'),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            '提示：填入图片直链即可生效；留空恢复默认的品牌首字母头像。',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 26),
          _sectionCard(
            scheme,
            children: [
              _navRow(
                scheme: scheme,
                icon: Icons.lock_outline,
                iconColor: TavoColors.coral,
                title: '修改密码',
                desc: '验证当前密码后设置新密码',
                onTap: () => context.push('/profile/password'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '账号邮箱：${auth.user!.email}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _avatarPreview(ColorScheme scheme, AuthUser? user) {
    final url = _avatar.text.trim().isEmpty
        ? (user?.avatarUrl ?? '')
        : _avatar.text.trim();
    final letter = (user?.nickname?.isNotEmpty == true)
        ? user!.nickname!.characters.first
        : (user?.email.isNotEmpty == true ? user!.email.characters.first : 'V');
    return Center(
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          gradient: url.isEmpty ? TavoColors.signGradientDiagonal : null,
          color: url.isEmpty ? null : scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(999),
            topRight: Radius.circular(999),
            bottomLeft: Radius.circular(999),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: TavoColors.violet.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: url.isEmpty
            ? Text(
                letter,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF141414),
                ),
              )
            : Image.network(
                url,
                width: 92,
                height: 92,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141414),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _loginPrompt(BuildContext context, ColorScheme scheme) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('登录后可编辑个人信息',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/login'),
              child: const Text('去登录'),
            ),
          ],
        ),
      );

  Widget _errorBanner(ColorScheme scheme, String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onErrorContainer)),
            ),
          ],
        ),
      );

  Widget _fieldLabel(ColorScheme scheme, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      );

  InputDecoration _inputDecoration(ColorScheme scheme, String hint) =>
      InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _sectionCard(ColorScheme scheme, {required List<Widget> children}) =>
      Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(children: children),
      );

  Widget _navRow({
    required ColorScheme scheme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: iconColor.withValues(alpha: 0.13),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface)),
                    const SizedBox(height: 1),
                    Text(desc,
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      );
}

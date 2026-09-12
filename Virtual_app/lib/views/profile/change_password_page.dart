import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_api_service.dart';

/// 修改密码（「个人信息」→「修改密码」进入）
///
/// 双通道：
///  - 常规改密：输入当前密码 + 新密码（已登录）
///  - 忘记密码：邮箱验证码 → 重置（未登录亦可用；已登录时邮箱自动带入且不可改）
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // 常规改密
  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  // 忘记密码（验证码）
  final _emailC = TextEditingController();
  final _codeC = TextEditingController();
  final _resetNewC = TextEditingController();

  bool _oldMode = true; // true=常规改密，false=验证码重置
  bool _busy = false;
  bool _sending = false;
  String? _error;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _emailC.text = context.read<AuthProvider>().user?.email ?? '';
  }

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    _emailC.dispose();
    _codeC.dispose();
    _resetNewC.dispose();
    super.dispose();
  }

  String get _backend => context.read<SettingsProvider>().backendBaseUrl;

  Future<void> _sendCode() async {
    final email = _emailC.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '请输入邮箱');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final dev = await context
          .read<AuthProvider>()
          .sendCode(_backend, email, purpose: 'reset');
      if (!mounted) return;
      setState(() => _cooldown = 60);
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dev != null ? '验证码（本地调试）：$dev' : '验证码已发送至邮箱'),
          duration: const Duration(seconds: 5),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '发送失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldown--);
      return _cooldown > 0;
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_oldMode) {
      return _submitChange();
    }
    return _submitReset();
  }

  Future<void> _submitChange() async {
    if (_oldC.text.isEmpty) {
      setState(() => _error = '请输入当前密码');
      return;
    }
    if (_newC.text.length < 6) {
      setState(() => _error = '新密码至少 6 位');
      return;
    }
    if (_newC.text != _confirmC.text) {
      setState(() => _error = '两次输入的新密码不一致');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().changePassword(
            _backend,
            oldPassword: _oldC.text,
            newPassword: _newC.text,
          );
      if (!mounted) return;
      _ok('密码已修改');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '修改失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitReset() async {
    if (_emailC.text.trim().isEmpty) {
      setState(() => _error = '请输入邮箱');
      return;
    }
    if (_codeC.text.trim().isEmpty) {
      setState(() => _error = '请输入验证码');
      return;
    }
    if (_resetNewC.text.length < 6) {
      setState(() => _error = '新密码至少 6 位');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().resetPassword(
            _backend,
            email: _emailC.text.trim(),
            code: _codeC.text.trim(),
            newPassword: _resetNewC.text,
          );
      if (!mounted) return;
      _ok('密码已重置');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '重置失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _ok(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('修改密码')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _modeSwitch(scheme),
          const SizedBox(height: 18),
          if (_error != null) ...[
            _errorBanner(scheme, _error!),
            const SizedBox(height: 14),
          ],
          if (_oldMode) ..._changeForm(scheme, loggedIn) else ..._resetForm(scheme),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_oldMode ? '确认修改' : '重置密码'),
          ),
        ],
      ),
    );
  }

  Widget _modeSwitch(ColorScheme scheme) => SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('当前密码'), icon: Icon(Icons.lock_outline, size: 18)),
          ButtonSegment(value: false, label: Text('忘记密码'), icon: Icon(Icons.mark_email_read_outlined, size: 18)),
        ],
        selected: {_oldMode},
        onSelectionChanged: (s) => setState(() {
          _oldMode = s.first;
          _error = null;
        }),
      );

  List<Widget> _changeForm(ColorScheme scheme, bool loggedIn) {
    if (!loggedIn) {
      return [
        Text('未登录状态下无法使用当前密码修改，请改用「忘记密码」通道。',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      ];
    }
    return [
      _label(scheme, '当前密码'),
      const SizedBox(height: 6),
      _pwdField(_oldC, scheme, '请输入当前密码', (v) => setState(() => _error = null)),
      const SizedBox(height: 14),
      _label(scheme, '新密码'),
      const SizedBox(height: 6),
      _pwdField(_newC, scheme, '至少 6 位', (v) => setState(() => _error = null)),
      const SizedBox(height: 14),
      _label(scheme, '确认新密码'),
      const SizedBox(height: 6),
      _pwdField(_confirmC, scheme, '再次输入新密码', (v) => setState(() => _error = null)),
    ];
  }

  List<Widget> _resetForm(ColorScheme scheme) => [
        _label(scheme, '邮箱'),
        const SizedBox(height: 6),
        TextField(
          controller: _emailC,
          enabled: false,
          decoration: _decoration(scheme, '注册邮箱'),
        ),
        const SizedBox(height: 14),
        _label(scheme, '验证码'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeC,
                decoration: _decoration(scheme, '6 位数字'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: (_sending || _cooldown > 0) ? null : _sendCode,
                child: Text(
                  _sending
                      ? '发送中'
                      : (_cooldown > 0 ? '$_cooldown s' : '获取验证码'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label(scheme, '新密码'),
        const SizedBox(height: 6),
        _pwdField(_resetNewC, scheme, '至少 6 位', (v) => setState(() => _error = null)),
      ];

  Widget _pwdField(TextEditingController c, ColorScheme scheme, String hint,
          ValueChanged<String> onChanged) =>
      TextField(
        controller: c,
        obscureText: true,
        onChanged: onChanged,
        decoration: _decoration(scheme, hint),
      );

  Widget _label(ColorScheme scheme, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      );

  InputDecoration _decoration(ColorScheme scheme, String hint) =>
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  style:
                      TextStyle(fontSize: 13, color: scheme.onErrorContainer)),
            ),
          ],
        ),
      );
}

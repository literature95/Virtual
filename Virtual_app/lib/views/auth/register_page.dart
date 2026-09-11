import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/tavo_brand.dart';

/// 注册页 —— 邮箱 + 验证码 + 密码（验证码走后端邮箱发送）
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Timer? _cooldownTimer;
  int _cooldown = 0;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = '请先输入有效邮箱');
      return;
    }
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    try {
      final devCode =
          await context.read<AuthProvider>().sendCode(backend, email);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(devCode == null
            ? '验证码已发送，请查收邮箱（含垃圾箱）'
            : '后端未配置 SMTP，验证码（开发模式）：$devCode'),
      ));
      setState(() => _cooldown = 60);
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    try {
      await context.read<AuthProvider>().register(
            backend,
            email: _emailCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            password: _passwordCtrl.text,
            nickname: _nicknameCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，已自动登录')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = context.watch<AuthProvider>().busy;

    return Scaffold(
      appBar: AppBar(title: const Text('邮箱注册')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        TavoColors.signGradient.createShader(bounds),
                    child: const Text(
                      '创建账号',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(Icons.alternate_email, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? '请输入有效邮箱' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            prefixIcon:
                                Icon(Icons.verified_outlined, size: 20),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length != 6)
                                  ? '6 位验证码'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: OutlinedButton(
                          onPressed:
                              _cooldown > 0 || busy ? null : _sendCode,
                          child: Text(
                            _cooldown > 0 ? '重发(${_cooldown}s)' : '获取验证码',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: '密码（至少 6 位）',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? '密码至少 6 位' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nicknameCtrl,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: '昵称（可选）',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: scheme.error, fontSize: 12.5),
                    ),
                  ],
                  const SizedBox(height: 22),
                  TavoBrand.gradientButton(
                    onPressed: busy ? null : _submit,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text('注册并登录',
                            style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '已有账号？',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('直接登录'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

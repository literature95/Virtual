import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/tavo_brand.dart';

/// 登录页 —— 邮箱 + 密码；未注册走 /register（邮箱验证码）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    try {
      await context.read<AuthProvider>().login(
            backend,
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
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
      appBar: AppBar(title: const Text('登录')),
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
                      '欢迎回来',
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
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '请输入密码' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                          color: scheme.error, fontSize: 12.5),
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
                        : const Text('登录', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '还没有账号？',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text('邮箱注册'),
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

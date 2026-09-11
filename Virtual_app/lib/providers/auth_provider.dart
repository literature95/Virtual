import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_api_service.dart';

/// 登录态：token + 用户信息，SharedPreferences 持久化
///
/// 本地优先原则下的可选账号层：未登录时所有本地功能照常，
/// 登录后「我的」展示真实身份，后续云端同步以此为基础。
class AuthProvider extends ChangeNotifier {
  static const _kSession = 'auth_session';

  final SharedPreferences _prefs;
  final AuthApiService _api = AuthApiService();

  AuthUser? user;
  String? token;
  bool busy = false;

  AuthProvider(this._prefs) {
    _restore();
  }

  bool get isLoggedIn => token != null && user != null;

  void _restore() {
    final raw = _prefs.getString(_kSession);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      token = data['token']?.toString();
    } catch (_) {
      _prefs.remove(_kSession);
    }
  }

  void _save(String token, AuthUser user) {
    this.token = token;
    this.user = user;
    _prefs.setString(_kSession, jsonEncode({'token': token, 'user': user.toJson()}));
    notifyListeners();
  }

  /// 发送验证码；返回降级模式下的 devCode（SMTP 未配置时），正常发信返回 null
  Future<String?> sendCode(String backend, String email) =>
      _api.sendCode(backend, email);

  Future<void> register(
    String backend, {
    required String email,
    required String code,
    required String password,
    String? nickname,
  }) async {
    busy = true;
    notifyListeners();
    try {
      final s = await _api.register(
        backend,
        email: email,
        code: code,
        password: password,
        nickname: nickname,
      );
      _save(s.token, s.user);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> login(
    String backend, {
    required String email,
    required String password,
  }) async {
    busy = true;
    notifyListeners();
    try {
      final s = await _api.login(backend, email: email, password: password);
      _save(s.token, s.user);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// 拉取最新用户资料；token 失效时静默清除登录态
  Future<void> refresh(String backend) async {
    final t = token;
    if (t == null) return;
    final u = await _api.me(backend, t);
    if (u == null) {
      await logout();
      return;
    }
    user = u;
    _prefs.setString(
        _kSession, jsonEncode({'token': t, 'user': u.toJson()}));
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    user = null;
    await _prefs.remove(_kSession);
    notifyListeners();
  }
}

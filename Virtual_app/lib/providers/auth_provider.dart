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
  final AuthApiService _api;

  AuthUser? user;
  String? token;
  bool busy = false;

  /// [api] 可注入（测试用假服务），默认真实网络实现
  AuthProvider(this._prefs, {AuthApiService? api})
      : _api = api ?? AuthApiService() {
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
  Future<String?> sendCode(String backend, String email,
          {String purpose = 'register'}) =>
      _api.sendCode(backend, email, purpose: purpose);

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

  /// 启动时校验本地恢复的会话（_restore 只读本地、不验真）：
  /// token 已失效（/api/auth/me 返回 401）则静默清除登录态，
  /// 避免后端重启/数据重置后「我的」页仍显示已失效的账号。
  /// 网络异常时保留本地会话——离线不应丢失登录态，下次启动再校验。
  Future<void> validateSession(String backend) async {
    final t = token;
    if (t == null) return;
    try {
      final u = await _api.me(backend, t);
      if (u == null) {
        await logout();
        return;
      }
      user = u;
      _prefs.setString(
          _kSession, jsonEncode({'token': t, 'user': u.toJson()}));
      notifyListeners();
    } catch (_) {
      // 网络不通 / 后端未启动：保留会话，不视为登出
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

  /// 更新个人资料并同步本地登录态（昵称 / 简介 / 头像）
  Future<void> updateProfile(
    String backend, {
    String? nickname,
    String? bio,
    String? avatarUrl,
  }) async {
    final t = token;
    if (t == null) throw AuthException('请先登录');
    busy = true;
    notifyListeners();
    try {
      final u = await _api.updateProfile(
        backend,
        t,
        nickname: nickname,
        bio: bio,
        avatarUrl: avatarUrl,
      );
      user = u;
      await _prefs.setString(
          _kSession, jsonEncode({'token': t, 'user': u.toJson()}));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// 修改密码（需旧密码）。成功后 token 仍有效，无需重新登录。
  Future<void> changePassword(
    String backend, {
    required String oldPassword,
    required String newPassword,
  }) async {
    final t = token;
    if (t == null) throw AuthException('请先登录');
    await _api.changePassword(backend, t,
        oldPassword: oldPassword, newPassword: newPassword);
  }

  /// 重置密码（未登录，邮箱验证码）
  Future<void> resetPassword(
    String backend, {
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _api.resetPassword(backend,
          email: email, code: code, newPassword: newPassword);
}

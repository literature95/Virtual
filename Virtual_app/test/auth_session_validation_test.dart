import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/providers/auth_provider.dart';
import 'package:virtual/services/auth_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 会话启动校验（validateSession）回归：
/// _restore 只读本地不验真，后端重启/数据重置后旧 token 已失效，
/// 若不校验「我的」页会一直显示已失效的账号（假登录态）。
class FakeAuthApi extends AuthApiService {
  final AuthUser? Function() onMe;
  FakeAuthApi(this.onMe);

  @override
  Future<AuthUser?> me(String backend, String token) async => onMe();
}

Future<AuthProvider> _restoreSession(SharedPreferences prefs) async {
  await prefs.setString(
    'auth_session',
    jsonEncode({
      'token': 'stale-token',
      'user': {'id': 'u1', 'email': 'a@b.c', 'nickname': '旧昵称'},
    }),
  );
  return AuthProvider(prefs, api: FakeAuthApi(() => null));
}

void main() {
  test('token 失效（401→null）：validateSession 清除登录态并删掉本地会话',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = await _restoreSession(prefs);

    expect(auth.isLoggedIn, isTrue, reason: '_restore 恢复了本地会话');

    await auth.validateSession('http://localhost:8080');

    expect(auth.isLoggedIn, isFalse);
    expect(prefs.getString('auth_session'), isNull);
  });

  test('网络异常：保留本地会话（离线不应丢失登录态）', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'auth_session',
      jsonEncode({
        'token': 'tok',
        'user': {'id': 'u1', 'email': 'a@b.c', 'nickname': '昵称'},
      }),
    );
    final auth = AuthProvider(
      prefs,
      api: FakeAuthApi(() => throw AuthException('无法连接后端')),
    );

    expect(auth.isLoggedIn, isTrue);

    await auth.validateSession('http://localhost:8080');

    expect(auth.isLoggedIn, isTrue);
    expect(prefs.getString('auth_session'), isNotNull);
  });

  test('token 有效：保留登录态并用最新资料刷新本地', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'auth_session',
      jsonEncode({
        'token': 'tok',
        'user': {'id': 'u1', 'email': 'a@b.c', 'nickname': '旧昵称'},
      }),
    );
    final auth = AuthProvider(
      prefs,
      api: FakeAuthApi(
        () => const AuthUser(id: 'u1', email: 'a@b.c', nickname: '新昵称'),
      ),
    );

    await auth.validateSession('http://localhost:8080');

    expect(auth.isLoggedIn, isTrue);
    expect(auth.user?.nickname, '新昵称');
    final saved =
        jsonDecode(prefs.getString('auth_session')!) as Map<String, dynamic>;
    expect((saved['user'] as Map)['nickname'], '新昵称');
  });

  test('未登录（无 token）：validateSession 是 no-op', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthProvider(prefs, api: FakeAuthApi(() => null));

    await auth.validateSession('http://localhost:8080');

    expect(auth.isLoggedIn, isFalse);
  });
}

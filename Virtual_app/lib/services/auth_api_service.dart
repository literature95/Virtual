import 'package:dio/dio.dart';

/// 邮箱账号认证 API（Virtual_background /api/auth/*）
///
/// 服务端错误统一以 `{"error": "..."}` 返回，本服务解析后抛
/// [AuthException]（message 可直接展示给用户）。
class AuthUser {
  final String id;
  final String email;
  final String? nickname;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.email,
    this.nickname,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'].toString(),
        email: j['email']?.toString() ?? '',
        nickname: j['nickname']?.toString(),
        avatarUrl: j['avatarUrl']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nickname': nickname,
        'avatarUrl': avatarUrl,
      };
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// 服务端错误 → AuthException；网络错误 → 连接提示
  AuthException _wrap(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return AuthException(data['error'].toString());
    }
    return AuthException('无法连接后端，请检查网络与后端地址');
  }

  /// 发送邮箱验证码。SMTP 未配置的降级模式返回 devCode（App 可提示）。
  Future<String?> sendCode(String backend, String email) async {
    try {
      final r = await _dio.post('$backend/api/auth/send-code', data: {
        'email': email,
      });
      return r.data is Map ? r.data['devCode']?.toString() : null;
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  Future<({AuthUser user, String token})> register(
    String backend, {
    required String email,
    required String code,
    required String password,
    String? nickname,
  }) async {
    try {
      final r = await _dio.post('$backend/api/auth/register', data: {
        'email': email,
        'code': code,
        'password': password,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      });
      return _session(r);
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  Future<({AuthUser user, String token})> login(
    String backend, {
    required String email,
    required String password,
  }) async {
    try {
      final r = await _dio.post('$backend/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      return _session(r);
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  /// token 失效返回 null
  Future<AuthUser?> me(String backend, String token) async {
    try {
      final r = await _dio.get('$backend/api/auth/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return AuthUser.fromJson((r.data['user'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      throw _wrap(e);
    }
  }

  ({AuthUser user, String token}) _session(Response r) {
    final data = (r.data as Map).cast<String, dynamic>();
    return (
      user: AuthUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
      token: data['token'].toString(),
    );
  }
}

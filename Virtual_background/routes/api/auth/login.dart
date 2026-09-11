
import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/auth_service.dart';

/// POST /api/auth/login —— 邮箱 + 密码登录
/// body: {"email": "...", "password": "..."}
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final Object? body;
  try {
    body = await context.request.json();
  } catch (_) {
    return Response(statusCode: 400, body: 'Bad Request: expected JSON');
  }
  if (body is! Map) return Response(statusCode: 400, body: 'Bad Request');

  final email = body['email']?.toString().trim().toLowerCase() ?? '';
  final password = body['password']?.toString() ?? '';
  if (email.isEmpty || password.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': '请输入邮箱和密码'});
  }

  final user = await AuthService.instance.findUserByEmail(email);
  // 统一提示，不区分「邮箱不存在」与「密码错误」，避免邮箱枚举
  if (user == null ||
      !AuthService.verifyPassword(password, user['password_hash'].toString())) {
    return Response.json(statusCode: 401, body: {'error': '邮箱或密码错误'});
  }

  final id = user['id'].toString();
  return Response.json(body: {
    'token': AuthService.issueToken(id, email),
    'user': AuthService.publicUser(user),
  });
}

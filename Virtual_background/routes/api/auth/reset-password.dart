import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/auth_service.dart';

/// POST /api/auth/reset-password — 忘记密码重置（无需登录，走邮箱验证码）
///
/// body: {"email": "...", "code": "123456", "newPassword": "..."}
/// 验证码用 purpose='reset'（与注册码互不干扰），
/// 通过 `POST /api/auth/send-code {"email":..., "purpose":"reset"}` 获取。
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  Object? body;
  try {
    body = await context.request.json();
  } catch (_) {
    return Response(statusCode: 400, body: 'Bad Request: expected JSON');
  }
  if (body is! Map) return Response(statusCode: 400, body: 'Bad Request');

  final email = body['email']?.toString().trim().toLowerCase() ?? '';
  final code = body['code']?.toString().trim() ?? '';
  final newPassword = body['newPassword']?.toString() ?? '';

  if (!AuthService.isValidEmail(email)) {
    return Response.json(statusCode: 400, body: {'error': '邮箱格式不正确'});
  }
  if (code.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': '请输入验证码'});
  }
  if (newPassword.length < 6) {
    return Response.json(statusCode: 400, body: {'error': '新密码至少 6 位'});
  }

  final user = await AuthService.instance.findUserByEmail(email);
  if (user == null) {
    return Response.json(statusCode: 404, body: {'error': '该邮箱未注册'});
  }

  final (codeOk, codeErr) =
      await AuthService.instance.verifyCode(email, code, purpose: 'reset');
  if (!codeOk) return Response.json(statusCode: 400, body: {'error': codeErr});

  final (ok, err) =
      await AuthService.instance.resetPassword(user['id'].toString(), newPassword);
  if (!ok) return Response.json(statusCode: 400, body: {'error': err});
  return Response.json(body: {'ok': true});
}

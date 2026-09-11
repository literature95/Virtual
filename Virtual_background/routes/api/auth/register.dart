
import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/auth_service.dart';

/// POST /api/auth/register —— 邮箱 + 验证码 + 密码注册（成功即登录）
/// body: {"email": "...", "code": "123456", "password": "...", "nickname": "..."(可选)}
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
  final code = body['code']?.toString().trim() ?? '';
  final password = body['password']?.toString() ?? '';
  final nickname = body['nickname']?.toString();

  if (!AuthService.isValidEmail(email)) {
    return Response.json(statusCode: 400, body: {'error': '邮箱格式不正确'});
  }
  if (password.length < 6) {
    return Response.json(statusCode: 400, body: {'error': '密码至少 6 位'});
  }
  if (code.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': '请输入验证码'});
  }

  // 先验码（含过期/错误次数上限），再查重，最后落库
  final (codeOk, codeErr) =
      await AuthService.instance.verifyCode(email, code);
  if (!codeOk) return Response.json(statusCode: 400, body: {'error': codeErr});

  final user = await AuthService.instance.registerUser(email, password, nickname);
  if (user == null) {
    return Response.json(statusCode: 409, body: {'error': '该邮箱已注册，请直接登录'});
  }

  final id = user['id'].toString();
  return Response.json(body: {
    'token': AuthService.issueToken(id, email),
    'user': AuthService.publicUser(user),
  });
}


import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/auth_service.dart';
import 'package:virtual_background/config.dart';

/// POST /api/auth/send-code —— 发送邮箱验证码
/// body: {"email": "...", "purpose": "register"(默认)}
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
  if (!AuthService.isValidEmail(email)) {
    return Response.json(statusCode: 400, body: {'error': '邮箱格式不正确'});
  }
  final purpose = body['purpose']?.toString() ?? 'register';

  // 注册场景：邮箱已被占用就不发码（不泄露「能否注册」以外的信息）
  if (purpose == 'register') {
    if (await AuthService.instance.findUserByEmail(email) != null) {
      return Response.json(statusCode: 409, body: {'error': '该邮箱已注册，请直接登录'});
    }
  }

  final (ok, note) = await AuthService.instance.sendCode(email, purpose: purpose);
  if (!ok) return Response.json(statusCode: 429, body: {'error': note});

  // SMTP 未配置的降级模式下随响应回 devCode，本地零配置可跑通全流程
  return Response.json(body: {
    'sent': true,
    if (!AppConfig.smtpConfigured && note != null) 'devCode': note,
  });
}

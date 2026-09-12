import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/auth_service.dart';

/// POST /api/auth/change-password — 修改密码（已登录，需校验旧密码）
///
/// body: {"oldPassword": "...", "newPassword": "..."}
/// 成功后返回 {"ok": true}。新密码至少 6 位，且不能与旧密码相同。
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final userId = AuthService.userIdFromHeaders(context.request.headers);
  if (userId == null) {
    return Response.json(statusCode: 401, body: {'error': '请先登录'});
  }

  Object? body;
  try {
    body = await context.request.json();
  } catch (_) {
    return Response(statusCode: 400, body: 'Bad Request: expected JSON');
  }
  if (body is! Map) return Response(statusCode: 400, body: 'Bad Request');

  final oldPassword = body['oldPassword']?.toString() ?? '';
  final newPassword = body['newPassword']?.toString() ?? '';

  if (oldPassword.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': '请输入当前密码'});
  }
  if (newPassword.length < 6) {
    return Response.json(statusCode: 400, body: {'error': '新密码至少 6 位'});
  }
  if (newPassword == oldPassword) {
    return Response.json(statusCode: 400, body: {'error': '新密码不能与当前密码相同'});
  }

  final (ok, err) = await AuthService.instance
      .changePassword(userId, oldPassword, newPassword);
  if (!ok) return Response.json(statusCode: 400, body: {'error': err});
  return Response.json(body: {'ok': true});
}

import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/auth_service.dart';

/// GET /api/auth/me —— 持 Bearer token 拉当前用户
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final userId = AuthService.userIdFromHeaders(context.request.headers);
  if (userId == null) {
    return Response.json(statusCode: 401, body: {'error': '未登录或登录已过期'});
  }

  final user = await AuthService.instance.findUserById(userId);
  if (user == null) {
    return Response.json(statusCode: 401, body: {'error': '用户不存在'});
  }
  return Response.json(body: {'user': AuthService.publicUser(user)});
}

import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/auth_service.dart';

/// PATCH /api/users/me — 更新当前登录用户的个人资料（需登录）
///
/// body（均为可选，**只更新传入的字段**，不传 = 保持原值）：
///   {"nickname": "...", "bio": "...", "avatarUrl": "..."}
/// avatarUrl 传空串表示清空头像。
/// 返回：{"user": {...publicUser}}
Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  if (method == HttpMethod.patch || method == HttpMethod.put) {
    return _onUpdate(context);
  }
  return Response(statusCode: 405, body: 'Method Not Allowed');
}

Future<Response> _onUpdate(RequestContext context) async {
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

  // 显式 null 不覆盖既有值；只有键存在才更新该字段
  final String? nickname =
      body.containsKey('nickname') ? body['nickname']?.toString() ?? '' : null;
  final String? bio =
      body.containsKey('bio') ? body['bio']?.toString() ?? '' : null;
  final String? avatarUrl = body.containsKey('avatarUrl')
      ? body['avatarUrl']?.toString() ?? ''
      : null;

  if (nickname != null && nickname.trim().isEmpty) {
    return Response.json(statusCode: 400, body: {'error': '昵称不能为空'});
  }
  if (nickname != null && nickname.trim().length > 24) {
    return Response.json(statusCode: 400, body: {'error': '昵称不超过 24 个字'});
  }
  if (bio != null && bio.trim().length > 200) {
    return Response.json(statusCode: 400, body: {'error': '简介不超过 200 个字'});
  }

  final user = await AuthService.instance.updateProfile(
    userId,
    nickname: nickname,
    bio: bio,
    avatarUrl: avatarUrl,
  );
  if (user == null) {
    return Response.json(statusCode: 404, body: {'error': '用户不存在'});
  }
  return Response.json(body: {'user': AuthService.publicUser(user)});
}

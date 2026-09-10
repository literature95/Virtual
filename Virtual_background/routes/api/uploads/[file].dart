import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// GET /api/uploads/[file] — 用户上传的角色立绘静态文件
///
/// 文件存放于 public/uploads/（与内置种子立绘 public/avatars/ 分离，
/// uploads/ 已加入 .gitignore 不入版本库）。挂到 /api/ 下与 avatars 路由同理：
/// 继承 _middleware.dart 的全局 CORS 头，Flutter Web 端可跨域取图。
/// 仅允许常见图片扩展名，拒绝路径穿越。
Future<Response> onRequest(RequestContext context, String file) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  // 路径穿越与扩展名白名单
  if (file.contains('..') || file.contains('/') || file.contains(r'\')) {
    return Response(statusCode: 400, body: 'Bad Request');
  }
  const contentTypes = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
  };
  final dot = file.lastIndexOf('.');
  final ext = dot >= 0 ? file.substring(dot).toLowerCase() : '';
  final contentType = contentTypes[ext];
  if (contentType == null) {
    return Response(statusCode: 404, body: 'Not Found');
  }

  final f = File('public/uploads/$file');
  if (!f.existsSync()) {
    return Response(statusCode: 404, body: 'Not Found');
  }

  return Response.bytes(
    body: await f.readAsBytes(),
    headers: {
      'content-type': contentType,
      'cache-control': 'public, max-age=86400',
    },
  );
}

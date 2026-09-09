import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// GET /api/avatars/[file] — 角色立绘静态文件
///
/// 文件存放于 public/avatars/。挂到 /api/ 下是为了继承 _middleware.dart 的
/// 全局 CORS 头——Dart Frog 的 public/ 静态目录会绕过中间件，Flutter Web 端
/// 用 XHR 跨域取图字节会被浏览器拦截导致图片空白，因此不走静态目录。
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
  };
  final dot = file.lastIndexOf('.');
  final ext = dot >= 0 ? file.substring(dot).toLowerCase() : '';
  final contentType = contentTypes[ext];
  if (contentType == null) {
    return Response(statusCode: 404, body: 'Not Found');
  }

  final f = File('public/avatars/$file');
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

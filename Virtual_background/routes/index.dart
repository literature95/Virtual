import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// GET / — 返回 Flutter Web 构建的入口页 index.html
///
/// Dart Frog 的 public/ 静态目录不会把 index.html 映射到根路径 `/`，
/// 这里用根路由显式提供，使「打开 http://localhost:8080/ 即 App」成立。
/// 静态资源（main.dart.js / assets / canvaskit 等）仍由 public/ 直接服务。
Future<Response> onRequest(RequestContext context) async {
  final f = File('public/index.html');
  if (!f.existsSync()) {
    return Response(statusCode: 404, body: 'index.html not found');
  }
  return Response.bytes(
    body: await f.readAsBytes(),
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

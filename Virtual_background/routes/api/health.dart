import 'package:dart_frog/dart_frog.dart';

/// GET /api/health — 健康检查
Response onRequest(RequestContext context) {
  if (context.request.method == HttpMethod.get) {
    return Response.json(body: {'status': 'ok', 'service': 'Virtual_background'});
  }
  return Response(statusCode: 405, body: 'Method Not Allowed');
}

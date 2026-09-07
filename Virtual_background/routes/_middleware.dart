import 'package:dart_frog/dart_frog.dart';

/// 全局 CORS 中间件：允许 Web 官网（Vite 代理外直连）与 Flutter Web 版 App 跨域访问
Map<String, String> _corsHeaders(Response res) => {
      ...res.headers,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': '*',
    };

Handler middleware(Handler handler) {
  return (context) async {
    if (context.request.method == HttpMethod.options) {
      return Response(
        headers: _corsHeaders(Response()),
      );
    }
    final response = await handler(context);
    return response.copyWith(headers: _corsHeaders(response));
  };
}

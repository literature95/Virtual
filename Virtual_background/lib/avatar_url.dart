/// 角色立绘 URL 解析。
///
/// 种子数据 / DB 中存储相对路径（如 `/avatars/char-001.jpg`），
/// 响应时按请求来源（scheme + host + port）重写为绝对 URL，
/// 保证 App 与 Web 端零改动即可直连后端获取图片；
/// 已是 http(s) 外链的 URL 原样透传。
library;

String resolveAvatarUrl(String? url, Uri requestUri) {
  if (url == null || url.isEmpty) return '';
  if (!url.startsWith('/')) return url;

  // 立绘统一走 /api/ 路由：Dart Frog 的 public/ 静态目录会绕过全局
  // CORS 中间件，导致 Flutter Web 用 XHR 跨域取图字节被浏览器拦截（图空白）。
  // 改挂到 /api/ 下即可继承 _middleware.dart 的 CORS 头，原生端同样可用。
  // /avatars/ = 内置种子立绘；/uploads/ = 用户上传立绘（发布协议 §2）。
  var resolved = url;
  if (resolved.startsWith('/avatars/') || resolved.startsWith('/uploads/')) {
    resolved = '/api$resolved';
  }

  final scheme = requestUri.scheme.isEmpty ? 'http' : requestUri.scheme;
  final host = requestUri.host.isEmpty ? 'localhost' : requestUri.host;
  final port = requestUri.port;
  final isDefaultPort =
      (scheme == 'http' && (port == 80 || port == 0)) ||
      (scheme == 'https' && port == 443);
  final effectivePort = port == 0 ? 8080 : port;

  return '$scheme://$host${isDefaultPort ? '' : ':$effectivePort'}$resolved';
}

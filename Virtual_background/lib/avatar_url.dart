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

  final scheme = requestUri.scheme.isEmpty ? 'http' : requestUri.scheme;
  final host = requestUri.host.isEmpty ? 'localhost' : requestUri.host;
  final port = requestUri.port;
  final isDefaultPort =
      (scheme == 'http' && (port == 80 || port == 0)) ||
      (scheme == 'https' && port == 443);
  final effectivePort = port == 0 ? 8080 : port;

  return '$scheme://$host${isDefaultPort ? '' : ':$effectivePort'}$url';
}

import 'dart:convert';
import 'dart:io';

/// 根据文件扩展名推断图片 MIME 类型
String imageMimeOf(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    default:
      return 'image/jpeg';
  }
}

/// 读取本地图片并转为 data URL（OpenAI 兼容格式）。
/// 文件不存在或读取失败时返回 null。
String? imageDataUrlFromPath(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    return 'data:${imageMimeOf(path)};base64,${base64Encode(bytes)}';
  } catch (_) {
    return null;
  }
}

/// 解析 data URL，返回 (mime, base64Data)。
/// 非 data URL 或格式非法时返回 null。
(String, String)? parseDataUrl(String url) {
  const prefix = 'data:';
  if (!url.startsWith(prefix)) return null;
  final commaIndex = url.indexOf(',');
  if (commaIndex < 0) return null;
  final header = url.substring(prefix.length, commaIndex); // image/jpeg;base64
  final data = url.substring(commaIndex + 1);
  final mime = header.split(';').first;
  if (mime.isEmpty || data.isEmpty) return null;
  return (mime, data);
}

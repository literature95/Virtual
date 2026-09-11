import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web 端保存字节 —— 用 Blob + 隐藏 `<a download>` 触发浏览器下载
///
/// `FilePicker.platform.saveFile` 在 Web 上未实现，因此这里绕开它。
/// 浏览器没有"选择保存路径"的概念，下载目录由浏览器设置决定，
/// 因此返回值只是文件名，不代表真实落盘路径。
Future<String?> saveBytesToFile(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
  List<String>? allowedExtensions,
  String? dialogTitle,
}) async {
  final blob = web.Blob(
    <web.BlobPart>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // 不可立即 revoke：下载是异步启动的，当场释放 URL 会让部分浏览器中断下载
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return fileName;
}

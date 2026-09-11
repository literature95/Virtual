import 'dart:typed_data';

import 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart'
    as impl;

/// 把字节保存为文件 —— 跨端统一入口。
///
/// 返回落盘路径（Web 端返回触发下载的文件名）；用户取消时返回 null。
///
/// 为什么需要这一层：`FilePicker.platform.saveFile` 在 **Web 上没有实现**
/// ——`FilePickerWeb` 未覆盖该方法，调用会直接抛 `UnimplementedError`；
/// 而 `dart:io` 的 `File` 在 Web 上同样不可用。项目里既有的导出（聊天记录、
/// 备份）因此都是原生专属。角色卡是对外分发物，导出必须在浏览器里也能用，
/// 所以用条件导入分流：原生走文件选择器 + `File.writeAsBytes`，
/// Web 走 Blob 触发下载。
///
/// [allowedExtensions] 在原生端映射为文件类型过滤；Web 端浏览器下载
/// 不使用该过滤（仅影响文件名）。
Future<String?> saveBytesToFile(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
  List<String>? allowedExtensions,
  String? dialogTitle,
}) =>
    impl.saveBytesToFile(
      bytes,
      fileName: fileName,
      mimeType: mimeType,
      allowedExtensions: allowedExtensions,
      dialogTitle: dialogTitle,
    );

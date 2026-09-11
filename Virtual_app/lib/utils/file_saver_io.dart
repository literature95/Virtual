import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 原生端（Windows / macOS / Linux / Android / iOS）保存字节
///
/// 桌面端 `saveFile` 只负责挑选路径并返回，**写盘要自己做**；Android / iOS
/// 则相反 —— 必须把 `bytes` 交给平台侧，由它落盘（受 SAF / 沙盒约束）。
Future<String?> saveBytesToFile(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
  List<String>? allowedExtensions,
  String? dialogTitle,
}) async {
  final type = (allowedExtensions == null || allowedExtensions.isEmpty)
      ? FileType.any
      : FileType.custom;

  if (Platform.isAndroid || Platform.isIOS) {
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: type,
      allowedExtensions: allowedExtensions,
      bytes: bytes,
    );
  }

  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: type,
    allowedExtensions: allowedExtensions,
  );
  // 用户取消
  if (path == null) return null;

  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

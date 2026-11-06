/// 本地模型（用户自行导入的 GGUF）管理接口。
///
/// 这里只放纯 Dart 类型与路径工具，具体文件操作在
/// `local_model_service_io.dart`（VM/Android），Web 由
/// `local_model_service_stub.dart` 提供「不支持」实现。
library;

/// 模型文件状态：路径 + 是否存在 + 字节数。
class LocalModelStatus {
  final String path;
  final bool exists;
  final int bytes;

  const LocalModelStatus({
    required this.path,
    required this.exists,
    required this.bytes,
  });

  static const LocalModelStatus missing =
      LocalModelStatus(path: '', exists: false, bytes: 0);

  String get sizeLabel {
    if (!exists) return '文件不存在';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum LocalModelImportOutcome {
  /// 已复制到 App 模型目录
  imported,

  /// 同目录已有同名同大小文件，跳过（幂等）
  skipped,

  /// 用户取消
  cancelled,
}

class LocalModelImportResult {
  final LocalModelImportOutcome outcome;
  final String path;
  final int bytes;

  const LocalModelImportResult({
    required this.outcome,
    required this.path,
    required this.bytes,
  });
}

/// 导入失败的可读异常（UI 直接把 [message] 上屏）。
class LocalModelImportException implements Exception {
  final String message;
  const LocalModelImportException(this.message);

  @override
  String toString() => message;
}

/// 从选择器返回的路径里取文件名（兼容 `/` 与 `\`）。
String modelFileNameFrom(String sourcePath) {
  final normalized = sourcePath.replaceAll('\\', '/');
  final name = normalized.substring(normalized.lastIndexOf('/') + 1);
  return name.isEmpty ? 'model.gguf' : name;
}

/// 拼接模型目录与文件名（不依赖 `package:path`，避免新增依赖）。
String joinModelPath(String directory, String fileName) {
  final dir = directory.endsWith('/') || directory.endsWith('\\')
      ? directory.substring(0, directory.length - 1)
      : directory;
  final sep = dir.contains('\\') && !dir.contains('/') ? '\\' : '/';
  return '$dir$sep$fileName';
}

abstract class LocalModelService {
  /// Web 端为 false；UI 据此显示「当前平台不支持导入」。
  bool get supported;

  /// App 可访问的模型目录（Android: `getExternalFilesDir(null)/models`）。
  Future<String> modelsDirectory();

  /// 查看任意路径（App 目录内或用户手填的外部路径）。
  Future<LocalModelStatus> inspect(String path);

  /// 选择文件后调用：校验头 → 流式复制到模型目录 → 返回绝对路径。
  ///
  /// [sourceBytes] 由文件选择器提供，用于进度与幂等判断。
  /// [onProgress] 0.0–1.0；[isCancelled] 每个分块检查一次。
  Future<LocalModelImportResult> importGguf({
    required String sourcePath,
    required int sourceBytes,
    String? preferredName,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  });

  /// 仅删除 App 自己模型目录内的文件；外部路径返回 false（只提示不代删）。
  Future<bool> deleteManaged(String path);

  /// 路径是否位于 App 模型目录内。
  Future<bool> isManagedPath(String path);
}

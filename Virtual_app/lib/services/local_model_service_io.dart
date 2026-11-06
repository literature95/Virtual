import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

import 'gguf_header.dart';
import 'local_model_service_base.dart';

/// VM / Android / iOS 实现：用户选择的 GGUF 复制进 App 可访问目录。
///
/// 约定目录：`getExternalFilesDir(null)/models/`（Android），因此
/// **不需要全盘存储权限**，也不会污染用户相册/下载目录。
class LocalModelServiceIo implements LocalModelService {
  /// 单测注入模型目录，避免依赖 path_provider 插件。
  LocalModelServiceIo({String? modelsDirectoryOverride})
      : _modelsDirectoryOverride = modelsDirectoryOverride;

  final String? _modelsDirectoryOverride;

  @override
  bool get supported => true;

  @override
  Future<String> modelsDirectory() async {
    if (_modelsDirectoryOverride != null) return _modelsDirectoryOverride;
    Directory base;
    if (Platform.isAndroid) {
      // getExternalFilesDir(null)：/storage/emulated/0/Android/data/<pkg>/files
      base = await getExternalStorageDirectory() ??
          await getApplicationSupportDirectory();
    } else {
      base = await getApplicationSupportDirectory();
    }
    final dir = Directory(joinModelPath(base.path, 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<LocalModelStatus> inspect(String path) async {
    final p = path.trim();
    if (p.isEmpty) return LocalModelStatus.missing;
    final file = File(p);
    if (!await file.exists()) {
      return LocalModelStatus(path: p, exists: false, bytes: 0);
    }
    return LocalModelStatus(path: p, exists: true, bytes: await file.length());
  }

  @override
  Future<bool> isManagedPath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return false;
    final dir = _normalize(await modelsDirectory());
    return _normalize(p).startsWith('$dir/');
  }

  @override
  Future<bool> deleteManaged(String path) async {
    if (!await isManagedPath(path)) return false; // 外部路径不代删
    final file = File(path);
    if (!await file.exists()) return true;
    await file.delete();
    return true;
  }

  @override
  Future<LocalModelImportResult> importGguf({
    required String sourcePath,
    required int sourceBytes,
    String? preferredName,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const LocalModelImportException('选择的文件已失效，请重新选择');
    }

    // 1) 先校验文件头，避免把整份大文件白拷一遍
    final header = await _readHeader(source);
    if (!header.valid) {
      throw LocalModelImportException(header.error!);
    }

    final expectedBytes =
        sourceBytes > 0 ? sourceBytes : await source.length();
    // 2) 幂等：同名同大小直接跳过
    final name = preferredName ?? modelFileNameFrom(sourcePath);
    final dir = await modelsDirectory();
    final targetPath = joinModelPath(dir, name);
    final target = File(targetPath);
    if (await target.exists() && await target.length() == expectedBytes) {
      onProgress?.call(1.0);
      return LocalModelImportResult(
        outcome: LocalModelImportOutcome.skipped,
        path: targetPath,
        bytes: expectedBytes,
      );
    }

    // 3) 流式复制到 .partial，完成后 rename；任何失败/取消都清理 .partial
    final partial = File('$targetPath.partial');
    RandomAccessFile? handle;
    var written = 0;
    var lastReport = -1.0;
    try {
      final raf = await partial.open(mode: FileMode.write);
      handle = raf;
      await for (final chunk in source.openRead()) {
        if (isCancelled?.call() ?? false) {
          await raf.close();
          handle = null;
          await _deleteQuietly(partial);
          return LocalModelImportResult(
            outcome: LocalModelImportOutcome.cancelled,
            path: targetPath,
            bytes: 0,
          );
        }
        await raf.writeFrom(chunk);
        written += chunk.length;
        if (onProgress != null && expectedBytes > 0) {
          final progress = math.min(1.0, written / expectedBytes);
          if (progress - lastReport >= 0.01) {
            lastReport = progress;
            onProgress(progress);
          }
        }
      }
      await raf.flush();
      await raf.close();
      handle = null;
      if (written < 8) {
        await _deleteQuietly(partial);
        throw const LocalModelImportException('文件内容为空或已损坏，导入已取消');
      }
      if (await target.exists()) await target.delete(); // 同名不同大小：覆盖
      await partial.rename(targetPath);
      onProgress?.call(1.0);
      return LocalModelImportResult(
        outcome: LocalModelImportOutcome.imported,
        path: targetPath,
        bytes: written,
      );
    } on FileSystemException catch (e) {
      final h = handle;
      if (h != null) await h.close();
      handle = null;
      await _deleteQuietly(partial);
      throw LocalModelImportException(_writeErrorMessage(e, expectedBytes));
    } on LocalModelImportException {
      rethrow;
    } catch (e) {
      final h = handle;
      if (h != null) await h.close();
      handle = null;
      await _deleteQuietly(partial);
      throw LocalModelImportException('导入模型失败：$e');
    }
  }

  Future<GgufHeaderCheck> _readHeader(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(8);
      return checkGgufHeader(bytes);
    } finally {
      await raf?.close();
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 清理失败不掩盖原始错误
    }
  }

  String _writeErrorMessage(FileSystemException e, int expectedBytes) {
    final code = e.osError?.errorCode;
    // Android/Linux: ENOSPC=28；Windows: 磁盘空间不足=112
    if (code == 28 || code == 112) {
      final mb = (expectedBytes / (1024 * 1024)).toStringAsFixed(1);
      return '存储空间不足，无法导入模型（需要约 $mb MB），请清理空间后重试';
    }
    return '写入模型失败：${e.osError?.message ?? e.message}';
  }

  String _normalize(String path) =>
      path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
}

LocalModelService createLocalModelService() => LocalModelServiceIo();

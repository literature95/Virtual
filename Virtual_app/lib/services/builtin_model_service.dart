import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 打包进 APK 的本地模型（GGUF）描述。
///
/// 与 `android/app/src/main/assets/models/` 下的文件一一对应；
/// [sizeBytes] 用于「已就绪」判定与复制后的完整性校验，
///
/// 改动模型文件时必须同步这里的大小，否则会判为未就绪并重新复制。
class BuiltInModel {
  /// 稳定标识，写进端点配置时用于区分内置/自定义
  final String id;

  /// 展示名
  final String displayName;

  /// 一句话说明（参数量、量化档位）
  final String description;

  /// APK 内 assets 路径（相对 assets 根）
  final String assetPath;

  /// 落地到设备后的文件名
  final String fileName;

  /// 精确字节数
  final int sizeBytes;

  const BuiltInModel({
    required this.id,
    required this.displayName,
    required this.description,
    required this.assetPath,
    required this.fileName,
    required this.sizeBytes,
  });

  /// 约等于多少 MB（按 1024 进制，展示用）
  int get sizeMb => sizeBytes ~/ (1024 * 1024);

  /// 端点配置里用这个值标记「使用内置模型」
  String get marker => 'builtin:$id';
}

/// 内置模型清单。目前只有一个（arm64 单架构包）。
const List<BuiltInModel> kBuiltInModels = [
  BuiltInModel(
    id: 'qwen3.5-0.8b-q4_k_m',
    displayName: 'Qwen3.5 0.8B (Q4_K_M)',
    description: '中文对话小模型 · 约 508 MB',
    assetPath: 'models/Qwen3.5-0.8B-Q4_K_M.gguf',
    fileName: 'Qwen3.5-0.8B-Q4_K_M.gguf',
    sizeBytes: 532517120,
  ),
];

/// 按 fileName 或路径匹配内置模型（用于把旧的「手填路径」识别成内置模型）
///
/// 不用 `Platform.pathSeparator`：这里要同时兼容 Android 绝对路径与
/// Windows 反斜杠路径，且 web 端不能引入 dart:io。
BuiltInModel? builtInModelForPath(String path) {
  if (path.isEmpty) return null;
  final segments = path.split(RegExp(r'[\\/]'));
  final name = segments.isEmpty ? path : segments.last;
  for (final m in kBuiltInModels) {
    if (name == m.fileName) return m;
  }
  return null;
}

/// 按 id 找内置模型
BuiltInModel? builtInModelById(String id) {
  for (final m in kBuiltInModels) {
    if (m.id == id) return m;
  }
  return null;
}

/// 内置模型的安装（APK assets → 应用私有目录）。
///
/// 复制在原生侧做（MainActivity 的 MethodChannel），Dart 只收进度与结果，
/// 避免把 500MB+ 读进 Dart 堆。web 无此能力，统一抛 [UnsupportedError]。
class BuiltInModelService {
  static const MethodChannel _channel =
      MethodChannel('app.bitbear.virtual/model_asset');

  static bool _handlerBound = false;
  static void Function(double)? _progressListener;

  static void _bindHandler() {
    if (_handlerBound) return;
    _handlerBound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onProgress') {
        final args = call.arguments;
        if (args is num) _progressListener?.call(args.toDouble());
      }
      return null;
    });
  }

  /// 已安装且大小正确时返回设备上的绝对路径，否则 null
  static Future<String?> installedPath(BuiltInModel model) async {
    if (kIsWeb) return null;
    _bindHandler();
    try {
      return await _channel.invokeMethod<String>('getInstalledPath', {
        'targetName': model.fileName,
        'expectedBytes': model.sizeBytes,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 确保模型已落地，返回绝对路径。
  /// 首次调用会复制（[onProgress] 回调 0~1）；已就绪则立即返回。
  static Future<String> ensureInstalled(
    BuiltInModel model, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('当前平台（Web）不支持本地模型部署');
    }
    _bindHandler();
    _progressListener = onProgress;
    try {
      final path = await _channel.invokeMethod<String>('ensureInstalled', {
        'assetPath': model.assetPath,
        'targetName': model.fileName,
        'expectedBytes': model.sizeBytes,
      });
      if (path == null || path.isEmpty) {
        throw StateError('本地模型复制失败：原生侧未返回路径');
      }
      return path;
    } on PlatformException catch (e) {
      throw StateError(e.message ?? '本地模型复制失败（${e.code}）');
    } on MissingPluginException {
      throw StateError('当前安装包未包含本地模型安装模块');
    } finally {
      _progressListener = null;
    }
  }
}

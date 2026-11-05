import 'dart:collection';
import 'dart:convert' show base64Decode;
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/image_data.dart';

/// 全局图片缓存与解码尺寸策略
///
/// 角色立绘/封面/头像有三个来源，统一从这里取 [ImageProvider]：
/// - `http(s)://…`：服务器 `/api/avatars/*`、`/api/uploads/*`（后端目前只有原图，
///   无缩略图、无 ETag），走 `CachedNetworkImageProvider` + 统一磁盘缓存；
/// - `data:image/…;base64,…`：角色卡内嵌图，base64 解码结果做 LRU 复用，
///   避免每次重建卡片都重新解码；
/// - 本地文件路径：`FileImage`（Web 端不支持文件系统，调用方回退占位）。
///
/// 磁盘缓存策略（`flutter_cache_manager`）：
/// - 缓存目录由插件托管（Android `…/cache/libCachedImageData/`，iOS `Library/Caches`）；
/// - 最多 **400 张**、**30 天**未访问即过期；
/// - key 只用 URL（不带解码宽度），同一张图不同尺寸只下载一次，按需解码。
class AppImageCache {
  AppImageCache._();

  /// 缓存目录名（改动会导致老缓存失联，升级时保持一致）
  static const String cacheKeyName = 'virtual_app_image_cache';

  /// 未访问过期时间
  static const Duration stalePeriod = Duration(days: 30);

  /// 最大缓存对象数（张）
  static const int maxObjects = 400;

  /// 全局共享的磁盘缓存实例（列表 / 详情 / 背景都使用同一个）
  static final CacheManager manager = CacheManager(
    Config(
      cacheKeyName,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxObjects,
    ),
  );

  /// 由 URL 生成稳定的缓存 key（仅网络 URL 使用）
  ///
  /// 去掉首尾空白与 `#fragment`，其余原样保留；不掺入解码宽度，
  /// 保证「同一张原图只缓存一份」。
  static String keyFor(String url) {
    var normalized = url.trim();
    final hash = normalized.indexOf('#');
    if (hash >= 0) normalized = normalized.substring(0, hash);
    return normalized;
  }

  /// 按显示宽度与设备像素比计算解码宽度
  ///
  /// [displayWidth] 是卡片/头像的**逻辑像素**宽度，[devicePixelRatio] 通常取
  /// `MediaQuery.devicePixelRatio`。返回 `null` 表示不限制（详情/全屏按原图）。
  /// [max] 用于兜底，避免异常 DPR 把值撑爆。
  static int? decodeWidthFor(
    double displayWidth,
    double devicePixelRatio, {
    int max = 4096,
  }) {
    if (!displayWidth.isFinite || displayWidth <= 0) return null;
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) return null;
    final px = (displayWidth * devicePixelRatio).round();
    if (px <= 0) return null;
    return px > max ? max : px;
  }

  /// base64 解码结果 LRU（同一张内嵌卡多次重建时复用同一份字节）
  static final LinkedHashMap<String, Uint8List> _decodedDataUrls =
      LinkedHashMap<String, Uint8List>();
  static const int _maxDecodedDataUrls = 24;

  static Uint8List? _decodedBytes(String dataUrl) {
    final cached = _decodedDataUrls.remove(dataUrl);
    if (cached != null) {
      // 重新插入到尾部，维持 LRU 顺序
      _decodedDataUrls[dataUrl] = cached;
      return cached;
    }
    final parsed = parseDataUrl(dataUrl);
    if (parsed == null) return null;
    try {
      final bytes = base64Decode(parsed.$2);
      _decodedDataUrls[dataUrl] = bytes;
      if (_decodedDataUrls.length > _maxDecodedDataUrls) {
        _decodedDataUrls.remove(_decodedDataUrls.keys.first);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// 按需套上 [ResizeImage]；`decodeWidth` 为空/≤0 表示保留原图
  static ImageProvider _maybeResize(ImageProvider provider, int? decodeWidth) {
    if (decodeWidth == null || decodeWidth <= 0) return provider;
    return ResizeImage(provider, width: decodeWidth, allowUpscaling: false);
  }

  /// 根据路径形态返回解码尺寸受控的 [ImageProvider]
  ///
  /// [decodeWidth] 为解码宽度（像素）；传 `null` 表示原图。
  /// 空值 / 无法识别 / Web 端本地文件 → `null`，由调用方展示占位。
  static ImageProvider? providerFor(String? path, {int? decodeWidth}) {
    if (path == null || path.isEmpty) return null;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      final provider = CachedNetworkImageProvider(
        path,
        cacheKey: keyFor(path),
        cacheManager: manager,
      );
      return _maybeResize(provider, decodeWidth);
    }

    if (path.startsWith('data:')) {
      final bytes = _decodedBytes(path);
      if (bytes == null) return null;
      return _maybeResize(MemoryImage(bytes), decodeWidth);
    }

    if (kIsWeb) return null;
    return _maybeResize(FileImage(File(path)), decodeWidth);
  }

  /// 清空磁盘缓存（调试/「清除图片缓存」入口使用）
  static Future<void> clear() async {
    _decodedDataUrls.clear();
    await manager.emptyCache();
  }
}

/// 纯逻辑：计算「即将进入视口」的预加载下标（便于单测）
///
/// 从 [index] 往后取最多 [lookahead] 个，越界自动截断。
List<int> lookaheadIndices(int index, int length, {int lookahead = 2}) {
  if (length <= 0 || lookahead <= 0) return const [];
  final start = index + 1;
  if (start >= length) return const [];
  final end = (start + lookahead > length) ? length : start + lookahead;
  return [for (var i = start; i < end; i++) i];
}

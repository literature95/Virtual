import 'package:flutter/material.dart';

import '../../services/app_image_cache.dart';

/// 统一的网络/内嵌/本地图片组件
///
/// 与裸 `Image.network` / `NetworkImage` 的区别：
/// 1. 统一走 [AppImageCache] 的磁盘缓存（进程重启后仍命中）；
/// 2. 按**实际显示宽度 × DPR** 降采样解码，不再整张解 1368×768 原图；
/// 3. 加载中显示与卡片同风格的浅色骨架，成功后 150ms 淡入（不再「一张张蹦」）；
/// 4. 失败态显示重试图标，点击会清掉该 URL 的磁盘缓存并重新请求。
///
/// [displayWidth] 一般传 `LayoutBuilder` 的 `constraints.maxWidth`；
/// 全屏/详情页可以显式传 `decodeWidth: null` 来解原图。
class CachedAppImage extends StatefulWidget {
  final String? path;
  final BoxFit fit;
  final Alignment alignment;

  /// 显示宽度（逻辑像素）；用于计算解码宽度
  final double? displayWidth;

  /// 显式指定解码宽度（像素）；传 0 或 null 且 [displayWidth] 也为空时解原图
  final int? decodeWidth;

  /// 占位背景色；为空时用主题 `surfaceContainerHighest`
  final Color? placeholderColor;

  /// 无图/无法识别时的兜底内容（默认透明）
  final Widget? fallback;

  /// 淡入时长（≤200ms，避免慢图观感像渲染失败）
  final Duration fadeInDuration;

  const CachedAppImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.displayWidth,
    this.decodeWidth,
    this.placeholderColor,
    this.fallback,
    this.fadeInDuration = const Duration(milliseconds: 150),
  });

  @override
  State<CachedAppImage> createState() => _CachedAppImageState();
}

class _CachedAppImageState extends State<CachedAppImage> {
  int _attempt = 0;

  Future<void> _retry(ImageProvider provider) async {
    try {
      await provider.evict();
      final path = widget.path;
      if (path != null && path.startsWith('http')) {
        await AppImageCache.manager.removeFile(AppImageCache.keyFor(path));
      }
    } catch (_) {
      // 缓存里没有该文件时 removeFile 可能抛错，忽略即可
    }
    if (mounted) setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: widget.placeholderColor ??
          scheme.surfaceContainerHighest.withValues(alpha: 0.35),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final explicit = widget.decodeWidth;
        final display = widget.displayWidth ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final int? decodeWidth;
        if (explicit != null) {
          // 显式传入：>0 按指定像素解码；0/负数表示「解原图」
          decodeWidth = explicit > 0 ? explicit : null;
        } else {
          decodeWidth = display == null
              ? null
              : AppImageCache.decodeWidthFor(
                  display, MediaQuery.devicePixelRatioOf(context));
        }
        final provider =
            AppImageCache.providerFor(widget.path, decodeWidth: decodeWidth);

        if (provider == null) {
          return widget.fallback ?? const SizedBox.shrink();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            Image(
              key: ValueKey('${widget.path}#$_attempt'),
              image: provider,
              fit: widget.fit,
              alignment: widget.alignment,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: widget.fadeInDuration,
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              errorBuilder: (context, error, stack) => _ErrorRetry(
                onTap: () => _retry(provider),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onTap;

  const _ErrorRetry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Icon(
            Icons.refresh_rounded,
            size: 24,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// 列表预加载器：只对「即将进入视口」的极少量图片预取
///
/// - 全局并发上限 [maxConcurrent]（默认 2，避免一次涌上一堆请求）；
/// - 同一 URL 在队列/进行中去重；
/// - 只预取 http(s) 网络图（内嵌 base64 与本地文件本身没有网络开销）。
class AppImagePreloader {
  AppImagePreloader._();

  static const int maxConcurrent = 2;

  static int _active = 0;
  static final List<_PreloadTask> _queue = [];
  static final Set<String> _scheduled = {};

  static void preload(
    BuildContext context,
    Iterable<String?> paths, {
    int? decodeWidth,
  }) {
    for (final path in paths) {
      if (path == null || path.isEmpty) continue;
      if (!path.startsWith('http://') && !path.startsWith('https://')) continue;
      if (_scheduled.contains(path)) continue;
      _scheduled.add(path);
      _queue.add(_PreloadTask(context, path, decodeWidth));
    }
    _drain();
  }

  static void _drain() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _active++;
      task.run().whenComplete(() {
        _active--;
        _scheduled.remove(task.path);
        _drain();
      });
    }
  }
}

class _PreloadTask {
  final BuildContext context;
  final String path;
  final int? decodeWidth;

  _PreloadTask(this.context, this.path, this.decodeWidth);

  Future<void> run() async {
    if (!context.mounted) return;
    final provider = AppImageCache.providerFor(path, decodeWidth: decodeWidth);
    if (provider == null) return;
    try {
      await precacheImage(provider, context);
    } catch (_) {
      // 预加载失败不影响正式加载（正式加载有自己的占位与重试）
    }
  }
}

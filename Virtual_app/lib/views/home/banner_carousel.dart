import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/banner_item.dart';
import '../../theme/tavo_brand.dart';

/// 首页轮播图
///
/// 横版运营位：自动轮播 + 手动滑动时暂停（松手后恢复），
/// 铺满屏宽，左右不露出下一张。
/// 数据为空时整体不占空间，不会在首页留下一块空白。
class BannerCarousel extends StatefulWidget {
  final List<BannerItem> items;

  /// 点击某一张；未关联角色卡时调用方自行决定是否响应
  final void Function(BannerItem item)? onTap;

  /// 宽高比（宽 : 高）。宽度铺满父约束，高度 = 宽度 / aspectRatio。
  /// 默认 1.58（约 16:10 的横幅构图）；例：屏宽 390 → 高约 247。
  final double aspectRatio;

  const BannerCarousel({
    super.key,
    required this.items,
    this.onTap,
    this.aspectRatio = 1.58,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  static const _autoPlayInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1.0);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(_autoPlayInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      // 轮播动画每帧都在变：圈进独立重绘边界，动画期间不重绘页面其余部分
      child: RepaintBoundary(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              // 用户正在拖：先别自动跳页，否则会和手势打架
              _timer?.cancel();
            } else if (notification is ScrollEndNotification) {
              _startAutoPlay();
            }
            return false;
          },
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              PageView.builder(
                controller: _controller,
                padEnds: false,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _BannerSlide(
                  item: items[i],
                  onTap: widget.onTap == null
                      ? null
                      : () => widget.onTap!(items[i]),
                ),
              ),
              Positioned(
                bottom: 8,
                child: _PageIndicator(count: items.length, index: _index),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单张横幅：图片铺满 + 左侧压暗 + 右下文字 + 右上「进入」胶囊
class _BannerSlide extends StatelessWidget {
  final BannerItem item;
  final VoidCallback? onTap;

  const _BannerSlide({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: TavoColors.cosmosElev,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.cover,
                // 按显示宽解码（≤560 逻辑宽 × 2 dpr），不整张解 1368×768 原图
                memCacheWidth: 1120,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: TavoColors.signGradientDiagonal,
                ),
              ),

            // ── 左侧压暗（文字在左下，不像封面卡那样居中）──
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    stops: [0.0, 0.45, 0.8],
                    colors: [
                      Color(0x000E0E0E),
                      Color(0xB30E0E0E),
                      Color(0xF20E0E0E),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 16,
              right: 16,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: TavoColors.cosmosTextDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 页码指示器：当前项拉长并走签名渐变
class _PageIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _PageIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 5,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? TavoColors.signGradient : null,
            color: active ? null : Colors.white.withValues(alpha: 0.35),
          ),
        );
      }),
    );
  }
}

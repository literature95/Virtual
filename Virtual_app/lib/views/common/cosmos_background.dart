import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/tavo_brand.dart';

/// 深空宇宙背景：星点层 + 品牌三色星云光斑
/// 与 Virtual_web 端 .cosmos 视觉统一
class CosmosBackground extends StatelessWidget {
  final Widget? child;

  const CosmosBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: isDark ? TavoColors.cosmosBg : scheme.surface),
        if (isDark) ...[
          const _Nebula(),
          // 星点是纯静态图层：用 RepaintBoundary 缓存成独立层，
          // 滚动/轮播动画时不再整屏重绘（软件渲染下的主要掉帧源）
          const RepaintBoundary(
            child: CustomPaint(painter: _StarsPainter(seed: 7, density: 90)),
          ),
          const RepaintBoundary(
            child: CustomPaint(painter: _StarsPainter(seed: 23, density: 55)),
          ),
        ],
        if (child != null) child!,
      ],
    );
  }
}

/// 三色星云光斑（紫/珊瑚/橙 极淡）
class _Nebula extends StatelessWidget {
  const _Nebula();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, -0.9),
            radius: 1.4,
            colors: [
              Color(0x227E4DF1),
              Color(0x000E0E0E),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.9, 0.95),
              radius: 1.2,
              colors: [
                Color(0x14E3756E),
                Color(0x000E0E0E),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 随机星点绘制（双seed叠层，静态无动画，性能友好）
class _StarsPainter extends CustomPainter {
  final int seed;
  final int density;

  const _StarsPainter({required this.seed, required this.density});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paints = [
      Paint()..color = Colors.white.withValues(alpha: 0.85),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
      Paint()..color = const Color(0xFFC7B0FC).withValues(alpha: 0.7),
      Paint()..color = TavoColors.coral.withValues(alpha: 0.5),
    ];

    for (var i = 0; i < density; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.3 + 0.4;
      canvas.drawCircle(Offset(dx, dy), r, paints[rng.nextInt(paints.length)]);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.density != density;
}

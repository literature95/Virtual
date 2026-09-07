import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Tavo 品牌视觉体系
///
/// 官方品牌色：紫 (#7F77DD) → 橙 (#D85A30) 渐变。
/// 提供渐变、Logo、渐变按钮 / 文字 / 空状态插图等可复用组件。
class TavoColors {
  // 品牌主色统一到 design_tokens（消除多套紫色并存）
  static const Color brandPurple = AppColors.violet;
  static const Color brandOrange = Color(0xFFD85A30);
  static const Color brandPurpleLight = Color(0xFF9B94F0);
  static const Color brandOrangeLight = Color(0xFFE8854F);
  static const Color textHighlightPurple = Color(0xFFB7A6FF);
  static const Color textHighlightOrange = Color(0xFFFFB07A);

  // ── 深空对话设计 token（单一来源：design_tokens/AppColors）──
  static const Color violet = AppColors.violet;
  static const Color coral = AppColors.coral;
  static const Color amber = AppColors.amber;
  static const Color cosmosBg = Color(0xFF0E0E0E);
  static const Color cosmosElev = Color(0xFF161519);
  static const Color cosmosText = Color(0xFFE8E8E8);
  static const Color cosmosTextDim = Color(0xFFA3A3A3);
  static const Color cosmosTextFaint = Color(0xFF626262);
  static const Color cosmosLine = Color(0x14FFFFFF);
  static const Color cosmosGreen = AppColors.success;

  /// 品牌签名三色渐变（紫→珊瑚→橙）
  static const LinearGradient signGradient = AppColors.signGradient;

  /// 签名渐变（对角线，用于头像/Logo 底）
  static const LinearGradient signGradientDiagonal =
      AppColors.signGradientDiagonal;

  /// 玻璃拟态胶囊装饰
  static BoxDecoration glassCapsule({BorderRadius? borderRadius}) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF26242C).withValues(alpha: 0.72),
            const Color(0xFF18161E).withValues(alpha: 0.66),
          ],
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPurple, brandOrange],
  );

  static const LinearGradient brandGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [brandPurple, brandOrange],
  );
}

class TavoBrand {
  /// 渐变容器装饰
  static BoxDecoration gradientBox({BorderRadius? borderRadius}) =>
      BoxDecoration(
        gradient: TavoColors.brandGradient,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      );

  /// 渐变文字（通过 ShaderMask 着色）
  static Widget gradientText(
    String text, {
    TextStyle? style,
    double? fontSize,
    TextAlign? textAlign,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => TavoColors.brandGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: (style ?? const TextStyle()).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  /// 圆角 "T" Logo（品牌渐变底）
  static Widget logo({double size = 40, double radiusFactor = 0.3}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: TavoColors.brandGradient,
        borderRadius: BorderRadius.circular(size * radiusFactor),
        boxShadow: [
          BoxShadow(
            color: TavoColors.brandPurple.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }

  /// 渐变按钮（Container + Material 水波纹）
  static Widget gradientButton({
    required VoidCallback? onPressed,
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(28);
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : TavoColors.brandGradient,
        color: onPressed == null ? Colors.grey.shade400 : null,
        borderRadius: radius,
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: TavoColors.brandPurple.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// 空状态渐变插图（圆形渐变 + 白色图标）
  static Widget emptyIllustration(IconData icon, {double size = 76}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: TavoColors.brandGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: TavoColors.brandPurple.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: size * 0.46,
      ),
    );
  }

  /// 品牌色 FloatingActionButton
  static FloatingActionButton fab({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: TavoColors.brandPurple,
      foregroundColor: Colors.white,
      elevation: 4,
      child: child,
    );
  }

  static FloatingActionButton extendedFab({
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
  }) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: TavoColors.brandPurple,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: icon,
      label: label,
    );
  }
}

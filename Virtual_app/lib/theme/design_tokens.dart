import 'package:flutter/material.dart';

/// Virtual App 设计令牌（Design Tokens）
///
/// 全局唯一的设计来源，统一颜色、间距、圆角、字号。
/// 所有页面应引用此处常量，禁止硬编码 `Color(0x…)` / `Colors.xxx` / 魔法间距数字。
///
/// 品牌色取自 Tavo 官网签名渐变，与 Virtual_web 端保持一致：
/// 紫 (#7E4DF1) → 珊瑚 (#E3756E) → 橙 (#E58029)。

class AppColors {
  AppColors._();

  // ── 品牌色 ────────────────────────────────────────────
  static const Color violet = Color(0xFF7E4DF1);
  static const Color coral = Color(0xFFE3756E);
  static const Color amber = Color(0xFFE58029);

  /// 主色：浅色用较深紫保证白底对比度，深色用亮紫保证黑底可读性
  static const Color primaryLight = Color(0xFF6C4DF6);
  static const Color primaryDark = Color(0xFFA78BFA);

  /// 成功 / 正向状态色
  static const Color success = Color(0xFF34D399);

  /// 品牌签名三色渐变（紫 → 珊瑚 → 橙）
  static const LinearGradient signGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [violet, coral, amber],
  );

  static const LinearGradient signGradientDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, coral, amber],
  );
}

/// 间距（8px 网格）
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

/// 圆角（统一卡角、输入框、按钮、卡片）
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

/// 字号阶梯（与 Material TextTheme 对应标签）
class AppFontSize {
  AppFontSize._();

  static const double display = 32;
  static const double headline = 22;
  static const double title = 16;
  static const double body = 14;
  static const double label = 13;
  static const double caption = 12;
}

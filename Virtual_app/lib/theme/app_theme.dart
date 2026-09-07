import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import 'design_tokens.dart';

/// 预设主题数据
class PresetTheme {
  final String id;
  final String name;
  final Color lightSeed;
  final Color darkSeed;
  final Color previewColor;

  const PresetTheme({
    required this.id,
    required this.name,
    required this.lightSeed,
    required this.darkSeed,
    required this.previewColor,
  });
}

/// 内置预设主题列表（仅改变主色，中性色/间距/圆角全局统一）
const List<PresetTheme> kPresetThemes = [
  PresetTheme(
    id: 'default_light',
    name: '品牌紫（默认）',
    lightSeed: AppColors.primaryLight,
    darkSeed: AppColors.primaryDark,
    previewColor: AppColors.primaryLight,
  ),
  PresetTheme(
    id: 'default_dark',
    name: '品牌紫（深空）',
    lightSeed: AppColors.primaryLight,
    darkSeed: AppColors.primaryDark,
    previewColor: AppColors.primaryDark,
  ),
  PresetTheme(
    id: 'sakura',
    name: '樱花',
    lightSeed: Color(0xFFE8649A),
    darkSeed: Color(0xFFFFB1D0),
    previewColor: Color(0xFFE8649A),
  ),
  PresetTheme(
    id: 'ocean',
    name: '海洋',
    lightSeed: Color(0xFF2196F3),
    darkSeed: Color(0xFF90CAF9),
    previewColor: Color(0xFF2196F3),
  ),
  PresetTheme(
    id: 'forest',
    name: '森林',
    lightSeed: Color(0xFF4CAF50),
    darkSeed: Color(0xFFA5D6A7),
    previewColor: Color(0xFF4CAF50),
  ),
  PresetTheme(
    id: 'sunset',
    name: '日落',
    lightSeed: Color(0xFFFF9800),
    darkSeed: Color(0xFFFFCC80),
    previewColor: Color(0xFFFF9800),
  ),
  PresetTheme(
    id: 'purple_night',
    name: '紫夜',
    lightSeed: Color(0xFF9C27B0),
    darkSeed: Color(0xFFCE93D8),
    previewColor: Color(0xFF9C27B0),
  ),
  PresetTheme(
    id: 'midnight',
    name: '午夜',
    lightSeed: Color(0xFF1A237E),
    darkSeed: Color(0xFF7986CB),
    previewColor: Color(0xFF1A237E),
  ),
];

class AppTheme {
  static ThemeData light(SettingsProvider settings) {
    final seedColor = Color(settings.primaryColorLight);
    return _buildTheme(seedColor, Brightness.light);
  }

  static ThemeData dark(SettingsProvider settings) {
    final seedColor = Color(settings.primaryColorDark);
    return _buildTheme(seedColor, Brightness.dark);
  }

  static ThemeData _buildTheme(Color seedColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // 主色系列由 seed 派生（保证用户自定义主色对比度正确），
    // 中性色系列统一手写，避免 M3 默认的 tint 造成页面颜色漂移。
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final ColorScheme scheme = base.copyWith(
      // 次级色跟随主色，避免 Material 自动生成不和谐的第二色
      secondary: base.primary,
      onSecondary: base.onPrimary,
      // ── 中性色：浅色=极简灰，深色=深空 ──
      surface: isDark ? const Color(0xFF141317) : Colors.white,
      onSurface: isDark ? const Color(0xFFE8E8E8) : const Color(0xFF17171B),
      surfaceContainerLowest:
          isDark ? const Color(0xFF0A0A0A) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF141317) : const Color(0xFFF8F8FA),
      surfaceContainer: isDark ? const Color(0xFF1A181E) : const Color(0xFFF3F3F6),
      surfaceContainerHigh:
          isDark ? const Color(0xFF211E27) : const Color(0xFFECECF0),
      surfaceContainerHighest:
          isDark ? const Color(0xFF26242C) : const Color(0xFFE6E6EB),
      onSurfaceVariant:
          isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B6B73),
      outline: isDark ? const Color(0xFF2A2833) : const Color(0xFFE2E2E8),
      outlineVariant:
          isDark ? const Color(0xFF211F29) : const Color(0xFFEFEFF3),
      error: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    );

    final Color scaffoldBg =
        isDark ? const Color(0xFF0E0E0E) : const Color(0xFFF7F7F8);

    final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      visualDensity: VisualDensity.standard,

      // ── 顶部栏 ──
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      // ── 卡片 ──
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: cardShape.copyWith(
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      // ── 分割线 ──
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── 输入框 ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),

      // ── 底部导航 / 侧栏 ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),

      // ── 悬浮按钮 ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
      ),

      // ── 按钮 ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),

      // ── 标签 Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primary.withValues(alpha: 0.16),
        labelStyle: TextStyle(color: scheme.onSurface, fontSize: 13),
        secondaryLabelStyle: TextStyle(
          color: scheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),

      // ── 弹窗 / 底部面板 ──
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      // ── 列表项 ──
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        subtitleTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),

      // ── 浮动提示 ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF26242C) : const Color(0xFF26252B),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // ── 选择开关 / 滑块 ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  /// 根据预设主题ID获取对应的 light seed color
  static Color? getPresetLightSeed(String presetId) {
    try {
      return kPresetThemes.firstWhere((t) => t.id == presetId).lightSeed;
    } catch (_) {
      return null;
    }
  }

  /// 根据预设主题ID获取对应的 dark seed color
  static Color? getPresetDarkSeed(String presetId) {
    try {
      return kPresetThemes.firstWhere((t) => t.id == presetId).darkSeed;
    } catch (_) {
      return null;
    }
  }
}
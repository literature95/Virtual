import 'package:flutter/material.dart';
import '../providers/settings_provider.dart';

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

/// 内置预设主题列表
const List<PresetTheme> kPresetThemes = [
  PresetTheme(
    id: 'default_light',
    name: '默认浅色',
    lightSeed: Color(0xFF6750A4),
    darkSeed: Color(0xFFD0BCFF),
    previewColor: Color(0xFF6750A4),
  ),
  PresetTheme(
    id: 'default_dark',
    name: '默认深色',
    lightSeed: Color(0xFFD0BCFF),
    darkSeed: Color(0xFFD0BCFF),
    previewColor: Color(0xFF381E72),
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
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        thickness: 0.5,
      ),
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

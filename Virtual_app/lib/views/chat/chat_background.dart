import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/chat_theme.dart';
import '../../services/app_image_cache.dart';
import '../common/cached_app_image.dart';

/// 对话背景的**唯一渲染入口**
///
/// 聊天页与「对话背景」设置页的预览都复用它，避免两处各画一遍导致
/// 「设置里看到的效果」和「聊天里实际效果」不一致。
///
/// 背景值存在 `ChatTheme.backgroundImage` 这一个字符串字段里，用前缀区分来源：
///  - `preset:<id>`  → 内置渐变（见 [kChatBackgroundPresets]）
///  - `http(s)://…`  → 网络图片
///  - 其它           → 本地文件路径（Web 端无法渲染，自动降级为空）
///
/// 若传入可用的 [portraitPath]（角色卡 PNG 立绘：http / data URL / 本地文件），
/// 立绘优先于 [ChatTheme.backgroundImage]，并按 [ChatTheme.portraitScrimOpacity]
/// 压暗以保证气泡可读；立绘不可用时由调用方回落到原背景。
class ChatBackgroundLayer extends StatelessWidget {
  final ChatTheme theme;

  /// 角色立绘地址；null 或不可渲染时走原有背景逻辑
  final String? portraitPath;

  const ChatBackgroundLayer({
    super.key,
    required this.theme,
    this.portraitPath,
  });

  /// 内置背景预设的 id 前缀（改动会导致存量设置失联）
  static const presetPrefix = 'preset:';

  static double blurSigma(ChatBackgroundBlur blur) {
    switch (blur) {
      case ChatBackgroundBlur.none:
        return 0;
      case ChatBackgroundBlur.light:
        return 4;
      case ChatBackgroundBlur.medium:
        return 10;
      case ChatBackgroundBlur.heavy:
        return 20;
    }
  }

  static ChatBackgroundPreset? presetOf(String? value) {
    if (value == null || !value.startsWith(presetPrefix)) return null;
    final id = value.substring(presetPrefix.length);
    for (final p in kChatBackgroundPresets) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 背景来源的中文名（用于设置页回显）
  static String describeSource(String? value) {
    if (value == null || value.trim().isEmpty) return '无背景';
    final preset = presetOf(value);
    if (preset != null) return preset.label;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return '网络图片';
    }
    return '本地图片';
  }

  /// 判断立绘地址是否真的可渲染（Web 端本地路径 / 空串 → 不可用）
  ///
  /// 用于聊天页提前决定「是否按有背景处理」，避免 AppBar 透明后背景却是空的。
  static String? usablePortraitPath(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    return AppImageCache.providerFor(path) == null ? null : path;
  }

  @override
  Widget build(BuildContext context) {
    final portrait = portraitPath;
    if (portrait != null && portrait.trim().isNotEmpty) {
      final scrim = theme.portraitScrimOpacity.clamp(0.0, 0.85);
      // 立绘只解一次：CachedAppImage 内部按「显示宽 × DPR」解码，
      // 同一 provider 命中 Flutter image cache，重建不会重复解码。
      return IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedAppImage(
              path: portrait,
              fit: BoxFit.cover,
              // 人物主体通常居中偏上，避免长屏只露出下半身/背景
              alignment: const Alignment(0, -0.25),
              placeholderColor: Colors.transparent,
              fallback: const SizedBox.shrink(),
            ),
            // 可调遮罩：保证气泡与文字对比度（0 表示不压暗）
            ColoredBox(color: Colors.black.withValues(alpha: scrim)),
          ],
        ),
      );
    }

    final raw = theme.backgroundImage;
    if (raw == null || raw.trim().isEmpty) return const SizedBox.shrink();

    final preset = presetOf(raw);
    Widget layer;
    if (preset != null) {
      layer = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: preset.colors,
          ),
        ),
      );
    } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
      // 走统一磁盘缓存 + 按屏宽降采样，重进聊天不再重新拉取/解码原图
      layer = CachedAppImage(
        path: raw,
        fit: BoxFit.cover,
        fallback: const SizedBox.shrink(),
      );
    } else if (kIsWeb) {
      // Web 端拿不到本地文件字节，直接降级为空背景（不抛异常、不显示破图）
      layer = const SizedBox.shrink();
    } else {
      layer = Image.file(
        File(raw),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    layer = Opacity(
      opacity: theme.backgroundOpacity.clamp(0.0, 1.0),
      child: layer,
    );

    final sigma = blurSigma(theme.backgroundBlur);
    if (sigma > 0) {
      layer = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: layer,
      );
    }

    // 背景纯装饰，绝不能吃掉消息列表 / 输入框的手势
    return IgnorePointer(child: layer);
  }
}

/// 内置背景预设（渐变，避免依赖网络图）
class ChatBackgroundPreset {
  final String id;
  final String label;
  final List<Color> colors;

  const ChatBackgroundPreset(this.id, this.label, this.colors);
}

const kChatBackgroundPresets = <ChatBackgroundPreset>[
  ChatBackgroundPreset(
      'deep_space', '深空', [Color(0xFF1B1233), Color(0xFF0E0E0E)]),
  ChatBackgroundPreset(
      'violet_mist', '紫雾', [Color(0xFF7E4DF1), Color(0xFF2A1A4A)]),
  ChatBackgroundPreset(
      'coral_dusk', '珊瑚暮', [Color(0xFFE3756E), Color(0xFF4A1F2A)]),
  ChatBackgroundPreset(
      'amber_sun', '琥珀', [Color(0xFFE58029), Color(0xFF3A2208)]),
  ChatBackgroundPreset(
      'ocean', '深海', [Color(0xFF1B4B6B), Color(0xFF07182A)]),
  ChatBackgroundPreset(
      'forest', '松林', [Color(0xFF1E4D3B), Color(0xFF082016)]),
  ChatBackgroundPreset(
      'sakura', '樱粉', [Color(0xFFE8A0BF), Color(0xFF4A2438)]),
  ChatBackgroundPreset(
      'paper', '素纸', [Color(0xFFEFE9DF), Color(0xFFCFC5B4)]),
];

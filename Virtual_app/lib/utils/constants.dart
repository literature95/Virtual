import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Virtual';
  static const String packageName = 'app.bitbear.virtual';

  /// 高德地图 Key（与 amap_location_service 保持一致；控制台绑定本包名 + SHA1）
  static const String amapKey = '59a835b927b9bb78abb1b93a8ee3e3b1';

  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
    Locale('ja', 'JP'),
  ];

  // 支持的 AI 平台
  static const List<String> supportedPlatforms = [
    'openai',
    'anthropic',
    'gemini',
    'deepseek',
    'grok',
    'novelai',
    'openrouter',
    'mantleai',
    'poprouter',
    'tinyrouter',
    'volink',
    'claude',
  ];

  // 模型能力标签
  static const List<String> modelCapabilities = [
    'text',
    'image',
    'code',
    'function',
    'reasoning',
    'tts',
    'asr',
    'cache',
    'structure',
  ];
}

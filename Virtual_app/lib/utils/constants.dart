import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Virtual';
  static const String packageName = 'app.bitbear.tav';

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

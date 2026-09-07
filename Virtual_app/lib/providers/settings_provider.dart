import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/asr_service.dart';
import '../services/tts_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  SettingsProvider(this._prefs) {
    _load();
  }

  // 主题
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  int _primaryColorLight = 0xFF6C4DF6;
  int get primaryColorLight => _primaryColorLight;

  int _primaryColorDark = 0xFFA78BFA;
  int get primaryColorDark => _primaryColorDark;

  // 语言
  Locale? _locale;
  Locale? get locale => _locale;

  // 聊天设置
  String _bubbleStyle = 'bubble'; // bubble, flat
  String get bubbleStyle => _bubbleStyle;

  String _listMode = 'message'; // message, visual
  String get listMode => _listMode;

  bool _showReasoning = true;
  bool get showReasoning => _showReasoning;

  bool _autoPlayTts = false;
  bool get autoPlayTts => _autoPlayTts;

  // ASR 设置
  ASRPlatform _asrPlatform = ASRPlatform.system;
  ASRPlatform get asrPlatform => _asrPlatform;
  String? _asrApiKey;
  String? get asrApiKey => _asrApiKey;
  String? _asrBaseUrl;
  String? get asrBaseUrl => _asrBaseUrl;
  String _asrLanguage = 'zh';
  String get asrLanguage => _asrLanguage;

  // TTS 设置
  TTSPlatform _ttsPlatform = TTSPlatform.flutterTts;
  TTSPlatform get ttsPlatform => _ttsPlatform;
  String? _ttsApiKey;
  String? get ttsApiKey => _ttsApiKey;
  String? _ttsBaseUrl;
  String? get ttsBaseUrl => _ttsBaseUrl;
  String? _ttsVoiceId;
  String? get ttsVoiceId => _ttsVoiceId;
  double _ttsSpeed = 1.0;
  double get ttsSpeed => _ttsSpeed;
  double _ttsPitch = 1.0;
  double get ttsPitch => _ttsPitch;

  // 引导 / 隐私 / 版本
  bool _onboardingCompleted = false;
  bool get onboardingCompleted => _onboardingCompleted;

  bool _privacyAccepted = false;
  bool get privacyAccepted => _privacyAccepted;

  String? _lastSeenVersion;
  String? get lastSeenVersion => _lastSeenVersion;

  // 后端地址（默认本地 Virtual_background）
  String _backendBaseUrl = 'http://localhost:8080';
  String get backendBaseUrl => _backendBaseUrl;

  // 备份
  String? _backupPassword;
  String? get backupPassword => _backupPassword;

  void _load() {
    // 主题
    final themeIndex = _prefs.getInt('theme_mode');
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    final primaryLight = _prefs.getInt('primary_color_light');
    if (primaryLight != null) _primaryColorLight = primaryLight;

    final primaryDark = _prefs.getInt('primary_color_dark');
    if (primaryDark != null) _primaryColorDark = primaryDark;

    // 语言
    final langCode = _prefs.getString('locale');
    if (langCode != null) {
      if (langCode == 'zh_CN') {
        _locale = const Locale('zh', 'CN');
      } else if (langCode == 'en_US') {
        _locale = const Locale('en', 'US');
      } else if (langCode == 'ja_JP') {
        _locale = const Locale('ja', 'JP');
      }
    }

    // 聊天
    _bubbleStyle = _prefs.getString('bubble_style') ?? 'bubble';
    _listMode = _prefs.getString('list_mode') ?? 'message';
    _showReasoning = _prefs.getBool('show_reasoning') ?? true;
    _autoPlayTts = _prefs.getBool('auto_play_tts') ?? false;

    // ASR
    final asrPlatformName = _prefs.getString('asr_platform');
    _asrPlatform = _parseAsrPlatform(asrPlatformName) ?? ASRPlatform.system;
    _asrApiKey = _prefs.getString('asr_api_key');
    _asrBaseUrl = _prefs.getString('asr_base_url');
    _asrLanguage = _prefs.getString('asr_language') ?? 'zh';

    // TTS
    final ttsPlatformName = _prefs.getString('tts_platform');
    _ttsPlatform = _parseTtsPlatform(ttsPlatformName) ?? TTSPlatform.flutterTts;
    _ttsApiKey = _prefs.getString('tts_api_key');
    _ttsBaseUrl = _prefs.getString('tts_base_url');
    _ttsVoiceId = _prefs.getString('tts_voice_id');
    _ttsSpeed = _prefs.getDouble('tts_speed') ?? 1.0;
    _ttsPitch = _prefs.getDouble('tts_pitch') ?? 1.0;

    // 引导 / 隐私 / 版本
    _onboardingCompleted = _prefs.getBool('onboarding_completed') ?? false;
    _privacyAccepted = _prefs.getBool('privacy_accepted') ?? false;
    _lastSeenVersion = _prefs.getString('last_seen_version');

    // 后端地址
    _backendBaseUrl =
        _prefs.getString('backend_base_url') ?? 'http://localhost:8080';
  }

  ASRPlatform? _parseAsrPlatform(String? value) {
    if (value == null) return null;
    for (final platform in ASRPlatform.values) {
      if (platform.name == value) return platform;
    }
    return null;
  }

  TTSPlatform? _parseTtsPlatform(String? value) {
    if (value == null) return null;
    for (final platform in TTSPlatform.values) {
      if (platform.name == value) return platform;
    }
    return null;
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  void setPrimaryColor(Color light, Color dark) {
    _primaryColorLight = light.toARGB32();
    _primaryColorDark = dark.toARGB32();
    _prefs.setInt('primary_color_light', light.toARGB32());
    _prefs.setInt('primary_color_dark', dark.toARGB32());
    notifyListeners();
  }

  void setLocale(Locale? locale) {
    _locale = locale;
    if (locale != null) {
      _prefs.setString(
          'locale', '${locale.languageCode}_${locale.countryCode}');
    } else {
      _prefs.remove('locale');
    }
    notifyListeners();
  }

  void setBubbleStyle(String style) {
    _bubbleStyle = style;
    _prefs.setString('bubble_style', style);
    notifyListeners();
  }

  void setListMode(String mode) {
    _listMode = mode;
    _prefs.setString('list_mode', mode);
    notifyListeners();
  }

  void setShowReasoning(bool value) {
    _showReasoning = value;
    _prefs.setBool('show_reasoning', value);
    notifyListeners();
  }

  void setAutoPlayTts(bool value) {
    _autoPlayTts = value;
    _prefs.setBool('auto_play_tts', value);
    notifyListeners();
  }

  void setAsrConfig({
    required ASRPlatform platform,
    String? apiKey,
    String? baseUrl,
    String? language,
  }) {
    _asrPlatform = platform;
    _asrApiKey = apiKey;
    _asrBaseUrl = baseUrl;
    _asrLanguage = language ?? 'zh';

    _prefs.setString('asr_platform', platform.name);
    if (apiKey == null || apiKey.isEmpty) {
      _prefs.remove('asr_api_key');
    } else {
      _prefs.setString('asr_api_key', apiKey);
    }
    if (baseUrl == null || baseUrl.isEmpty) {
      _prefs.remove('asr_base_url');
    } else {
      _prefs.setString('asr_base_url', baseUrl);
    }
    _prefs.setString('asr_language', _asrLanguage);
    notifyListeners();
  }

  void setTtsConfig({
    required TTSPlatform platform,
    String? apiKey,
    String? baseUrl,
    String? voiceId,
    double? speed,
    double? pitch,
  }) {
    _ttsPlatform = platform;
    _ttsApiKey = apiKey;
    _ttsBaseUrl = baseUrl;
    _ttsVoiceId = voiceId;
    _ttsSpeed = speed ?? _ttsSpeed;
    _ttsPitch = pitch ?? _ttsPitch;

    _prefs.setString('tts_platform', platform.name);
    if (apiKey == null || apiKey.isEmpty) {
      _prefs.remove('tts_api_key');
    } else {
      _prefs.setString('tts_api_key', apiKey);
    }
    if (baseUrl == null || baseUrl.isEmpty) {
      _prefs.remove('tts_base_url');
    } else {
      _prefs.setString('tts_base_url', baseUrl);
    }
    if (voiceId == null || voiceId.isEmpty) {
      _prefs.remove('tts_voice_id');
    } else {
      _prefs.setString('tts_voice_id', voiceId);
    }
    _prefs.setDouble('tts_speed', _ttsSpeed);
    _prefs.setDouble('tts_pitch', _ttsPitch);
    notifyListeners();
  }

  void setOnboardingCompleted(bool value) {
    _onboardingCompleted = value;
    _prefs.setBool('onboarding_completed', value);
    if (value) {
      _privacyAccepted = true;
      _prefs.setBool('privacy_accepted', true);
    }
    notifyListeners();
  }

  void setPrivacyAccepted(bool value) {
    _privacyAccepted = value;
    _prefs.setBool('privacy_accepted', value);
    notifyListeners();
  }

  void setLastSeenVersion(String version) {
    _lastSeenVersion = version;
    _prefs.setString('last_seen_version', version);
    notifyListeners();
  }

  void setBackendBaseUrl(String url) {
    final trimmed = url.trim().isEmpty ? 'http://localhost:8080' : url.trim();
    _backendBaseUrl = trimmed;
    _prefs.setString('backend_base_url', trimmed);
    notifyListeners();
  }
}

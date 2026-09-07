import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_metadata.dart';
import 'backend_config.dart';

/// 应用元数据服务
///
/// 默认从本地后端 `http://localhost:8080/api/metadata` 拉取，
/// 失败时回退到内置 `assets/metadata_default.json`。
/// 构造时接受 [SharedPreferences] 以读取用户配置的后端地址。
class MetadataService {
  static const String _assetPath = 'assets/metadata_default.json';
  static const String _prefsKey = 'backend_base_url';
  static const String _defaultBaseUrl = 'http://localhost:8080';

  final Dio _dio;
  final String baseUrl;

  AppMetadata? _metadata;

  MetadataService({
    Dio? dio,
    SharedPreferences? prefs,
    String? baseUrl,
  }) : baseUrl = baseUrl ??
            (prefs?.getString(_prefsKey) ?? _defaultBaseUrl),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: BackendConfig.metadataTimeout,
              receiveTimeout: BackendConfig.metadataTimeout,
              headers: {'Accept': 'application/json'},
            ));

  AppMetadata? get metadata => _metadata;

  /// 加载元数据：先远程，失败后回退内置资源。
  Future<AppMetadata> load({bool forceRemote = false}) async {
    if (_metadata != null && !forceRemote) return _metadata!;

    try {
      final remote = await _fetchRemote();
      _metadata = remote;
      return _metadata!;
    } catch (e) {
      // 网络不可达或服务端异常时回退内置元数据
      debugPrint('MetadataService remote fetch failed: $e');
      return loadFromAsset();
    }
  }

  /// 仅从内置资源加载（离线兜底）
  Future<AppMetadata> loadFromAsset() async {
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as List<dynamic>;
    _metadata = AppMetadata.fromJsonList(json);
    return _metadata!;
  }

  /// 远程拉取元数据。
  ///
  /// 请求参数（证据：pp+0x1d5f0~0x1d618）：
  /// `ch`(渠道)、`lc`(语言)、`pf`(平台)、`version_code`、`referrer`、
  /// `is_first_launch`。
  Future<AppMetadata> _fetchRemote() async {
    final response = await _dio.get<dynamic>(
      '$baseUrl${BackendConfig.metadataPath}',
      queryParameters: {
        'ch': BackendConfig.channel,
        'lc': _locale(),
        'pf': BackendConfig.platform,
        'version_code': _versionCode(),
        'is_first_launch': _isFirstLaunch(),
      },
    );

    final data = response.data;
    if (data is List) {
      return AppMetadata.fromJsonList(data);
    }
    if (data is Map && data.containsKey('data') && data.containsKey('key')) {
      // 服务端返回加密信封时（与原资产同格式），本还原工程不做在线解密，
      // 直接回退内置明文，避免引入 RSA/AES 运行时依赖。
      throw FormatException('encrypted envelope not handled at runtime');
    }
    throw FormatException('unexpected metadata response: $data');
  }

  String _locale() {
    // 设备语言，非本地化场景默认英文
    return 'en';
  }

  int _versionCode() {
    // 与 pubspec version 一致（1.0.0+1）
    return 1;
  }

  bool _isFirstLaunch() {
    // 首启标记由调用方（设置迁移）维护；此处无本地存储时按非首启处理
    return false;
  }
}

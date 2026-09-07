import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// WukTrace 用量追踪服务
///
/// 证据（Blutter pp.txt，reverse_analysis/blutter_out/pp.txt）：
/// - 初始化：`initWukTrace: api-secret missing or invalid, tracking disabled`
///   （pp+0x20ea8）→ 由 metadata `api-secret` 门控
/// - 上报端点：`https://t.tavo.cc/`（pp+0x20fe8）+ `api/v2/counters|metrics|
///   snapshots|events`（pp+0x20f00 / pp+0x20fb8 / pp+0x20fe0 等）
/// - 本地缓存键：`wuk_trace.counters.cache`（pp+0x8cc0）、
///   `wuk_trace.metrics.cache`（pp+0x20ec0）、`wuk_trace.snapshots.cache`
///   （pp+0x20fa0）、`wuk_trace.events.cache`（pp+0x20fc0）
/// - `WukTrace.disabled: all tracking calls will be no-ops`（pp+0x21010）
class WukTrace {
  WukTrace._();

  static final WukTrace instance = WukTrace._();

  static const String _trackingBase = 'https://t.tavo.cc/';
  static const String _eventsCacheKey = 'wuk_trace.events.cache';
  static const int _maxCachedEvents = 200;

  SharedPreferences? _prefs;
  String? _apiSecret;
  Dio? _dio;
  bool _initialized = false;

  bool get enabled => _initialized && _apiSecret != null && _apiSecret!.isNotEmpty;

  /// 初始化追踪。metadata 就绪后调用一次；api-secret 缺失时追踪禁用。
  void init({
    required SharedPreferences prefs,
    required String? apiSecret,
  }) {
    if (_initialized) return;
    _initialized = true;
    _prefs = prefs;
    _apiSecret = apiSecret;
    if (!enabled) {
      // ignore: avoid_print
      print('WukTrace.disabled: all tracking calls will be no-ops');
    }
  }

  /// 记录一次事件（本地缓存，随后由 [flushEvents] 批量上报）。
  Future<void> trackEvent(String name, [Map<String, dynamic>? props]) async {
    if (!enabled) return;
    final prefs = _prefs;
    if (prefs == null) return;

    final event = <String, dynamic>{
      'event_name': name,
      'ts': DateTime.now().toUtc().toIso8601String(),
      if (props != null && props.isNotEmpty) ...props,
    };

    final cached = prefs.getStringList(_eventsCacheKey) ?? [];
    cached.add(jsonEncode(event));
    // 限制缓存长度，避免无限增长
    if (cached.length > _maxCachedEvents) {
      cached.removeRange(0, cached.length - _maxCachedEvents);
    }
    await prefs.setStringList(_eventsCacheKey, cached);
  }

  /// 批量上报事件到 `api/v2/events`，成功后清空缓存。
  Future<int> flushEvents() async {
    if (!enabled) return 0;
    final prefs = _prefs;
    if (prefs == null) return 0;

    final cached = prefs.getStringList(_eventsCacheKey) ?? [];
    if (cached.isEmpty) return 0;

    final events = cached.map((s) => jsonDecode(s)).toList();
    try {
      final dio = _dio ??= Dio(BaseOptions(
            baseUrl: _trackingBase,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'X-Api-Secret': _apiSecret},
          ));
      final response = await dio.post<dynamic>(
        'api/v2/events',
        data: jsonEncode({'events': events}),
      );
      if (response.statusCode == 200 || response.statusCode == 202) {
        await prefs.setStringList(_eventsCacheKey, const []);
        return events.length;
      }
    } catch (e) {
      // 上报失败保留缓存，下次重试
      debugPrint('WukTrace flush failed: $e');
    }
    return 0;
  }

  /// 清空本地事件缓存（调试用）
  Future<void> clearEvents() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setStringList(_eventsCacheKey, const []);
  }
}
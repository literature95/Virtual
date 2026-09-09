import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/banner_item.dart';

/// 首页轮播位服务
///
/// 轮播是锦上添花的内容位：拿不到数据时返回空列表让首页不渲染这一块，
/// **绝不抛错**——后端没起 / 还没加这个端点都不该拖垮角色列表。
class BannerService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// 拉取轮播列表；后端不可用或返回非法结构时返回空列表
  Future<List<BannerItem>> fetchBanners(String backendBaseUrl) async {
    final base = _normalizeBase(backendBaseUrl);
    if (base.isEmpty) return const [];

    try {
      final res = await _dio.get<List<dynamic>>(
        '$base/api/banners',
        options: Options(responseType: ResponseType.json),
      );
      final data = res.data ?? const [];
      return data.map((e) {
        final map = e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(jsonDecode(jsonEncode(e)));
        return BannerItem.fromJson(map);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  String _normalizeBase(String backendBaseUrl) {
    final base = backendBaseUrl.trim();
    if (base.isEmpty) return '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }
}

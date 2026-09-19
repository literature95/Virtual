import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 高德定位 + 逆地理编码（发动态时显示位置）。
///
/// ## 两个 Key 不要混用
/// - [amapAndroidKey]：**Android 平台** Key，绑定包名 + SHA1，给 SDK/原生定位鉴权用。
/// - [amapWebKey]：**Web服务** Key，专供 REST（如 `restapi.amap.com` 逆地理）。
///
/// 🔴 实测：把 Android Key 拿去调 `regeo` 会返回
/// `USERKEY_PLAT_NOMATCH`（infocode 10009）—— Key 本身有效，但**平台类型不对**。
/// 不是网络/权限问题，也不是包名写错。
///
/// 控制台：https://console.amap.com/ → 应用管理 → 我的应用 →
/// 「添加」→ 服务平台选 **Web服务**（不需要填包名/SHA1）→ 把新 Key 填进 [amapWebKey]。
///
/// 若 [amapWebKey] 为空：仍会 GPS 定位成功，地址退化为经纬度短标（不阻塞发动态）。
///
/// 隐私合规：首次定位前必须用户同意（AMap 要求），同意状态存 SharedPreferences。
class AmapLocationService {
  /// Android 平台 Key（包名 app.bitbear.virtual + 发布 SHA1）
  /// 仅供原生/SDK 场景；**不能**调 restapi 逆地理。
  static const String amapAndroidKey =
      '59a835b927b9bb78abb1b93a8ee3e3b1';

  /// Web服务 Key（逆地理 REST）——2026-09-19 控制台新建
  static const String amapWebKey = '05c6d2fd7304e5253554d3149c565211';

  /// 兼容旧引用：默认等于 Android Key
  static const String amapKey = amapAndroidKey;

  static const String _privacyKey = 'amap_privacy_ok_v1';

  static Future<bool> isPrivacyAccepted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_privacyKey) ?? false;
  }

  static Future<void> acceptPrivacy() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_privacyKey, true);
  }

  /// 定位结果：坐标 + 高德格式化地址（无 Web服务 Key 时地址为坐标短标）
  static Future<AmapPlace?> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('系统定位服务未开启，请在系统设置中打开定位');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('未授予定位权限');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    String address;
    String label;
    if (amapWebKey.trim().isEmpty) {
      // 未配置 Web服务 Key：GPS 仍可用，先落坐标，避免整条发动态被逆地理卡死
      address =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      label = '已定位 · $address';
    } else {
      try {
        address = await regeo(pos.latitude, pos.longitude);
        label = _shortLabel(address);
      } catch (_) {
        // 逆地理失败不阻塞发动态：仍返回坐标
        address =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        label = '已定位 · $address';
      }
    }

    return AmapPlace(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
      label: label,
    );
  }

  /// 高德逆地理编码 REST（需 [amapWebKey]）
  /// https://restapi.amap.com/v3/geocode/regeo?location=lng,lat&key=KEY
  static Future<String> regeo(double lat, double lng) async {
    final key = amapWebKey.trim();
    if (key.isEmpty) {
      throw Exception(
        '未配置高德「Web服务」Key。请到高德控制台新建 Web服务 类型 Key，'
        '填入 AmapLocationService.amapWebKey',
      );
    }
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    final r = await dio.get(
      'https://restapi.amap.com/v3/geocode/regeo',
      queryParameters: {
        // 高德 location 顺序是 经度,纬度
        'location': '${lng.toStringAsFixed(6)},${lat.toStringAsFixed(6)}',
        'key': key,
        'extensions': 'base',
        'output': 'json',
      },
    );
    final data = r.data;
    if (data is! Map) throw Exception('高德逆地理返回异常');
    final status = data['status']?.toString();
    if (status != '1') {
      final info = data['info'] ?? data['infocode'] ?? '未知错误';
      final code = data['infocode']?.toString() ?? '';
      if (code == '10009' || '$info'.contains('USERKEY_PLAT_NOMATCH')) {
        throw Exception(
          'USERKEY_PLAT_NOMATCH：当前 Key 是 Android 类型，不能调 Web 服务接口。'
          '请到高德控制台另建「Web服务」Key 并填入 amapWebKey',
        );
      }
      throw Exception('高德定位失败：$info');
    }
    final regeoMap = data['regeocode'];
    final addr = (regeoMap is Map)
        ? (regeoMap['formatted_address']?.toString() ?? '')
        : '';
    return addr;
  }

  static String _shortLabel(String address) {
    if (address.isEmpty) return '未知位置';
    // 取前两段行政区划附近文本，避免整段长地址
    final parts = address
        .split(RegExp(r'[省市区县]'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return address.length > 16 ? address.substring(0, 16) : address;
    final buf = StringBuffer();
    for (var i = 0; i < parts.length && i < 3; i++) {
      if (i > 0) buf.write(i == 1 ? '·' : '');
      buf.write(parts[i].trim());
    }
    final s = buf.toString();
    return s.length > 20 ? '${s.substring(0, 20)}…' : s;
  }
}

class AmapPlace {
  final double latitude;
  final double longitude;
  final String address;
  final String label;

  const AmapPlace({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.label,
  });

  /// 是否仅有坐标、尚未解析出真实地址
  bool get isCoordsOnly => label.startsWith('已定位');

  Map<String, dynamic> toJson() => {
        'name': label,
        'address': address,
        'lat': latitude,
        'lng': longitude,
      };
}

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 高德定位 + 逆地理编码（发动态时显示位置）。
///
/// 控制台登记：
/// - Key：Android 平台（包名 app.bitbear.virtual + 发布版 SHA1）
/// - 逆地理 REST 建议再建一个「Web服务」类型 Key（同一控制台）；两者可相同试用，
///   以控制台返回 status=1 为准。
/// - 隐私合规：首次定位前必须用户同意（AMap 要求），同意状态存 SharedPreferences。
class AmapLocationService {
  /// 高德 Key（Android / Web服务 逆地理）
  static const String amapKey = '59a835b927b9bb78abb1b93a8ee3e3b1';

  static const String _privacyKey = 'amap_privacy_ok_v1';

  static Future<bool> isPrivacyAccepted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_privacyKey) ?? false;
  }

  static Future<void> acceptPrivacy() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_privacyKey, true);
  }

  /// 定位结果：坐标 + 高德格式化地址
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
    final address = await regeo(pos.latitude, pos.longitude);
    return AmapPlace(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
      label: _shortLabel(address),
    );
  }

  /// 高德逆地理编码 REST
  /// https://restapi.amap.com/v3/geocode/regeo?location=lng,lat&key=KEY
  static Future<String> regeo(double lat, double lng) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    final r = await dio.get(
      'https://restapi.amap.com/v3/geocode/regeo',
      queryParameters: {
        // 高德 location 顺序是 经度,纬度
        'location': '${lng.toStringAsFixed(6)},${lat.toStringAsFixed(6)}',
        'key': amapKey,
        'extensions': 'base',
        'output': 'json',
      },
    );
    final data = r.data;
    if (data is! Map) throw Exception('高德逆地理返回异常');
    final status = data['status']?.toString();
    if (status != '1') {
      final info = data['info'] ?? data['infocode'] ?? '未知错误';
      throw Exception('高德定位失败：$info（请确认 Key 类型含 Web服务 / 已开通逆地理）');
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

  Map<String, dynamic> toJson() => {
        'name': label,
        'address': address,
        'lat': latitude,
        'lng': longitude,
      };
}

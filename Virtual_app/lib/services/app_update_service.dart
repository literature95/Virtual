import 'package:dio/dio.dart';

/// 远端版本信息（用于启动时「是否有新包」判断）
class RemoteAppInfo {
  final String version;
  final String? downloadUrl;
  final List<String> changes;
  final String? notes;

  const RemoteAppInfo({
    required this.version,
    this.downloadUrl,
    this.changes = const [],
    this.notes,
  });
}

/// 启动时探测最新版本。
///
/// 优先级：
/// 1. `{backend}/version.json`（nginx 静态，最快，发版只需改文件）
/// 2. `{backend}/api/app-info`（后端 PG/seed）
///
/// 默认下载地址指向官网 APK，避免 seed 里过期的虚拟域名。
class AppUpdateService {
  AppUpdateService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ));

  final Dio _dio;

  static const String fallbackDownloadUrl =
      'https://virtual.literature95.com/app-release.apk';

  Future<RemoteAppInfo?> fetchLatest(String backendBase) async {
    final base = backendBase.trim();
    if (base.isEmpty) return null;
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;

    final fromJson = await _tryVersionJson(normalized);
    if (fromJson != null) return fromJson;
    return _tryAppInfo(normalized);
  }

  Future<RemoteAppInfo?> _tryVersionJson(String base) async {
    try {
      final r = await _dio.get('$base/version.json');
      final data = r.data;
      if (data is! Map) return null;
      final version = data['version']?.toString().trim() ?? '';
      if (version.isEmpty) return null;
      return RemoteAppInfo(
        version: version,
        downloadUrl:
            data['downloadUrl']?.toString().trim().isNotEmpty == true
                ? data['downloadUrl'].toString().trim()
                : fallbackDownloadUrl,
        changes: _asStringList(data['changes'] ?? data['notes']),
        notes: data['notes']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<RemoteAppInfo?> _tryAppInfo(String base) async {
    try {
      final r = await _dio.get('$base/api/app-info');
      final data = r.data;
      if (data is! Map) return null;
      final version = data['version']?.toString().trim() ?? '';
      if (version.isEmpty) return null;
      final dl = data['downloadUrl']?.toString().trim() ?? '';
      return RemoteAppInfo(
        version: version,
        downloadUrl: dl.isNotEmpty ? dl : fallbackDownloadUrl,
        changes: _asStringList(data['changes']),
        notes: data['description']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'[\n\r]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// 语义化版本比较：`1.0.8+9` > `1.0.7+8`；主版本相同再比 build。
  static bool isNewerVersion(String remote, String local) {
    int core(String v) {
      final main = v.split('+').first.trim();
      final parts =
          main.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (parts.length < 3) {
        parts.add(0);
      }
      return parts[0] * 1000000 + parts[1] * 1000 + parts[2];
    }

    int build(String v) {
      final seg = v.split('+');
      return seg.length > 1 ? (int.tryParse(seg[1]) ?? 0) : 0;
    }

    final rm = core(remote);
    final lm = core(local);
    if (rm != lm) return rm > lm;
    return build(remote) > build(local);
  }
}

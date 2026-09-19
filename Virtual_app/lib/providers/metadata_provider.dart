import 'package:flutter/foundation.dart';

import '../models/app_metadata.dart';
import '../services/metadata_service.dart';

/// Virtual 品牌网络资源（设置「关于」等用户可见文案以此为准）
class VirtualBrand {
  VirtualBrand._();
  static const String appName = 'Virtual';
  static const String homepage = 'https://virtual.literature95.com';
  static const String privacyPolicy = 'https://virtual.literature95.com/#privacy';
  static const String termsOfService = 'https://virtual.literature95.com/#terms';
  static const String help = 'https://virtual.literature95.com/';
  static const String downloadApk = 'https://virtual.literature95.com/app-release.apk';
  static const String email = 'virtual_service@outlook.com';
}

bool _looksLikeLegacyTavo(String url) {
  final u = url.toLowerCase();
  return u.contains('tavo') || u.contains('volink') || u.contains('echomoon');
}

/// 若下发/缓存元数据仍是旧 Tavo 链接，则整体替换为 Virtual 品牌链接
AppUris sanitizeUris(AppUris? raw) {
  final home = raw?.homepage ?? '';
  final needReplace = home.isEmpty || _looksLikeLegacyTavo(home);
  if (!needReplace && raw != null) {
    // 个别字段残留 tavo 时逐字段清洗
    return AppUris(
      customerServiceEmail: _looksLikeLegacyTavo(raw.customerServiceEmail)
          ? VirtualBrand.email
          : (raw.customerServiceEmail.isEmpty
              ? VirtualBrand.email
              : raw.customerServiceEmail),
      discord: _looksLikeLegacyTavo(raw.discord) ? '' : raw.discord,
      help:
          _looksLikeLegacyTavo(raw.help) ? VirtualBrand.help : (raw.help.isEmpty ? VirtualBrand.help : raw.help),
      homepage: VirtualBrand.homepage,
      models: _looksLikeLegacyTavo(raw.models) ? '' : raw.models,
      partnerBanners:
          _looksLikeLegacyTavo(raw.partnerBanners) ? '' : raw.partnerBanners,
      partnerDiscord:
          _looksLikeLegacyTavo(raw.partnerDiscord) ? '' : raw.partnerDiscord,
      privacyPolicy: _looksLikeLegacyTavo(raw.privacyPolicy) ||
              raw.privacyPolicy.isEmpty
          ? VirtualBrand.privacyPolicy
          : raw.privacyPolicy,
      reddit: _looksLikeLegacyTavo(raw.reddit) ? '' : raw.reddit,
      termsOfService: _looksLikeLegacyTavo(raw.termsOfService) ||
              raw.termsOfService.isEmpty
          ? VirtualBrand.termsOfService
          : raw.termsOfService,
      volinkAuth: '',
      volinkEmail: '',
      volinkHome: '',
      volinkPricing: '',
    );
  }
  return const AppUris(
    customerServiceEmail: VirtualBrand.email,
    discord: '',
    help: VirtualBrand.help,
    homepage: VirtualBrand.homepage,
    models: '',
    partnerBanners: '',
    partnerDiscord: '',
    privacyPolicy: VirtualBrand.privacyPolicy,
    reddit: '',
    termsOfService: VirtualBrand.termsOfService,
    volinkAuth: '',
    volinkEmail: '',
    volinkHome: '',
    volinkPricing: '',
  );
}

/// 应用元数据 Provider
///
/// 启动时加载 metadata_default.json / 后端 /api/metadata；
/// **用户可见链接经 [sanitizeUris] 强制 Virtual 品牌**，避免旧 Tavo 配置残留。
class MetadataProvider extends ChangeNotifier {
  final MetadataService _service;

  AppMetadata? _metadata;
  bool _loaded = false;
  String? _error;

  MetadataProvider(this._service);

  AppMetadata? get metadata => _metadata;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _metadata = await _service.load();
      _loaded = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('MetadataProvider load failed: $e');
    }
    notifyListeners();
  }

  AppUris get uris => sanitizeUris(_metadata?.uris);

  Map<String, PartnerInfo> get partners {
    final raw = _metadata?.partners ?? const {};
    // 丢弃旧 Tavo/Volink 合作配置
    raw.removeWhere((k, v) =>
        k.toLowerCase().contains('volink') ||
        k.toLowerCase().contains('tavo') ||
        _looksLikeLegacyTavo(v.home) ||
        _looksLikeLegacyTavo(v.docs));
    return raw;
  }

  Map<String, SocialResource> get socials {
    final raw = Map<String, SocialResource>.from(
        _metadata?.socials ?? const <String, SocialResource>{});
    raw.removeWhere((_, v) => _looksLikeLegacyTavo(v.url));
    return raw;
  }

  Map<String, SocialVisibility> get visibility =>
      _metadata?.visibility ?? const {};

  Map<String, ExperimentConfig> get experiments =>
      _metadata?.experiments ?? const {};

  bool get displayVolink => false;

  bool get quickSetupEnabled => _metadata?.quickSetupEnabled ?? false;

  Map<String, List<PluginMarketBanner>> get pluginMarketBanners =>
      _metadata?.pluginMarketBanners ?? const {};
}
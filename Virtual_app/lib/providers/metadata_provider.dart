import 'package:flutter/foundation.dart';

import '../models/app_metadata.dart';
import '../services/metadata_service.dart';

/// 应用元数据 Provider
///
/// 启动时加载 metadata_default.json，向全局暴露
/// uris / partners / socials / visibility / experiments 等配置。
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

  AppUris? get uris => _metadata?.uris;

  Map<String, PartnerInfo> get partners => _metadata?.partners ?? const {};

  Map<String, SocialResource> get socials => _metadata?.socials ?? const {};

  Map<String, SocialVisibility> get visibility =>
      _metadata?.visibility ?? const {};

  Map<String, ExperimentConfig> get experiments =>
      _metadata?.experiments ?? const {};

  bool get displayVolink => _metadata?.displayVolink ?? true;

  bool get quickSetupEnabled => _metadata?.quickSetupEnabled ?? false;

  Map<String, List<PluginMarketBanner>> get pluginMarketBanners =>
      _metadata?.pluginMarketBanners ?? const {};
}
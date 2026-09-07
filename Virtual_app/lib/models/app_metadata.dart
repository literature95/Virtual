/// 应用元数据条目
class AppMetadataEntry {
  final String? desc;
  final String id;
  final String? name;
  final dynamic obj;
  final dynamic tag;

  const AppMetadataEntry({
    this.desc,
    required this.id,
    this.name,
    this.obj,
    this.tag,
  });

  factory AppMetadataEntry.fromJson(Map<String, dynamic> json) =>
      AppMetadataEntry(
        desc: json['desc'],
        id: json['id'] ?? '',
        name: json['name'],
        obj: json['obj'],
        tag: json['tag'],
      );

  T? objectAs<T>(T Function(dynamic) cast) => obj == null ? null : cast(obj);
}

/// 网络资源信息（uris）
class AppUris {
  final String customerServiceEmail;
  final String discord;
  final String help;
  final String homepage;
  final String models;
  final String partnerBanners;
  final String partnerDiscord;
  final String privacyPolicy;
  final String reddit;
  final String termsOfService;
  final String volinkAuth;
  final String volinkEmail;
  final String volinkHome;
  final String volinkPricing;

  const AppUris({
    required this.customerServiceEmail,
    required this.discord,
    required this.help,
    required this.homepage,
    required this.models,
    required this.partnerBanners,
    required this.partnerDiscord,
    required this.privacyPolicy,
    required this.reddit,
    required this.termsOfService,
    required this.volinkAuth,
    required this.volinkEmail,
    required this.volinkHome,
    required this.volinkPricing,
  });

  factory AppUris.fromJson(Map<String, dynamic> json) => AppUris(
        customerServiceEmail: json['customer_service_email'] ?? '',
        discord: json['discord'] ?? '',
        help: json['help'] ?? '',
        homepage: json['homepage'] ?? '',
        models: json['models'] ?? '',
        partnerBanners: json['partner_banners'] ?? '',
        partnerDiscord: json['partner_discord'] ?? '',
        privacyPolicy: json['privacy_policy'] ?? '',
        reddit: json['reddit'] ?? '',
        termsOfService: json['terms_of_service'] ?? '',
        volinkAuth: json['volink_auth'] ?? '',
        volinkEmail: json['volink_email'] ?? '',
        volinkHome: json['volink_home'] ?? '',
        volinkPricing: json['volink_pricing'] ?? '',
      );
}

/// 合作伙伴信息（partners）
class PartnerInfo {
  final String auth;
  final String binding;
  final String docs;
  final String email;
  final String home;
  final String pricing;

  const PartnerInfo({
    required this.auth,
    required this.binding,
    required this.docs,
    required this.email,
    required this.home,
    required this.pricing,
  });

  factory PartnerInfo.fromJson(Map<String, dynamic> json) => PartnerInfo(
        auth: json['auth'] ?? '',
        binding: json['binding'] ?? '',
        docs: json['docs'] ?? '',
        email: json['email'] ?? '',
        home: json['home'] ?? '',
        pricing: json['pricing'] ?? '',
      );
}

/// 社媒资源（socials）
class SocialResource {
  final List<String> locales;
  final List<String> placements;
  final String url;

  const SocialResource({
    required this.locales,
    required this.placements,
    required this.url,
  });

  factory SocialResource.fromJson(Map<String, dynamic> json) => SocialResource(
        locales: List<String>.from(json['locales'] ?? []),
        placements: List<String>.from(json['placements'] ?? []),
        url: json['url'] ?? '',
      );
}

/// 社媒可见性规则（visibility）
class SocialVisibilityRule {
  final bool enabled;
  final List<String> locales;
  final List<String> placements;

  const SocialVisibilityRule({
    required this.enabled,
    required this.locales,
    required this.placements,
  });

  factory SocialVisibilityRule.fromJson(Map<String, dynamic> json) =>
      SocialVisibilityRule(
        enabled: json['enabled'] ?? false,
        locales: List<String>.from(json['locales'] ?? []),
        placements: List<String>.from(json['placements'] ?? []),
      );
}

class SocialVisibility {
  final String? memberCount;
  final List<SocialVisibilityRule> rules;
  final String url;

  const SocialVisibility({
    this.memberCount,
    required this.rules,
    required this.url,
  });

  factory SocialVisibility.fromJson(Map<String, dynamic> json) =>
      SocialVisibility(
        memberCount: json['member_count'],
        rules: (json['rules'] as List?)
                ?.map((e) => SocialVisibilityRule.fromJson(e))
                .toList() ??
            [],
        url: json['url'] ?? '',
      );
}

/// 插件市场横幅
class PluginMarketBanner {
  final String action;
  final String url;

  const PluginMarketBanner({
    required this.action,
    required this.url,
  });

  factory PluginMarketBanner.fromJson(Map<String, dynamic> json) =>
      PluginMarketBanner(
        action: json['action'] ?? '',
        url: json['url'] ?? '',
      );
}

/// 灰度实验配置（experiments）
class ExperimentConfig {
  final bool enabled;
  final bool forceDisable;
  final String phase;
  final double rollout;
  final String salt;

  const ExperimentConfig({
    required this.enabled,
    required this.forceDisable,
    required this.phase,
    required this.rollout,
    required this.salt,
  });

  factory ExperimentConfig.fromJson(Map<String, dynamic> json) =>
      ExperimentConfig(
        enabled: json['enabled'] ?? false,
        forceDisable: json['force_disable'] ?? false,
        phase: json['phase'] ?? '',
        rollout: (json['rollout'] as num?)?.toDouble() ?? 0,
        salt: json['salt'] ?? '',
      );

  bool isInRollout(String salt) {
    if (forceDisable) return false;
    if (!enabled) return false;
    if (rollout >= 1) return true;
    var h = 0;
    final input = '$salt:$this.salt';
    for (final c in input.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 10000) / 10000.0 < rollout;
  }
}

/// 应用元数据（metadata_default.json 明文）
class AppMetadata {
  final List<AppMetadataEntry> entries;

  const AppMetadata({required this.entries});

  factory AppMetadata.fromJsonList(List<dynamic> json) =>
      AppMetadata(entries: json.map((e) => AppMetadataEntry.fromJson(e)).toList());

  AppMetadataEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  AppUris? get uris => byId('uris')?.obj == null
      ? null
      : AppUris.fromJson(Map<String, dynamic>.from(byId('uris')!.obj));

  Map<String, PartnerInfo> get partners {
    final entry = byId('partners');
    if (entry?.obj == null) return const {};
    final map = Map<String, dynamic>.from(entry!.obj);
    return map.map((k, v) => MapEntry(k, PartnerInfo.fromJson(v)));
  }

  Map<String, SocialResource> get socials {
    final entry = byId('socials');
    if (entry?.obj == null) return const {};
    final map = Map<String, dynamic>.from(entry!.obj);
    return map.map((k, v) => MapEntry(k, SocialResource.fromJson(v)));
  }

  Map<String, SocialVisibility> get visibility {
    final entry = byId('visibility');
    if (entry?.obj == null) return const {};
    final map = Map<String, dynamic>.from(entry!.obj);
    return map.map((k, v) => MapEntry(k, SocialVisibility.fromJson(v)));
  }

  bool get displayVolink => byId('display-volink')?.obj == true;

  /// 用量追踪密钥（证据：pp+0x20e70 `api-secret`；
  /// 用于 WukTrace 初始化，缺失时追踪禁用）
  String? get apiSecret => byId('api-secret')?.obj?.toString();

  bool get quickSetupEnabled => byId('quick-setup')?.obj == true;

  Map<String, ExperimentConfig> get experiments {
    final entry = byId('experiments');
    if (entry?.obj == null) return const {};
    final map = Map<String, dynamic>.from(entry!.obj);
    return map.map((k, v) => MapEntry(k, ExperimentConfig.fromJson(v)));
  }

  Map<String, List<PluginMarketBanner>> get pluginMarketBanners {
    final entry = byId('plugin-market');
    if (entry?.obj == null) return const {};
    final obj = Map<String, dynamic>.from(entry!.obj);
    final banner = obj['banner'];
    if (banner == null) return const {};
    return Map<String, dynamic>.from(banner).map(
      (k, v) => MapEntry(
        k,
        (v as List).map((e) => PluginMarketBanner.fromJson(e)).toList(),
      ),
    );
  }
}
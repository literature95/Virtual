/// 后端服务配置
///
/// 以下端点均来自 libapp.so 对象池反编译证据（Blutter pp.txt，
/// 见 reverse_analysis/blutter_out/pp.txt），非猜测值：
/// - `https://og.tavo.cc/api/metadata`（pp+0x1d5c0）
/// - `https://og.tavo.cc/` + `/api/metadata`（pp+0x1f830 / pp+0x1f898）
/// - `https://ag.tavo.cc/` + `/api/accounts/anonymous`（pp+0x1d748 / pp+0x1d760）
/// - `https://tavoai.dev/registry`（pp+0xe5f0）
/// - `https://hub.tavoai.dev/plugin-market/`（pp+0x2aff8 附近）
/// - `https://docs.tavoai.dev/`（pp+0x52610）
class BackendConfig {
  BackendConfig._();

  /// 主 API 网关
  static const String apiBaseUrl = 'https://og.tavo.cc';

  /// 应用元数据远程获取路径
  static const String metadataPath = '/api/metadata';

  /// 应用元数据完整 URL
  static const String metadataUrl = 'https://og.tavo.cc/api/metadata';

  /// 匿名账号网关（原 app 中该 base 与主网关分离）
  static const String anonymousAccountBase = 'https://ag.tavo.cc';

  /// 匿名账号注册路径
  static const String anonymousAccountPath = '/api/accounts/anonymous';

  /// 插件注册表（原 app 官方注册表地址）
  static const String registryUrl = 'https://tavoai.dev/registry/';

  /// 插件市场
  static const String pluginMarketUrl = 'https://hub.tavoai.dev/plugin-market/';

  /// 文档站
  static const String docsBaseUrl = 'https://docs.tavoai.dev/';

  /// 分发渠道标识（原 app 枚举 vM：androidGooglePlay / iosTestflight / iosAppStore）
  static const String channel = 'android_googleplay';

  /// 平台标识
  static const String platform = 'android';

  /// 元数据请求超时
  static const Duration metadataTimeout = Duration(seconds: 10);
}

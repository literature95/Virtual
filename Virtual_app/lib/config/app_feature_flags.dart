/// 全局功能开关。
///
/// 本地模型（GGUF + nobodywho）部署能力已停用：模型不再打包进 APK，
/// 端点编辑页不再提供「部署」入口，已存在的部署型端点保留但不可推理。
/// 相关代码保留，未来把 [localDeployEnabled] 置为 true 并恢复打包配置即可。
class AppFeatureFlags {
  const AppFeatureFlags._();

  /// 是否启用「部署」型端点（本地模型推理）。
  static const bool localDeployEnabled = false;
}

/// 全局功能开关。
///
/// 本地模型（GGUF + nobodywho）部署能力已恢复：默认不打包任何模型，
/// 由用户在「部署」型端点里自行导入 GGUF 文件（见
/// `services/local_model_service.dart`）。APK 内 `.gguf` 条目恒为 0。
class AppFeatureFlags {
  const AppFeatureFlags._();

  /// 是否启用「部署」型端点（本地模型推理）。
  static const bool localDeployEnabled = true;
}

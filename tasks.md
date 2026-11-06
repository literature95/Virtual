# 历史归档：本地模型对话稳定性修复任务清单

> **该方案已停用，仅存档。**
>
> 对应 [`spec.md`](spec.md)。该清单记录 2026-11-04 本地模型（GGUF + nobodywho）稳定性修复的
> 执行过程，相关能力已于同日随本地部署整体下线，**任务状态仅代表当时**。
> 现行能力见 [`README.md`](README.md) 第 4.1 节「端点接入/部署（历史归档）」。

## 当时任务状态（全部完成于 2026-11-04，后随方案停用）

1. [x] `endpoint.dart`：`kDefaultContextSize 8192`；新增 `repetitionPenalty`（clamp 1.0–1.3）。
2. [x] 适配器接口与转发：`llm_adapter.dart`、`api_service.dart` 增加可选 `conversationId`。
3. [x] `nobodywho_adapter.dart`：会话隔离、显式 `ContextShiftOptions`、`penalties` 采样、按 ctx 真裁、错误中文映射。
4. [x] `chat_provider.dart`：调用链传 `conversationId`。
5. [x] `endpoint_edit_page.dart`：重复惩罚滑杆（1.0–1.3）。
6. [x] `pubspec.yaml`：当时版本 `1.0.18+19`。
7. [x] `README.md`：参数与裁剪策略（后来随停用改为归档说明）。
8. [x] `flutter analyze` / `flutter test` 与基线一致。
9. [x] 出包并核查体积/版本/签名/gguf。
10. [x] 输出交付报告（未 commit、未上线）。

## 停用后的处理（当前实际）

- 功能开关关闭：`AppFeatureFlags.localDeployEnabled = false`；
- 模型资源与安装通道、内置模型服务、Gradle 打包配置全部移除；
- 端点默认参数回滚；
- 恢复方式：仅需把开关置回 `true` 并恢复打包配置，代码本身保留。

## 当时列出的真机复测点（已无对象，仅存档）

- 长角色卡 + 连续 10 轮对话；
- 上下文长度 4096 / 8192 两档；
- 会话 A ↔ B 来回切换无串场；
- 重复惩罚 1.0 / 1.1 / 1.3 对比；
- 关闭 GPU / 线程 2 的降级路径；
- 中途中止生成后再次发送。

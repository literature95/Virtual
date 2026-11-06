# 历史归档：本地模型对话稳定性修复 Spec

> **该方案已停用，仅存档。**
>
> 本文件记录 2026-11-04 为「内置 GGUF + nobodywho 本地推理」做的稳定性修复方案。
> 该能力已于 **2026-11-04** 随本地部署整体下线（`AppFeatureFlags.localDeployEnabled = false`），
> 文中所有默认值、字段与策略**均不代表当前产品行为**。现行能力请以
> [`README.md`](README.md) 第 4.1 节「端点接入/部署（历史归档）」与
> [`Virtual_app/README.md`](Virtual_app/README.md) 第 5.1 节「本地部署已停用」为准。

## 停用原因

1. 真机效果不达标：0.8B 模型只发「你是」两字就续写大段无关设定，角色扮演可用性低。
2. 体积与安装成本过高：APK 约 568MB（模型 508MB），装机另需约 1.3GB 空闲空间。
3. 分发受限：内置模型授权/分发不适配应用商店，只能自用分发。
4. 真机测试后决定放弃，改为只保留云端「接入」型端点。

## 回滚结果（当前实际状态）

| 项 | 结果 |
|---|---|
| 功能开关 | `lib/config/app_feature_flags.dart` → `localDeployEnabled = false` |
| 端点编辑页 | 只渲染「接入」，部署型控件全部不渲染 |
| 已存在的部署型端点 | 列表仍可见，进入对话提示「本地部署已停用」，不做本地推理 |
| 模型资源 | `android/app/src/main/assets/models/*.gguf` 已删除；`MainActivity` 模型安装通道已移除 |
| 内置模型服务 | `lib/services/builtin_model_service.dart` 已删除 |
| Gradle | 移除 `noCompress 'gguf'` 与 `jniLibs.excludes`，`jvmargs` 回到 `-Xmx2G` |
| 默认参数 | `contextSize 4096` / `maxTokens 1024` / `temperature 0.7`（本地调优值已撤销） |
| 出包 | 1.0.27+28 为 108,003,841 B，APK 内 `.gguf` = 0 |

## 存档内容概要（当时实现，现已不生效）

- 按 `endpointId + conversationId` 隔离 Chat，切换会话重建并 `resetHistory`；
- 显式 `ContextShiftOptions(keepFirstTurns: 1, keepLastTurns: 1)`；
- 发送前按 `Chat.tokenize` 真裁历史，system 常驻、从最老消息丢；
- `SamplerBuilder.penalties(penaltyRepeat: 1.0–1.3)` 重复惩罚；
- 错误中文映射（上下文不足 / 模型缺失 / OOM）；
- 独立组装层 `local_prompt_builder.dart`：压缩角色卡 ≤300 token、最近 4 轮、75% 阈值裁剪。

上述代码仍保留在仓库中，仅作将来恢复时的参考；云端对话分支不调用。

# Virtual 项目分析报告

> 分析日期：2026-09-08　分析范围：`Virtual_app` / `Virtual_background` / `Virtual_web`
> 说明：本报告聚焦**架构判断、风险与建议**，功能清单与启动方式见根目录 `README.md`。

## 一、项目定位

Virtual 是一个 **AI 角色聊天**全栈项目，由三端构成一个 monorepo：

| 子项目 | 技术栈 | 职责 | 代码规模 |
|---|---|---|---|
| `Virtual_app` | Flutter 3.x / Dart | 聊天客户端，功能主体 | 82 文件 · 22,547 行（92%） |
| `Virtual_background` | Dart Frog 1.x（shelf） | 本地 API：元数据、角色卡、应用信息 | 10 文件 · 614 行（3%） |
| `Virtual_web` | React 19 + Vite 8 | 官网展示 + 角色卡浏览 | 6 文件 · 1,263 行（5%） |

版本控制：Git 单分支 `main`，3 次提交（2026-09-05 起），工作区干净。

**核心判断**：这是一个**客户端驱动**的项目。App 承载了几乎全部业务复杂度，后端目前只是「带降级能力的静态数据源」，官网是品牌展示页。三端不是对等关系，而是「1 主 + 2 辅」。

## 二、关键架构决策与评价

### 决策 1：模型调用直连厂商，其余走本地后端

App 通过 `services/api_service.dart` 按 `endpoint.platform` 分发到三个适配器：

- `OpenAiCompatibleAdapter` — 覆盖 OpenAI / DeepSeek / Qwen / Moonshot / GLM / xAI / Groq / Together / Fireworks / MiniMax 等 20+ 兼容平台
- `AnthropicApiAdapter` — Claude
- `GeminiApiAdapter` — Google / Vertex AI

三者均实现 SSE 流式，OpenAI 适配器已解析 `reasoning_content` / `reasoning` / `thinking` 思维链字段。

**评价**：合理。避免了自建代理带来的延迟、成本与密钥托管责任，也让「本地优先」的隐私叙事成立。代价是**密钥保存在客户端**，且无法在服务端做审计、限流、缓存。

### 决策 2：PostgreSQL 可选 + 内存种子降级

后端 `lib/database/db.dart` 用 3 秒超时尝试连库，失败则 `isAvailable=false`，所有路由回退到 `lib/database/seed.dart` 的内存数据（5 个手写角色）。

**评价**：开发体验友好，但**生产不可用**——降级态下后端等价于静态 JSON 服务，任何写入都不持久。

### 决策 3：App 本地优先存储

`data/app_database.dart` 用 SharedPreferences 存整表 JSON，键为 `db_characters` / `db_conversations` / `db_messages_<id>` / `db_endpoints` / `db_lorebooks` / `db_presets` / `db_regex` / `db_themes` / `db_personas` / `db_plugins`。

**评价**：与定位一致，但见风险 R2。

## 三、Virtual_app 内部分层

```
main.dart  →  MultiProvider（5 个 ChangeNotifier）
  ├─ providers/   settings / metadata / endpoint / character / chat
  ├─ services/    api_service + adapters/（LLM）+ asr / tts / image_generation /
  │               web_search / plugin / preset / lorebook / prompt / regex /
  │               model_registry / metadata / backup / character_import|export /
  │               online_character / platform_presets / backend_config
  ├─ models/      11 个：character / chat_message / conversation / endpoint /
  │               lorebook / persona / preset / regex_rule / plugin /
  │               chat_theme / app_metadata / agent_run
  ├─ views/       按域分目录（character / chat / home / discover / profile /
  │               settings / endpoint / lorebook / preset / regex / plugin /
  │               theme / more / onboarding / debug / common）
  ├─ route/       GoRouter，30+ 路由，ShellRoute 包裹 5 Tab
  └─ theme/       design_tokens（单一来源）+ app_theme（浅/深双主题）+ tavo_brand
```

状态管理用 Provider，`chat_provider` 通过 `ChangeNotifierProxyProvider3` 注入 Settings/Character/Endpoint 依赖——依赖注入清晰，是这个 codebase 里质量较高的部分。

设计系统上已完成一轮统一（2026-09-07）：`design_tokens.dart` 作为颜色/间距/圆角/字号的唯一来源，消除了此前多套紫色并存的问题。

## 四、风险清单

| 级别 | 编号 | 问题 | 影响 |
|---|---|---|---|
| **高** | R1 | 后端**零写接口**：仅有 5 个 GET 端点，无 POST/PUT/DELETE；无鉴权，CORS 为 `*` | 无法做用户体系、角色卡投稿、数据同步，只能当静态服务用 |
| **高** | R2 | App 用 SharedPreferences 存**整表 JSON**，消息表为 `db_messages_<id>` | 单键值随会话数增长不断膨胀，长会话下读写全量反序列化，存在性能悬崖；无迁移/版本机制 |
| **中** | R3 | `lib/database/seed.dart` 中 `api-secret` 的 key 与 iv **明文硬编码**并通过 `/api/metadata` 下发 | 任何能访问后端的人都能拿到；即便只是占位也应移出代码库 |
| **中** | R4 | 测试近乎为零：App 仅 2 个测试（其中 1 个是模板计数器占位），后端 **0 个**，官网无测试 | 22k 行代码无回归保护，重构风险高 |
| **中** | R5 | 角色卡 `avatar_url` 全部指向外部文生图 API `trae-api-cn.mchost.guru` | 第三方域名，随时可能失效或变更；App 与官网的图片展示都依赖它 |
| **低** | R6 | 国际化只做了框架级：`flutter_localizations` + `supportedLocales`（zh_CN/en_US/ja_JP），**无 .arb 文件**，UI 文案硬编码中文 | 设置页的语言切换实际只影响 Material 组件文案，业务界面不会切换 |
| **低** | R7 | 官网无接口降级数据：后端离线时角色区直接隐藏、下载按钮回退为 `#`；`api.metadata` 封装了但从未调用 | 展示中断；`assets/hero.png`、`react.svg`、`vite.svg` 为未使用残留 |
| **低** | R8 | README 与实现不一致：写 React 18，实际 `react@19.2`；写 Flutter 3.47.1，后端 SDK 约束为 `^3.11.0` | 新成员按文档装依赖会踩坑 |

## 五、建议的下一步（按投入产出排序）

1. **补后端写接口 + 基础鉴权**（解 R1）
   加 `POST /api/characters` 等写入口与一个简单的 token 校验，先把「角色卡投稿/同步」链路打通。这是从「能跑的 demo」走向「可用产品」的分水岭。

2. **消息存储换成 SQLite**（解 R2）
   项目已引入 `sqflite ^2.3.3` 依赖但未使用。按 `conversation_id` 建表 + 分页查询即可，改动集中在 `AppDatabase` 内部，可保持对外 API 不变。

3. **移除硬编码密钥**（解 R3）
   改用 `String.fromEnvironment` 读取，未提供时不下发该字段。

4. **为核心链路补测试**（解 R4）
   优先级：`PromptService`（多模态消息组装）→ `ApiService` 适配器分发 → `AppDatabase` 序列化。这三个是回归时最容易静默出错的部分。

5. **图片资源自持**（解 R5）
   把 5 个角色立绘落到本地 `assets/` 或自建对象存储，去掉对第三方文生图 API 的运行时依赖。

6. **校正 README 版本表**（解 R8）
   顺手改，成本低。

## 六、尚未启动的能力

README 的「下一步」里列了 TTS/ASR/图片生成/联网搜索代理到后端，但 `Virtual_app/lib/services/` 下**已存在** `asr` / `tts` / `image_generation` / `web_search` 四个服务——说明这些能力已在 App 侧直连实现，尚未收敛到后端。是否要走后端代理，取决于是否要做统一的用量统计与计费，目前看收益有限，可暂缓。

---

**总体结论**：项目骨架完整、分层清晰、设计系统已统一，具备继续迭代的基础。当前最大瓶颈不在客户端，而在**后端能力缺失**（只读、无鉴权、无持久化保障）与**测试近乎空白**。若要往前推进，优先级应是「后端可写 + 存储可扩 + 关键路径有测试」，而非继续堆客户端功能。

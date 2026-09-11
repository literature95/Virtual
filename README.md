# Virtual

## 一、项目介绍

Virtual 是一个**本地优先、跨模型、隐私向**的 AI 角色聊天全栈项目。用户可创建、导入并与 AI 角色进行沉浸式流式对话，同时自由接入任意大模型服务。

核心特色：

| 特色 | 说明 |
|---|---|
| **本地优先** | 数据默认保存在设备本地，不上云，隐私可控、离线可用 |
| **跨模型接入** | 直连 20+ LLM 平台（OpenAI 兼容 / Anthropic / Gemini），支持 BYOK（自带密钥） |
| **自托管后端** | 除模型调用外，所有外部服务走本地后端，后端地址可配置（本机 / 局域网 / 自建服务器） |
| **角色卡系统** | 导入、创建、分享 AI 角色，内置 5 个种子角色与在线角色卡广场 |
| **多模态对话** | 支持图片输入，转 OpenAI 视觉格式参与对话 |
| **统一品牌视觉** | 深空色 + 三色签名渐变（紫→珊瑚→橙）+ 玻璃拟态，App / Web 双端一致 |

项目定位为「自托管工具」：目标是成为隐私敏感用户与技术爱好者在移动端/桌面端可自持的 AI 角色聊天客户端，而非对标云端 SaaS 的巨型产品。

## 二、技术栈

| 端 | 技术 | 版本 | 职责 |
|---|---|---|---|
| **Virtual_app** | Flutter / Dart | Flutter 3.47.1 · Dart 3.13.1 | 聊天客户端，功能主体（占约 92% 代码量） |
| **Virtual_background** | Dart Frog（shelf） | dart_frog 1.2.6 · shelf 1.4.2 | 本地 API 服务，端口 `:8080` |
| **Virtual_web** | React + Vite | React 19 · Vite 8 | 官网 + 角色卡浏览，端口 `:5173` |

关键依赖：

| 类别 | 依赖 |
|---|---|
| 状态管理 | Provider（5 个 ChangeNotifier） |
| 路由 | GoRouter（30+ 路由，ShellRoute 包裹 5 Tab） |
| 网络 | Dio、http（App 直连 LLM 厂商）；Dart Frog/shelf（后端） |
| 本地存储 | SharedPreferences（整表 JSON 持久化，已引 `sqflite` 待启用） |
| 数据库（可选） | PostgreSQL（`postgres` 驱动，未安装自动降级到内存种子） |
| UI 组件 | flutter_markdown、cached_network_image、image_picker、lottie 等 |
| 设计系统 | `design_tokens.dart` 单一来源（颜色/间距/圆角/字号） |
| 测试 | flutter_test（App）、test + mocktail（后端）、oxlint（Web） |

架构原则：

1. **除模型调用外**，App 所有外部服务走 `Virtual_background` 本地后端
2. **模型调用**保持 App 直连厂商 API（OpenAI 兼容 / Anthropic / Gemini 三适配器，均 SSE 流式）
3. **PostgreSQL 可选**：未安装时后端自动降级到内存种子数据

```
┌─────────────────┐         ┌────────────────────┐        ┌────────────┐
│ Virtual_web      │────────▶│                    │───────▶│ PostgreSQL │
│ React 官网       │  5173   │ Virtual_background │        │ (可选)     │
└─────────────────┘         │   Dart Frog :8080  │        └────────────┘
┌─────────────────┐         │                    │
│ Virtual_app      │────────▶│  /api/*            │        ┌────────────┐
│ Flutter 移动端   │ 设置页配 │  /avatars/*        │───────▶│ LLM 厂商   │
│                  │后端地址   │                    │        │ (直连)     │
└─────────────────┘         └────────────────────┘        └────────────┘
```

## 三、文件结构

```
d:\Documents\Desktop\Virtual\
├── Virtual_app/                 # Flutter 客户端（功能主体）
│   ├── lib/
│   │   ├── main.dart            # 入口，MultiProvider 装配
│   │   ├── providers/           # 5 个 ChangeNotifier：settings/metadata/endpoint/character/chat
│   │   ├── services/            # 业务服务层
│   │   │   ├── adapters/        #   LLM 适配器：openai/anthropic/gemini/llm_adapter
│   │   │   ├── api_service.dart #   模型调用分发（按 platform 路由到适配器）
│   │   │   ├── asr/tts/image_generation/web_search_service.dart  # 已直连实现，未收敛后端
│   │   │   ├── online_character_service.dart   # 在线角色卡（后端 /api/characters）
│   │   │   ├── prompt_service.dart             # 多模态消息组装
│   │   │   └── ...（preset/lorebook/regex/plugin/backup/import/export 等 20 个）
│   │   ├── models/              # 12 个数据模型：character/chat_message/conversation/endpoint/
│   │   │                        #   lorebook/persona/preset/regex_rule/plugin/chat_theme/
│   │   │                        #   app_metadata/agent_run
│   │   ├── views/               # 按域分目录（character/chat/home/discover/profile/settings/
│   │   │                        #   endpoint/lorebook/preset/regex/plugin/theme/more/
│   │   │                        #   onboarding/debug/common）
│   │   ├── route/               # GoRouter，30+ 路由，ShellRoute 包裹 5 Tab
│   │   ├── theme/               # design_tokens（唯一来源）+ app_theme（浅/深双主题）+ tavo_brand
│   │   ├── data/                # app_database.dart（SharedPreferences 持久化）
│   │   └── utils/               # image_data 等工具类
│   └── test/                    # 2 个测试（settings_provider / widget）
│
├── Virtual_background/          # Dart Frog 后端（端口 8080）
│   ├── routes/
│   │   ├── _middleware.dart     # 全局 CORS 中间件
│   │   ├── api/                 # health / metadata / characters(index,[id]) / app-info
│   │   └── avatars/[file].dart  # 角色立绘静态文件（白名单 + 路径穿越防护）
│   ├── lib/
│   │   ├── config.dart          # 环境配置（DB 连接等）
│   │   ├── avatar_url.dart      # 立绘 URL 解析器（相对路径 → 按请求来源补全）
│   │   ├── character_card_mapper.dart # 角色卡映射/校验/共享 upsert SQL
│   │   └── database/            # db.dart（连接 + 降级）+ seed.dart（5 个种子角色）
│   ├── tool/import_cards.dart   # 角色卡批量导入（PNG/JSON → PG upsert + 立绘落盘）
│   ├── public/avatars/          # 5 张本地立绘（char-001~005.jpg）
│   └── test/                    # 57 个测试（种子契约 / avatar URL / 往返 / 中文 id / PNG 提取）
│
├── Virtual_web/                 # React 官网（端口 5173）
│   └── src/
│       ├── api/client.js        # API 封装
│       ├── pages/               # Home.jsx（首页）+ Characters.jsx（角色卡浏览）
│       ├── App.jsx / App.css    # 入口 + 深空设计系统
│       └── assets/              # 静态资源
│
├── docs/                        # 项目分析与战略评估文档
├── .github/workflows/ci.yml     # CI：App analyze+test / 后端 analyze+test / Web lint+build
└── README.md
```

## 四、各端功能与计划

### 4.1 Virtual_app（Flutter 客户端）

**已实现：**

| 功能域 | 说明 |
|---|---|
| 导航 | 5 Tab 主导航（首页/发现/对话/角色/我的），窄屏 NavigationBar / 宽屏 NavigationRail；GoRouter 30+ 路由 |
| 首页 | 在线角色卡广场：后端 `/api/characters` 拉取 + 分类过滤 chips + 搜索；竖版封面卡（0.62 比例、照片铺满、2~3 列网格，已导入角色带角标）；点击卡片 → 拉详情 → 幂等导入 → 直达对话（已聊过则回原对话） |
| 对话 | 会话列表（搜索/置顶/长按菜单：重命名/置顶/删除）；聊天页流式输出、导出 Markdown、清空消息、模型信息 |
| 角色 | 本地角色管理（搜索 + 复制角色）；**角色卡导入/导出 —— 唯一格式为 PNG**（内嵌 CCv3 全字段与 `character_book` 世界书），Web/桌面/移动共用一条字节流路径，浏览器端亦可导出下载 |
| 世界书 | **Lorebook 管理 —— 唯一格式为 JSON**：导入自动识别 SillyTavern World Info（`entries` 为对象）/ CCv3 `character_book`（`entries` 为数组）/ 本 App 导出格式；导出为 SillyTavern 形态，便于跨前端交换 |
| 模型接入 | OpenAI 兼容（20+ 平台）/ Anthropic / Gemini 三适配器，均 SSE 流式，已解析思维链字段 |
| 多模态 | 图片输入（≤4 张，预览条可删除），转 OpenAI 视觉格式（data URL） |
| 发现 | 扩展内容聚合：世界书/预设/正则/插件/主题/调试 |
| 我的 | 头像/昵称/ID + 我的角色卡计数 + API 接入/主题外观/插件/更多 |
| 设置 | 后端地址配置、语言切换（跟随系统/简中/English/日本語）、数据迁移（JSON 导出导入） |
| 设计系统 | `design_tokens.dart` 单一来源 + 浅/深双主题 + 星空背景/玻璃拟态，与 Web 端统一 |

**格式约定（项目级，非可选）：角色卡用 PNG，世界书用 JSON。**

**角色卡导入来源支持矩阵：**

| 来源 | 形态 | Web | 桌面 | 移动 |
|---|---|---|---|---|
| PNG 卡片 | `tEXt` / `zTXt` / `iTXt` 中的 `chara` / `ccv3`（base64，规范形态；压缩块自动 zlib 解压） | ✅ | ✅ | ✅ |
| URL 直链 | 裸 JSON 端点（保留的远程获取通道，不受本地文件格式约束） | ✅ | ✅ | ✅ |

**角色卡导出**：统一 PNG —— 写入 `chara` 与 `ccv3` 两个 `tEXt` 块（值同为
`base64(UTF-8 CCv3 JSON)`）。底图取角色立绘，无立绘时生成品牌色占位图；
`data:` URL 头像会被剥离为 `"none"`，避免同一张图在卡内存两遍。

**世界书导入/导出**：统一 JSON。导入自动识别三种形态（SillyTavern World Info /
CCv3 `character_book` / 本 App 导出），导出为 SillyTavern World Info 形态。
注意 SillyTavern 与 CCv3 的同名字段语义不同（`disable` 与 `enabled` 相反、
`position` 是整数 0..4），照搬会**静默**出错 —— 映射表见文档第九节。

已知不支持：JPEG / WEBP 内嵌卡片（存量卡片几乎全是 PNG）、chub.ai 网页链接
（其公开下载 API 已废弃，需先在页面点 Download 拿到文件）。
若一块卡片同时带 `chara` 与 `ccv3` 且内容不一致，取 `spec` 版本更高的一方，
避免丢掉 V3 独有字段。
容器布局、写入规范与世界书字段映射见 `docs/character-card-schema.md` 第八、九节。
卡片疑似有问题时：

```bash
# 看某张 PNG 到底有哪些 chunk（块级取证）
python Virtual_app/tool/inspect_card_png.py <文件.png>
# 逐张诊断，或对整库做回归（输出成功率 / 关键字分布 / 失败清单）
dart run Virtual_app/tool/card_png_probe.dart <文件或目录>
```

**待实现：**

- [ ] 消息存储由 SharedPreferences 整表 JSON 迁移到 SQLite（`sqflite` 已引入未启用，解决长会话性能悬崖）
- [ ] 国际化补全 `.arb` 文件（当前仅框架级，业务文案硬编码中文）
- [ ] 决定 TTS/ASR/图片生成/联网搜索是否收敛到后端（App 侧已直连实现，视统一计费需求而定）

### 4.2 Virtual_background（Dart Frog 后端）

**已实现：**

| 端点 | 用途 |
|---|---|
| `GET /api/health` | 健康检查 |
| `GET /api/metadata` | App 元数据（顶级数组，`api-secret` 仅在编译期注入时下发） |
| `GET /api/characters` | 角色卡列表（精简字段：id/name/description/avatarUrl/tags/greeting/persona/creator/characterVersion） |
| `GET /api/characters/:id` | 角色卡详情（**完整 CCv3 字段** + `characterBook` 世界书原样下发） |
| `POST /api/characters` | **发布角色卡**（multipart：`card`=角色卡 JSON、`avatar`=立绘文件；按 `id + character_version` upsert，同版本覆盖、换版本新增一行；卡内 `avatar: "none"` 占位值归一化为 NULL；可选 `X-Api-Token` 鉴权） |
| `GET /api/characters/:id/export` | 导出角色卡（CCv2 完整包；上传过的角色由 `raw_card` 原样吐回，保证上传=导出） |
| `GET /api/app-info` | 应用介绍/下载信息 |
| `GET /api/avatars/:file` | 内置角色立绘（jpg/png/webp 白名单，1 天缓存） |
| `GET /api/uploads/:file` | 用户上传立绘（发布接口写入 `public/uploads/`，同白名单与 CORS 处理） |

其他能力：全局 CORS 中间件；PostgreSQL 可选 + 失败降级内存种子（5 个角色，空库首次启动自动灌入）；角色卡 schema 已对齐 App 的完整角色模型（`characters` 表 27 列，含幂等增量迁移，**复合主键 `(id, character_version)`** 支持多版本）；**中文（非 ASCII）id 全链路可用** —— `slugify` 保留汉字，详情/导出路由对路径参数补解码（dart_frog 不解码，Dart `Uri.path` 也只归一化 ASCII 转义），立绘文件名对非 ASCII id 追加 FNV-1a 短哈希以免不同中文名同版本互相覆盖；立绘本地化（存相对路径，响应时按请求来源补全绝对 URL，App/Web 零改动）；api-secret 与 PUBLISH_TOKEN 编译期外置（`String.fromEnvironment`）；57 个单元测试（含角色卡密度护栏、Cricket 卡 round-trip、中文 id 编码回归、PNG 卡内文本块提取）。

**批量导入角色卡（PNG / JSON → 数据库）**：`tool/import_cards.dart` 把角色卡批量灌入 PostgreSQL，与 `POST /api/characters` 同一条 mapper/upsert 链路。**PNG 卡片**会解析其 `tEXt`/`zTXt`/`iTXt` 文本块取出内嵌卡片数据，并把**卡面图像本身落盘为立绘**（`public/uploads/`，命名与上传协议一致），App 的角色墙据此显示头像：

```bash
cd Virtual_background
# 单张卡试跑：只解析，不落库不落盘
dart run tool/import_cards.dart "/路径/xx.png" --dry-run
# 卡库批量导入（PNG 卡库通常需要递归）
dart run tool/import_cards.dart "/路径/卡库" --recursive
```

选项：`--recursive` 递归子目录 · `--limit=N` 限量 · `--batch-size=N` 每事务条数（默认 100） · `--no-avatar` 不落盘立绘 · `--avatar-dir=PATH` · `--id-from=name|file`（默认 `name`，取卡内 name 的 slug 并保留中文） · `--dry-run`。批量事务 + 坏行隔离，同 `(id, character_version)` 覆盖，可重跑幂等；同名不同卡会互相覆盖，运行结束会报告重复计数（此时建议 `--id-from=file`）。

注意：`GET /api/characters` 列表接口尚无分页，单次导入建议控制在几千张以内（万级会拖垮 App/Web 列表加载）。

发布协议设计见 [`docs/character-publish-design.md`](docs/character-publish-design.md)。

**待实现：**

- [ ] 写接口补全：`PUT/PATCH/DELETE /api/characters`（POST 已支持；改删与版本历史列表待加）
- [ ] 基础鉴权：`X-Install-Token` 自签 token 校验（当前仅 POST 支持可选 `X-Api-Token`）
- [ ] Docker Compose 部署模板（PostgreSQL + 后端 + 数据卷）
- [ ] 部署文档 `docs/deploy.md`（一键启动、升级、备份）
- [ ] `metadata` 端点查询参数（`?ch=&lc=&pf=`）实际生效

### 4.3 Virtual_web（React 官网）

**已实现：**

- 官网首页：Hero 区（左文右机不对称布局 + 漂浮玻璃胶囊 + CSS 手机 mockup）+ 角色卡预览 + 应用介绍
- 角色卡浏览页：后端 `/api/characters` 拉取 + 沉浸式图片卡 + 详情弹窗
- 深空设计系统：近黑深空 `#0e0e0e` + 星空闪烁 + 三色签名渐变 + 楷体 display 字体
- `/api` 代理到后端 `:8080`

**待实现：**

- [ ] 角色卡管理后台
- [ ] 接口离线降级数据（后端不可用时角色区隐藏、下载按钮回退为 `#`）
- [ ] 补充更多角色立绘（当前 5 个）
- [ ] 清理未使用静态资源（`hero.png`、`react.svg`、`vite.svg`）

### 4.4 后续计划（按优先级）

| 优先级 | 阶段 | 内容 |
|---|---|---|
| 短期 | Tier 2 | 后端写接口 + 基础鉴权、Docker Compose、部署文档、metadata 查询参数生效 |
| 中期 | 存储与质量 | SQLite 替换 SharedPreferences、国际化 `.arb` 补全、关键路径测试扩充 |
| 长期 | 能力收敛 | TTS/ASR/图片生成/联网搜索代理到后端（若需统一用量统计）、Web 角色卡管理后台、CI/CD + Release 签名 |

## 五、快速启动

### 1. 启动后端（先启动，App 和 Web 都依赖它）

```bash
cd Virtual_background
dart pub get
dart_frog dev --port 8080
# ✅ http://localhost:8080
```

用量追踪密钥（可选，默认不下发）：通过编译期变量注入，未提供时 `/api/metadata` 不含 `api-secret` 条目，App 自动禁用追踪：

```bash
# dev 模式
dart_frog dev --port 8080 --dart-define=API_SECRET_KEY=xxx --dart-define=API_SECRET_IV=yyy
# 或直接运行构建产物（JIT 模式下 -D 生效）
dart -DAPI_SECRET_KEY=xxx -DAPI_SECRET_IV=yyy build/bin/server.dart
```

### 2. 启动 Web 官网

```bash
cd Virtual_web
npm install
npm run dev
# ✅ http://localhost:5173  （已配置 /api 代理到 8080）
```

### 3. 启动 Flutter App

```bash
cd Virtual_app
flutter pub get
flutter run
```

App 首次启动后，进入 **设置 → 后端地址**，默认 `http://localhost:8080`，可改为：
- 真机调试：`http://<电脑IP>:8080`（如 `http://192.168.1.145:8080`）
- 自定义部署服务器地址

## 六、故障排查

| 问题 | 解决 |
|---|---|
| 后端启动报错 `StdinException` | Windows 终端不影响 HTTP 服务，看 "Running on http://localhost:8080" 即可 |
| 非交互 shell 下 `dart_frog dev` 报 mason `BricksJson.rootDir` 空指针 | 沙箱/CI 环境缺 `APPDATA` 变量，设置 `MASON_CACHE=<任意目录>` 即可；仍异常时改用 `dart_frog build` + `dart build/bin/server.dart` |
| 后端连接 PostgreSQL 失败 | 正常降级到内存数据，控制台会显示 "degraded to memory" |
| App 元数据加载失败 | 自动回退 `assets/metadata_default.json`，无网也能跑 |
| Web `npm run dev` 启动但 API 404 | 确认后端 8080 端口已启动 |
| 真机 App 连不上后端 | 改设置页后端地址为 `http://<电脑局域网IP>:8080` |

## 七、相关文档

| 文档 | 内容 |
|---|---|
| `docs/character-card-schema.md` | 角色卡字段映射（CCv2/v3 → App）、`mes_example` 说话人解析规则、世界书映射、Prompt 组装顺序、密度护栏 |
| `docs/project-analysis-2026-09-08.md` | 全项目架构分析与技术债清单 |

## 八、开发约束

- 后端 API **端口与 JSON 格式与 App 现有调用保持一致**，App 解析逻辑零改动
- 先能运行再逐步完善
- **文档时时同步**（改代码要同步更新 README）
- 功能为主导，项目主体保持不变
- 目录命名统一 `Virtual_` 前缀

# Virtual 全栈改造设计文档

> 日期：2026-09-05
> 状态：已实施
> 目标：Flutter App + Dart Frog 后端 + React Web 官网 + PostgreSQL（降级到内存）

## 1. 背景与目标

App 所有"非模型"外部服务（元数据、遥测等）原本依赖外部云服务。
本次改造将其统一收编到自建本地后端，同时新建 React 官网（角色卡展示 + 应用介绍 + 下载）。

核心约束：
- 后端 API 的**端口与 JSON 格式与 App 现有调用一致**，App 仅改 baseUrl，解析逻辑零改动
- 模型调用（LLM 聊天）保持 App 直连厂商，不经过后端
- 最小版本实现，先能运行再逐步完善
- App 保持本地优先存储，不上云

## 2. 技术栈

| 端 | 技术 |
|---|---|
| App | Flutter 3.47 + Dart 3.13 + Provider + GoRouter |
| 后端 | Dart Frog 1.2 + postgres 3.5（降级到内存），端口 8080 |
| Web | Vite + React 18 + React Router，端口 5173 |
| 数据库 | PostgreSQL 可选（未安装时走内存） |

## 3. 目录结构（monorepo）

```
d:\Documents\Desktop\Virtual\
├── Virtual_app/           # Flutter App（聊天本体）
├── Virtual_background/    # Dart Frog 后端（端口 8080）
├── Virtual_web/           # React 官网（端口 5173）
└── docs/
    └── specs/
        └── 2026-09-05-virtual-fullstack-design.md
```

## 4. Virtual_background（Dart Frog 后端）

```
Virtual_background/
├── bin/server.dart              # 入口（dart_frog dev 自动生成）
├── lib/
│   ├── config.dart              # 端口、DB 连接参数
│   ├── database/
│   │   ├── db.dart              # PostgreSQL 连接池（降级策略）
│   │   └── seed.dart            # 种子数据（metadata + characters + appInfo）
│   └── services/（业务逻辑）
├── routes/api/
│   ├── health.dart              # GET /api/health
│   ├── metadata.dart            # GET /api/metadata（顶级数组，契约对齐）
│   ├── characters/index.dart    # GET /api/characters
│   ├── characters/[id].dart     # GET /api/characters/:id
│   └── app-info.dart            # GET /api/app-info
└── pubspec.yaml
```

### 降级策略

PostgreSQL 连接失败时（未安装），所有端点自动回退到 `SeedData` 内存数据，保证开发体验。

## 5. API 契约（与 App 现有调用一致）

| 端点 | 用途 | 响应格式 |
|---|---|---|
| `GET /api/health` | 健康检查 | `{"status":"ok","service":"Virtual_background"}` |
| `GET /api/metadata` | App 元数据 | **顶级 JSON 数组** `[{desc, id, name, obj, tag}, ...]` |
| `GET /api/characters` | Web 角色卡列表 | `[{id, name, description, avatarUrl, tags}]` |
| `GET /api/characters/:id` | Web 角色卡详情 | 完整角色卡对象 |
| `GET /api/app-info` | Web 介绍/下载 | `{name, version, description, features, downloadUrl}` |

### 元数据格式关键约束

App 端 `MetadataService._fetchRemote()` 用 `AppMetadata.fromJsonList(data)` 解析，
**data 必须是顶级 List**，每项含 `desc/id/name/obj/tag` 字段。
后端直接返回种子数据，不做二次包装。

## 6. PostgreSQL 设计（可选）

| 表 | 字段 |
|---|---|
| `characters` | id, name, description, avatar_url, tags(jsonb), greeting, first_message, persona |
| `app_info` | id, name, version, description, features(jsonb), download_url |
| `metadata` | id, payload(jsonb) |

未安装 PostgreSQL 时后端自动降级到内存，不影响开发。

## 7. Virtual_app 改动清单

| 文件 | 改动 |
|---|---|
| `lib/providers/settings_provider.dart` | 新增 `backendBaseUrl` 字段 + `setBackendBaseUrl()` 方法，默认 `http://localhost:8080`，存 prefs key `backend_base_url` |
| `lib/services/metadata_service.dart` | 构造函数接受 `SharedPreferences`，从 prefs 读取 `backend_base_url` 作为请求 baseUrl；`_fetchRemote()` 改用动态 baseUrl |
| `lib/main.dart` | MetadataService 实例化时传入 `prefs: prefs` |
| `lib/views/settings/settings_page.dart` | 顶部新增"后端地址"设置组，点击弹出输入框（重置/取消/保存） |

## 8. Virtual_web（React 官网）

- 首页（`/`）：App 介绍 + 特性卡片 + 下载按钮 + 后端健康状态
- 角色卡页（`/characters`）：网格展示 + 点击弹窗看详情
- 紫色渐变深色调，对齐品牌视觉
- Vite dev server 配置 `/api` 代理到 `http://localhost:8080`

## 9. 启动方式

```bash
# 后端（先启动，因为 App 和 Web 都依赖它）
cd Virtual_background
dart pub get
dart_frog dev --port 8080
# 运行在 http://localhost:8080

# Web
cd Virtual_web
npm install
npm run dev
# 运行在 http://localhost:5173

# App
cd Virtual_app
flutter pub get
flutter run
# 设置页 → 后端地址 → 默认 http://localhost:8080
```

## 10. 明确不做

- 不引入账号体系、App 数据不上云
- 不代理 LLM 模型调用（保持直连厂商）
- TTS/ASR/图片生成/联网搜索暂不代理（下一阶段）
- Web 只读展示，不做角色卡管理页

## 11. 已知限制

| 项目 | 说明 |
|---|---|
| dart_frog dev 终端警告 | Windows 下 StdinException 可忽略，HTTP 服务正常 |
| Web metadata 响应 | PowerShell 客户端会把数组包装成 `{"value":[...]}`，浏览器 fetch 直接得到顶级数组，App 端同理 |
| PostgreSQL 未安装 | 自动走内存降级，生产部署时需配置 |
| Mobile App 访问 | 真机调试需把设置页后端地址改为 `http://<电脑IP>:8080`（如 `http://192.168.1.145:8080`） |

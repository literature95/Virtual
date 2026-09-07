# Virtual

Virtual 是一个基于 Flutter 的 AI 角色聊天客户端 + Dart Frog 本地后端 + React 官网，支持本地优先、角色扮演、跨模型接入。

## 项目结构

```
d:\Documents\Desktop\Virtual\
├── Virtual_app/           # Flutter App（聊天本体，移动端）
├── Virtual_background/    # Dart Frog 后端（本地 API，端口 8080）
├── Virtual_web/           # React 官网（角色卡展示 + 应用介绍）
└── docs/superpowers/specs/
    └── 2026-09-05-virtual-fullstack-design.md  # 详细设计文档
```

## 架构

```
┌─────────────────┐         ┌────────────────────┐        ┌────────────┐
│ Virtual_web      │────────▶│                    │───────▶│ PostgreSQL │
│ React 官网       │  5173   │ Virtual_background │        │ (可选)     │
└─────────────────┘         │   Dart Frog :8080  │        └────────────┘
┌─────────────────┐         │                    │
│ Virtual_app      │────────▶│  /api/metadata     │        ┌────────────┐
│ Flutter 移动端   │ 设置页配 │  /api/characters   │───────▶│ LLM 厂商   │
│                  │后端地址   │  /api/app-info     │        │ (直连)     │
└─────────────────┘         └────────────────────┘        └────────────┘
```

核心原则：
- **除模型调用外**，App 所有外部服务都走 Virtual_background 本地后端
- **模型调用**保持 App 直连厂商 API（OpenAI/Anthropic/Gemini 等）
- **PostgreSQL 可选**：未安装时后端自动降级到内存种子数据

## 快速启动

### 1. 启动后端（先启动，App 和 Web 都依赖它）

```bash
cd Virtual_background
dart pub get
dart_frog dev --port 8080
# ✅ http://localhost:8080
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

## API 接口

| 端点 | 用途 | 响应 |
|---|---|---|
| `GET /api/health` | 健康检查 | `{"status":"ok"}` |
| `GET /api/metadata` | App 元数据 | 顶级 JSON 数组 `[{desc,id,name,obj,tag},...]` |
| `GET /api/characters` | 角色卡列表 | 精简字段数组 |
| `GET /api/characters/:id` | 角色卡详情 | 完整角色卡 |
| `GET /api/app-info` | 应用介绍/下载 | `{name,version,description,features,downloadUrl}` |

## 技术栈

| 端 | 版本 |
|---|---|
| Flutter | 3.47.1 / Dart 3.13.1 |
| Dart Frog | 1.2.14（shelf） |
| React | 18 + Vite 8 |
| PostgreSQL | 3.x（可选，未安装自动降级） |
| Provider | 状态管理 |
| GoRouter | Flutter 路由 |
| SharedPreferences | 本地存储 |
| postgres | Dart PostgreSQL 驱动 |

## 开发约束

- 后端 API **端口与 JSON 格式与 App 现有调用保持一致**，App 解析逻辑零改动
- 先能运行再逐步完善（用户规则）
- 文档时时同步（用户规则）
- 功能为主导，项目主体保持不变（用户规则）

## Virtual_web 设计语言（学习自 Tavo 官网）

> 设计参考资源：`Tavo_files/`（官网另存资源：首页 CSS、logo SVG、主视觉 PNG）

| 元素 | 实现 |
|---|---|
| 背景 | 近黑深空 `#0e0e0e` + 双层星点闪烁（CSS radial-gradient 星空）+ 品牌三色星云光斑 |
| 品牌色 | Tavo 签名渐变：`#7E4DF1` 紫 → `#E3756E` 珊瑚红 → `#E58029` 橙（取自官方 logo SVG） |
| 标志 | 对话气泡 mark（呼应 Tavo mark 形制）+ 楷体渐变 "Virtual" 字 |
| 字体 | display 用楷体（Kaiti，呼应 Tavo 手写 logo 温度）/ 正文系统无衬线 / 标签 mono |
| Hero | 左文右机不对称布局 + 漂浮玻璃胶囊（多模型/角色卡/本地优先/流式）+ CSS 手机 mockup（模拟沉浸式聊天：场景标签 + 玻璃气泡） |
| 动效 | 页面加载 staggered reveal、星空 twinkle、胶囊漂浮、气泡弹出、hover 渐变描边 |
| 角色卡 | 沉浸式图片卡 474×300（1.58:1）：左侧 AI 生成的角色立绘，向右虚化渐隐，文字（楷体名/描述/标签）叠加图上，右上 VIEW 胶囊；照片 URL 由后端种子数据下发 |
| 详情弹窗 | 深色玻璃 sheet + `// INTRO` 风格 mono 小节标题 + 渐变引用块 |

## Virtual_app 导航结构（2026-09-05 重构）

5 Tab 主导航（窄屏底部 NavigationBar / 宽屏 NavigationRail）：

| Tab | 路由 | 内容 | AppBar 右上角 |
|---|---|---|---|
| 首页 | `/home` | **在线角色卡广场**：后端 `/api/characters` 拉取 + 分类过滤 chips + 搜索 | 🔍 搜索 |
| 发现 | `/discover` | 扩展内容聚合：世界书 / 预设 / 正则 / 插件 / 主题 / 调试 | 无 |
| 对话 | `/chat` | 会话列表（原有） | 无 |
| 角色 | `/characters` | 本地角色管理（原有） | ➕ 新建角色 |
| 我的 | `/profile` | 头像/昵称/ID 区块 + 我的角色卡计数 + 我的 API / 主题外观 / 插件 + 更多 | 无 |

- 左上角 ☰ 抽屉：复用「我的」导航（用户区块 + 一级 Tab + API接入/更多 + 扩展项），深空配色
- "+" 图标仅在 `/characters`（新建角色）与 `/endpoints`（新增端点）显示，其余页面隐藏
- 子页面（编辑/详情/设置等）AppBar 显示返回键；`/chat/:id` 聊天详情也返回键

### App 深空设计语言（与 Web 端统一）

| 元素 | 实现 |
|---|---|
| 主题 token | [tavo_brand.dart](Virtual_app/lib/theme/tavo_brand.dart) 新增 `violet/coral/amber/cosmosBg/cosmosElev/cosmosText*` + `signGradient`（紫→珊瑚→橙）+ `glassCapsule` |
| 星空背景 | [cosmos_background.dart](Virtual_app/lib/views/common/cosmos_background.dart)：`CosmosBackground` 组件（双 seed 随机星点 CustomPainter + 三色星云 RadialGradient），包裹 HomeShell 内容区 |
| 沉浸角色卡 | [character_photo_card.dart](Virtual_app/lib/views/common/character_photo_card.dart)：`CharacterPhotoCard`（1.58:1，照片左置 + ShaderMask 向右虚化 + 文字叠加），首页在线卡使用 |
| 在线角色服务 | [online_character_service.dart](Virtual_app/lib/services/online_character_service.dart)：Dio GET `{backendBaseUrl}/api/characters`（backendBaseUrl 来自设置页，失败显示错误 + 重新加载） |
| 品牌头像 | 对话气泡形渐变 "V"（AppBar 侧栏 / 抽屉 / 我的页统一复用） |

## 目录命名约定

所有子项目统一 `Virtual_` 前缀：
- `Virtual_app/` — Flutter App
- `Virtual_background/` — Dart Frog 后端
- `Virtual_web/` — React 官网

## 故障排查

| 问题 | 解决 |
|---|---|
| 后端启动报错 `StdinException` | Windows 终端不影响 HTTP 服务，看 "Running on http://localhost:8080" 即可 |
| 后端连接 PostgreSQL 失败 | 正常降级到内存数据，控制台会显示 "degraded to memory" |
| App 元数据加载失败 | 自动回退 `assets/metadata_default.json`，无网也能跑 |
| Web `npm run dev` 启动但 API 404 | 确认后端 8080 端口已启动 |
| 真机 App 连不上后端 | 改设置页后端地址为 `http://<电脑局域网IP>:8080` |

## 下一步

- [ ] TTS/ASR/图片生成/联网搜索 代理到后端（下一阶段 B）
- [ ] PostgreSQL 生产部署（Docker Compose）
- [ ] Web 角色卡管理后台
- [ ] CI/CD + Release 签名流程

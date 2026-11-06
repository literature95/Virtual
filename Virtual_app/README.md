# Virtual

Virtual 是一个基于 Flutter 的 AI 角色聊天客户端，定位为“本地优先、角色扮演、跨模型接入”的应用。

它目前的代码结构已经具备完整的客户端闭环：角色管理、聊天历史、模型端点配置、主题设置、插件/世界书/预设/正则规则等模块均在项目中实现。

## 当前状态（2026-11-06）

| 项 | 值 |
|---|---|
| 版本 | **1.0.30+31**（`pubspec.yaml`） |
| 路由 | **43 条**（ShellRoute 内 10 条 + 根路由 33 条） |
| 测试 | **35 个测试文件 / 296 例**（**296 通过 / 0 失败**，`flutter test -j 1` 全绿） |
| 构建产物 | 1.0.30+31 本地构建 `app-release.apk` **108,036,733 B**（约 103MB），`--target-platform android-arm64`（`libapp.so`/`libflutter.so` 仅 arm64-v8a，插件原生库另带 armeabi-v7a/x86_64 目录）；1.0.27+28 线上包 108,003,841 B |
| 本地模型 | **已恢复**（`AppFeatureFlags.localDeployEnabled = true`）；**不打包任何模型**，GGUF 由用户自行导入，APK 内 `.gguf` = 0 |
| 端点类型 | **接入 + 部署并存**：接入型（OpenAI 兼容 / Anthropic / Gemini）、部署型（本机 nobodywho + 用户自备 GGUF） |

## 项目概览

Virtual 不是一个单纯的聊天 Demo，而是一个偏 AI 客户端的应用框架，核心能力包括：

- AI 角色聊天
- 多角色卡管理
- 会话与消息持久化
- 多 LLM 接入端点配置
- 角色设定、世界书、预设、正则规则等扩展能力
- TTS / ASR / Web Search / Image Generation 等功能入口
- 本地设置、备份和调试能力

## 技术栈

- Flutter
- Dart
- Provider（状态管理）
- GoRouter（路由）
- SharedPreferences + JSON（本地存储）
- Dio / Http（网络请求）
- multi-model adapters：OpenAI / Anthropic / Gemini
- Flutter UI 组件：Material, Lottie, Markdown, Image Picker, WebView 等

## 代码结构

```text
lib/
  main.dart                    # 应用入口
  data/
    app_database.dart          # 本地数据存储与 CRUD
  models/                      # 数据模型
  providers/                   # 状态管理（6 个 ChangeNotifier）
    auth_provider.dart
    settings_provider.dart
    metadata_provider.dart
    endpoint_provider.dart
    character_provider.dart
    chat_provider.dart
  route/
    app_router.dart            # 路由配置（43 条）
  config/
    app_feature_flags.dart     # 功能开关（localDeployEnabled = true）
  services/
    api_service.dart
    app_image_cache.dart       # 图片统一缓存/降采样
    retry_policy.dart          # 上游限流重试
    conversation_request_lock.dart # 对话串行锁
    plot_option_parser.dart    # 剧情选项解析
    backend_config.dart
    model_registry_service.dart
    metadata_service.dart
    prompt_service.dart
    adapters/
      openai_adapter.dart
      anthropic_adapter.dart
      gemini_adapter.dart
  theme/
    app_theme.dart
    tavo_brand.dart
  utils/
    constants.dart
    random_order.dart          # 发现页下拉刷新随机
    multi_select.dart          # 角色页批量多选
  views/
    common/                    # cached_app_image（统一图片组件 + 预加载器）
    onboarding/
    chat/
    character/
    endpoint/
    lorebook/
    regex/
    preset/
    settings/
    theme/
    plugin/
    more/
    debug/
```

## 关键业务模块

### 1. App 启动与全局状态

入口位于 [lib/main.dart](lib/main.dart)。

启动流程包括：

- 初始化 Flutter 绑定
- 初始化 Sentry
- 获取 SharedPreferences
- 初始化本地数据库
- 强制竖屏
- 注册全局 Provider
- 判断是否完成 onboarding
  - 未完成：显示引导页
  - 完成：进入主路由

### 2. 路由

路由定义在 [lib/route/app_router.dart](lib/route/app_router.dart)。

当前路由分为两类：

**一级 Tab / 保留底部导航的页面（`ShellRoute` 内）**

- `/home`、`/home/character/:id`（角色卡详情，保留底部导航）、`/home/category/:name`、`/home/search`、`/home/tags`
- `/discover`、`/profile`、`/characters`
- `/chat`、`/chat/:id`

**全屏根路由（不经过 Shell）**

- `/login`、`/register`（登录 / 注册）
- `/user/:id`（用户主页）、`/post/:id`（帖子详情）、`/compose`（发布动态）

**二级页面（根 Navigator 独立路由，无底部导航栏）**

- `/profile/edit`、`/profile/password`
- `/endpoints`、`/endpoint/new`、`/endpoint/:id/edit`
- `/lorebooks`、`/lorebook/:id/edit`
- `/regex`、`/regex/new`、`/regex/:id/edit`
- `/presets`、`/preset/new`、`/preset/:id/edit`
- `/theme`
- `/settings`、`/settings/backup`、`/settings/tts`、`/settings/asr`、`/settings/web-search`、`/settings/image-gen`
- `/plugins`、`/more`、`/debug`
- `/character/manage`、`/character/new`、`/character/:id/edit`
- `/chat/info/:characterId`、`/chat/background/:conversationId`

#### 2.1 导航与 AppBar 规范（2026-11-04）

此前二级页面（插件 / Lorebook / 正则 / 设置…）注册在 `ShellRoute` 内，进入后底部导航栏仍可见；
且 shell 自身 AppBar 与页面 AppBar 叠加，出现「返回箭头一行、标题另一行」的双层栏，
系统返回键还会直接从 App 退出。现已统一为：

| 约定 | 实现 | 说明 |
| --- | --- | --- |
| 二级页面用根路由 | `lib/route/app_router.dart` | 二级 `GoRoute` 注册在 `ShellRoute` **之外**，页面构建为根 Navigator 的全屏页，不经过 `HomeShell`，因此不会渲染底部导航栏；不使用嵌套 Navigator |
| 入口用 `push` 而非 `go` | `profile_page` / `more_page` / `endpoint_list_page` / `chat_list_page` / 首页分类入口 / 首页顶栏（搜索框、分类按钮） | `go` 会替换当前 location、丢失返回栈，导致系统返回键直接退出 App；`push` 才能「返回上一级」。壳内的 `/home/category/:name`、`/home/search` 与 `/home/tags` 虽然保留底部导航，也必须用 `push` 进入 |
| 返回键唯一规则 | 全部页面 | 界面**有返回箭头** → 系统返回键必须回上一级（不退出 App）；**无箭头的根页面**（首页/Tab）→ 系统返回键退出 App；不允许「有箭头但 pop 不了」或「根页面误画箭头」 |
| 统一 AppBar | 各二级页面 | 标准 `AppBar`：`leading` 返回箭头 + `centerTitle: true` 居中标题 + `actions` 同一行。push 进入的页面由 `AppBar` 自动补返回箭头；设置 / 接口 / 更多等入口页使用显式 `BackButton` 并带 `fallbackLocation` 回落 |
| 返回行为 | `AppBar` 自动 leading + 显式 `BackButton` | 二级页面 → 回上一级；只有根页面（Tab / 首页）才允许退出 App |
| 设置页返回 | `settings_page.dart` | 显式 `BackButton`，点击与系统返回都回到「我的」(`/profile`) |

> 全项目已无 `PopScope` / `WillPopScope` 拦截逻辑（grep 为空），系统返回键由 Navigator 栈自然处理。
> 沉浸式页面（对话、角色卡详情）继续使用 `InsetAppBar`（自绘状态栏内边距）；
> `chat_background_page` / `chat_character_info_page` 已显式补齐 `leading` 返回键。

### 3. 本地数据库

[lib/data/app_database.dart](lib/data/app_database.dart) 是本项目的核心数据存储层，采用 SharedPreferences + JSON 保存数据，支持：

- characters
- conversations
- messages
- endpoints
- lorebooks
- presets
- regex rules
- themes
- personas
- plugins

这种设计的特点是：

- 启动简单，不依赖复杂本地数据库依赖
- 适合轻量桌面/移动端应用
- 易于扩展成更重的持久化方案

### 4. 聊天能力

[lib/providers/chat_provider.dart](lib/providers/chat_provider.dart) 是聊天逻辑核心，负责：

- 加载对话列表
- 创建/删除/置顶对话
- 加载消息
- 自动插入角色首条欢迎消息
- 发送消息
- 自动选择当前 endpoint 和 model
- 调用 API 生成回复
- 处理中断、流式输出、错误状态

#### 4.1 上游限流与重试（2026-11-04）

免费模型档常见限制是**同账号并发 1**，旧实现 1s/2s/2s 的密集重试等于连续撞同一限流窗口
（现象：`Too many requests for this free model` → 「自动重试 3 次后仍未成功」）。
现在由 `lib/services/retry_policy.dart` 统一决策，`chat_provider.dart` 的
`_consumeWithRetry` 执行；三个云端适配器把 `DioException` 转成带状态码 /
`Retry-After` 的 `LlmRequestException`（`lib/services/adapters/*_adapter.dart`）。

| 可重试（最多尝试 4 次 = 首次 + 3 次重试） | 不重试（直接报错） |
| --- | --- |
| HTTP **429**（含 `Too many requests` / `rate limit` / `concurrency` 文本） | 400 / 401 / 403 / 404 / 422 等其余 4xx |
| HTTP **500 / 502 / 503 / 504** | 其余 5xx（如 501） |
| 连接 / 发送 / 接收超时 | 用户主动停止 |
| 网络中断、DNS、连接被重置 | 流式已收到首 token（改报「生成中断」，避免半截文本重复拼接） |

退避表（第 N 次重试的等待，叠 **±20% 抖动** 避免多设备同步撞车）：

| 尝试 | 等待 |
| --- | --- |
| 第 1 次失败后 | 2s ± 20% |
| 第 2 次失败后 | 6s ± 20% |
| 第 3 次失败后 | 15s ± 20% |
| 第 4 次失败 | 不再重试，错误上屏 |

- **`Retry-After` 优先**：响应头存在时直接采用（上限 30s），覆盖上表退避；只支持秒数形式，HTTP-date 回落退避。
- **并发规则**：`lib/services/conversation_request_lock.dart` 按**对话 id** 串行——
  同一对话同时只允许一个进行中的请求（快速连点第二次会被拦截并提示「上一条还在生成」，
  选择**提示而不排队**：排队会让用户以为消息丢了，且长等待后突然连出两条回复）；
  锁在 `sendMessage` / `regenerateMessage` 的 `finally` 释放，成功 / 失败 / 取消都不泄漏。
  不同对话使用不同 key，不存在全局并发上限（当前 Provider 只持有一个活动对话，实际仍是串行）。
- **日志前缀 `[Retry]`**：`endpoint=<端点名> attempt=<n>/4 status=<状态码|-> wait=<秒>s retryAfter=<hit|miss> reason=<...> raw=<原始错误>`；
  放弃、生成中断、用户停止也各有一条，原始错误始终保留。
- **最终提示**：重试耗尽后仍限流时，在原有文案后追加「已等待约 X 秒仍限流，建议换模型或稍后再试」
  （仅最终失败出现）。采样参数被 400 拒绝的「钳制后重试」是独立机制，单独计数，不占用上述 4 次尝试。

#### 4.2 剧情选项与继续生成（2026-11-04）

聊天页最后一条 AI 回复下方、输入区上方新增「生成选项 / 换一批 / 继续」。

- **触发方式**：按钮显式触发，不自动请求（省 API 额度）。生成中显示 loading 并禁用，
  与聊天请求共用同一对话锁与 `[Retry]` 策略（免费档并发 1，两者不能并行）。
- **选项请求**：独立的一次非流式轻量请求，**不写数据库、不进对话历史**；
  只带 `ContextWindowService.trim` 后的最近若干轮（1200 token 预算），
  system 为极简「剧情助手」指令（不复用角色卡/世界书），`temperature=0.8`、`maxTokens=200`、关闭流式与推理。
  输出约定严格 JSON：

  ```json
  {"options":["我要拔剑","我要后退","我要谈判"]}
  ```

  每条 ≤ 20 字、第一人称「我要……」。解析在 `lib/services/plot_option_parser.dart`，
  按 **严格 JSON → 按行/编号 → 单行编号切分** 三级降级，清洗引号/项目符号，
  最多 3 条并去重；全部失败（含模型拒答）显示「没生成出来，再试一次」。
- **缓存与交互**：选项按 **AI 消息 id** 缓存在 `ChatProvider`（切页面回来仍在），
  「换一批」显式重新请求；点击某条 = 以普通用户消息走 `sendMessage` 全链路发送，
  发送成功后清空该消息的选项缓存。
- **继续生成**：仅当最后一条是**已完成 AI 回复**且无进行中请求时显示。
  点击写入隐藏用户消息 `（继续上文，不要重复已写内容）`（`isHidden = true`），
  走 `sendMessage(hidden: true)`，含重试与并发锁；失败提示与普通发送一致。
- **隐藏消息约定**：`ChatMessage.isHidden` 默认 `false`，旧数据兼容；
  隐藏的含义是**只隐藏界面渲染**，仍写入数据库并进入 Prompt 上下文（历史与后续轮次都可见）。
  聊天列表/可见消息数使用 `ChatProvider.visibleMessages` 过滤；导出 Markdown 时标注
  `> [隐藏消息，不显示于聊天]`，便于调试。
- **额度影响**：每次「生成选项 / 换一批」= 1 次额外请求（约 ≤200 输出 token）；
  点选与「继续」复用正常发送链路。限流时沿用「4.1」的退避与提示，不会额外放大并发。

### 5. 模型与端点管理

端点和模型配置位于：

- [lib/providers/endpoint_provider.dart](lib/providers/endpoint_provider.dart)
- [lib/services/model_registry_service.dart](lib/services/model_registry_service.dart)
- [lib/services/adapters](lib/services/adapters)

项目支持多家模型接入，当前实现中已具备 OpenAI / Anthropic / Gemini 适配器结构，说明应用设计目标是“多模型切换”，不是单一厂商绑定。

#### 5.1 本地部署已恢复（2026-11-06，1.0.30+31）

「云端接入」与「本地部署」两型端点并存；**App 不打包任何模型**，GGUF 由用户自行导入。

| 项 | 状态 | 说明 |
| --- | --- | --- |
| 功能开关 | 开启 | `lib/config/app_feature_flags.dart` → `AppFeatureFlags.localDeployEnabled = true`；关闭即可整体隐藏部署入口 |
| 新建/编辑端点 | 接入 / 部署可切换 | 部署型隐藏 baseUrl / apiKey / 平台 / 连接测试，显示本地模型文件、提示词模式与推理参数（contextSize / maxTokens / temperature / GPU 层数 / 线程数 / 重复惩罚） |
| 已存在的部署型端点 | 可推理 | `chat_provider.dart` 的「本地部署已停用」守卫已移除，`sendMessage` / `regenerate` 正常走 nobodywho |
| 模型来源 | **用户自备** | 端点页「选择模型文件」→ `file_picker`（SAF，无需存储权限）→ 校验 GGUF 头 → 流式复制到 `getExternalFilesDir(null)/models/` → 回填绝对路径；也可手填路径（adb 已推送的文件） |
| 模型管理 | 最小闭环 | 显示「是否存在 + 字节数」；「更换」重新选择；「删除」二次确认且只删 App 模型目录内文件，外部路径只提示不代删 |
| 打包体积 | 不含模型 | APK 内 `*.gguf` = 0；nobodywho 原生库仍在，1.0.30+31 为 **108,036,733 B（约 103MB）** |

> 云端角色卡路径保持不变：完整角色卡 + 世界书 + `PromptService.assembleSystem` 两遍拼装 + `ContextWindowService.trim`。

##### 5.1.1 GGUF 导入流程

1. 入口：端点编辑页「本地模型」区 → 「选择模型文件 / 更换模型」；
2. 选择器：`FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gguf'], withData: false)`，
   走 Android SAF（`ACTION_GET_CONTENT`），**不申请全盘存储权限**；
3. 校验：读取前 8 字节，magic 必须为 `GGUF`，版本号需在 **1–3**（拒绝空文件、截断文件、改名的 PNG/ZIP）；
4. 复制：`source.openRead()` 流式写入 `<name>.gguf.partial`，每块回调进度（1% 粒度），完成后 `rename`；
   同名同大小直接跳过（幂等），失败/取消删除 `.partial`；
5. 回填：成功或跳过后把绝对路径写入端点 `localModelPath`，状态行立即刷新（文件名 + 体积 + 「App 目录 / 外部路径」）；
6. 失败可读化：文件头非法、选择器读取失败、空间不足（`ENOSPC` / Windows 112）、写入失败分别给中文提示；
   取消导入不报错；Web 端明确提示「不支持本地模型导入」。

##### 5.1.2 两档提示词模式（部署端点）

| 模式 | 组装内容 | 适用 |
| --- | --- | --- |
| **精简（默认）** | 压缩角色卡（≤300 token）+ 最近 4 轮 + 本轮指令 | ≤2B 小模型；避免塞满上下文后答非所问 |
| **完整** | 完整角色卡 + 世界书 + 预设 + 正常历史裁剪（复用云端 `PromptService`，按端点 `contextSize` 裁剪） | ≥3B、上下文窗口足够的模型 |

- 默认精简：多数用户导入 1–2B 小模型；大模型由用户在端点里显式切换；
- 精简模式保证**用户最新输入完整保留**（本轮内容不参与裁剪，只追加指令），system 与历史是独立段落；
- 增量上下文（`ask` + 75% 阈值裁剪）与错误可读化沿用原实现，未回退。

### 6. 角色与详细配置

角色、人物卡、世界书、预设和规则等均有对应视图和模型：

- [lib/models/character.dart](lib/models/character.dart)
- [lib/models/lorebook.dart](lib/models/lorebook.dart)
- [lib/models/preset.dart](lib/models/preset.dart)
- [lib/models/regex_rule.dart](lib/models/regex_rule.dart)
- [lib/views/character](lib/views/character)
- [lib/views/lorebook](lib/views/lorebook)
- [lib/views/preset](lib/views/preset)
- [lib/views/regex](lib/views/regex)

这些模块构成“角色扮演应用”的核心配置层。

### 7. 首页与在线角色卡导入

首页（`lib/views/home/home_page.dart`）是后端角色卡广场，点击卡片即「一键导入 + 进入对话」。
这条链路上有三个**不能破**的约定：

| 约定 | 实现位置 | 破了会怎样 |
| --- | --- | --- |
| 走详情接口建卡 | `_ensureLocalCharacter` | 列表接口省略 `exampleMessages` / `personality`，会导入出「只有名字和头像」的空壳角色 |
| 按 `sourceId` 查重 | `Character.sourceId` ← `extensions['sourceId']` | 本地 id 是 `createCharacter` 现生成的 uuid，后端 ID 若不留存就无从查重，同一张卡点 N 次堆 N 个副本 |
| 已导入则续聊 | `ChatProvider.latestConversationOf` | 每次都新建会话，重复点击会攒出一串空对话 |

导入完成后直接 `context.go('/chat/:id')`，不停留在首页。

> `AppDatabase` 是单例且持有首次 `init()` 时的 prefs 实例，
> 测试中 `SharedPreferences.setMockInitialValues` 清不掉它的数据，
> 需显式删除，否则用例互相污染。

### 7.1 首页板块顺序与轮播位

首页是 `CustomScrollView` 的 sliver 序列，从上到下：

| 顺序 | 板块 | 实现 | 备注 |
| --- | --- | --- | --- |
| 1 | AppBar 顶栏：左侧圆角搜索框 + 右侧「分类」按钮 | `_homeTopBar`（`home_shell.dart`） | 搜索框 → `push('/home/search')`；分类 → `push('/home/tags')`（标签筛选页）。原 ☰ 抽屉与 "Virtual" 字标已删除，原抽屉入口改由「我的」页可达 |
| 2 | 轮播图（横版，比例 1.58） | `views/home/banner_carousel.dart` | 数据在备案时才占位，**拉不到就不渲染**，不留空白 |
| 3 | 分类 chips（高 44，横向滚动，选中走渐变） | `_categoryChip` | 分类来自所有角色的 `tags` 并集 |
| 4 | 竖版封面卡网格（比例 0.62，2~3 列） | `views/common/character_cover_card.dart` | 其余为空 / 加载中 / 错误态占满剩余空间 |
| 5 | 分类区块「更多 >」按钮 | `context.push('/home/category/:name')` | 跳转到搜索筛选页，预选中该分类 tag |

轮播的两个约束：

- **必须配横版图**。后端 `BannerSeed` 直接复用 16:9 立绘原图；
  这批素材放进 0.62 竖卡会被 `cover` 裁掉大半，放进横幅才是原生比例。
- **降级要彻底**。`BannerService.fetchBanners` 吞掉所有异常返回空列表，
  `_loadBanners` 也不 await —— 后端没起或还没这个端点时，首页只是没有轮播，
  角色列表照常加载。

点击轮播走 `_openBanner`：先在当前列表里按 `characterId` 找，找不到再单独拉一次详情
（运营位可能指向列表未返回的角色），最后复用封面卡同一条导入闭环。

## 运行方式

安装依赖：

```bash
flutter pub get
```

启动应用：

```bash
flutter run
```

如果需要运行测试：

```bash
flutter test
```

### Web（Chrome）运行与已知坑

```bash
flutter run -d chrome --web-port 5000
```

- **图标字体**：`pubspec.yaml` 手动声明 `family: MaterialIcons` 指向
  `fonts/materialicons-regular.otf`（**必须是完整字体，约 1.6MB**）。
  曾误用一个 7.5KB 的残缺占位字体（只有 menu 等个别字形），导致搜索、
  底部导航等绝大多数图标在 Web/原生端渲染为空白——替换为完整字体后正常。
  `uses-material-design: true` 同时存在时 FontManifest 会有两条
  MaterialIcons 记录（大小写路径在 Windows 指向同一文件），无害。
  **更换字体文件后要重启 dev server（必要时 `flutter clean`）**，
  FontManifest 与 build 缓存不会自动刷新。
- **头像渲染**：`avatarPath` 有三种形态——在线卡 `http(s)` 外链、data URL、
  本地文件路径。统一走 `resolveAvatarImage()`（见
  `lib/views/common/character_cover_card.dart`）分发；Web 上对 URL 使用
  `FileImage(File(...))` 会抛 `Unsupported operation: _Namespace`。
- **主题色规范**：文字/图标颜色一律取 `colorScheme.onSurface` 等主题令牌，
  禁止硬编码 `Colors.white`/`Colors.black`（浅色主题白底白字、深色主题黑底
  黑字都不可见）。深底图片上的白色压字除外。
- debug 模式 `Could not find Noto fonts` 警告无害（个别 emoji 显示为方块）。

## 构建说明

项目在 [pubspec.yaml](pubspec.yaml) 中定义了应用名为 `virtual`，并声明了 Flutter 3.19+ / Dart SDK 3.3+ 的最低要求。

Android / Web 入口已更新为 Virtual 相关名称；包名、签名、远程地址等仍可能存在历史命名，这些通常属于发布/包管理层面的兼容性配置。

## 设计特点

1. 轻量本地优先
   - 本地 JSON 持久化，便于快速启动和调试。

2. 模块可扩展
   - API、角色、世界书、插件、设置都按独立模块拆分。

3. 面向 AI 角色扮演
   - 从会话、角色设定、模型端点到扩展规则，均围绕 AI 角色体验设计。

4. 适合继续演进
   - 当前结构已经具备中型客户端的基础骨架，后续可继续扩展云同步、更稳定数据库、测试覆盖和发布流程。

## 注意事项

- 当前本地数据存储采用 SharedPreferences + JSON，适合中小规模场景，不适合超大规模数据查询。
- 项目包含较多功能入口，适合功能型 AI 客户端方案，但维护时需要注意模块边界和测试覆盖。
- 如果需要生产级交付，建议后续再补充：
  - 更稳定持久化层（如 SQLite / Drift / ObjectBox）
  - API 接口统一封装与错误重试
  - 单元测试和 widget 测试
  - CI/CD 与版本发布流程

## 结论

Virtual 是一个具有较完整业务闭环的 Flutter AI 角色聊天应用，代码结构已经相对成熟，适合继续迭代成正式产品。当前 README 与代码的实际状态基本一致，重点是"AI 角色通信 + 多模型接入 + 本地数据管理"的组合能力。

## 发现页社区功能（2026-09-10 起，2026-11-05 已接真实后端）

发现页从工具入口网格改为**社区聚合页**，定位为用户内容发现与社交入口。

### 页面结构

发现页为 `Column(TabBar + Expanded(TabBarView))` 结构（不使用内层 Scaffold，避免与 home_shell 双层 AppBar 冲突），home_shell 在 `/discover` 路由下隐藏 AppBar（`PreferredSize(height: 0)`）。

三个 Tab（`initialIndex = 1`，底栏进入时默认停在「发现」）：

| Tab | 内容 | 数据来源 |
|---|---|---|
| 推荐 | 顶部横向社区分类 + 动态流（`?community=` 过滤） | 后端 `GET /api/posts` |
| 发现 | 竖向角色卡流（一次一卡，上下滑；点卡进在线详情；点赞/转发为本地状态） | 后端 `GET /api/characters` |
| 关注 | 已关注创作者列表 + 关注流 | 后端 `GET /api/follows`、`GET /api/posts?following=true` |

**加载策略（1.0.27+28）**：

- 进入发现页默认停在「发现」Tab，首屏只发 **1 个请求**（`/api/characters`）；
- 推荐 / 关注的 3 个请求在用户**首次切到对应 Tab** 时才懒加载（`_onTabChanged`），只加载一次；
- 角色卡流首批渲染 **12 张**，滑到本批末尾前 2 张时追加 12 张；
- 图片预取 `lookahead = 1`（只预取下一张），并发上限 2；
- **仅下拉刷新**才随机重排并回到第一张；进入与翻页保持后端顺序。

### 帖子类型

| 类型 | 说明 | 组件 |
|---|---|---|
| `characterCard` | 用户发布的角色卡宣传，封面 + 描述 + 标签 + 互动 | `_CharacterPostCard` |
| `conversationShowcase` | 用户炫耀对话片段，气泡式渲染对话行 | `_ConversationShowcaseCard` |
| `announcement` | 官方公告/版本更新，渐变背景 | `_AnnouncementCard` |

### 数据模型

- `lib/models/community_post.dart`：`Creator`、`CommunityPost`、`DialogueLine`、`CommunityTag`（`fromJson` 对接后端）
- 社区数据由 `CommunityApiService` 统一请求，不再使用 Mock 假数据

### 踩坑记录

| 问题 | 原因 | 修复 |
|---|---|---|
| TabBarView 99895px 溢出 | discover_page 内层 Scaffold 与 home_shell 双层 AppBar，TabBarView 高度约束断裂 | 去掉内层 Scaffold，改用 `Column + Expanded` |
| TabAlignment.start 异常 | `tabAlignment: TabAlignment.start` 需要 `isScrollable: true` | 去掉 `tabAlignment` 参数（2 个 tab 不需要滚动） |
| 关注列表 5px 溢出 | 头像 60px + 文字行高超过容器 | 容器高度改为 128px |

## 角色卡详情页（2026-09-10）

首页点击角色卡不再直接进对话，而是先进入**角色卡详情页**浏览信息，再决定是否「开始对话」。

### 交互流程

```
首页/分类页 角色卡 → 点击 → /home/character/:id（详情页）→「开始对话」→ /chat/:id
```

### 详情页结构（`lib/views/home/character_detail_page.dart`）

沉浸式布局，立绘作为视觉主角固定不滚动，立绘上直接叠 CTA「开始对话」。

| 区域 | 实现 | 说明 |
|---|---|---|
| 立绘区 | `SliverToBoxAdapter` + `SizedBox(height: 屏宽×1.25 clamp [420,580])` + `CachedNetworkImage(cover)` + 渐变遮罩 | **不再用 `SliverAppBar`**，避免向上滚动时立绘被压缩成扁条再消失。立绘底部叠：角色名（32号大字+阴影）+ 昵称 + 标签 chips + 「开始对话」渐变按钮 |
| 互动条 | 圆角胶囊容器，左：评分（星+分+评分数），右：点赞/转发 | 点赞可本地 toggle 切换状态，转发给 toast「开发中」。互动数由 characterId hash 生成稳定 mock（后端暂无该字段）。**收藏按钮已于 2026-11-05 移除**（底层 `isFavorite` 字段保留） |
| 创作人区 | 渐变头像（首字母）+ 名字 + ID + 关注按钮 | 关注按钮本地 toggle |
| 详情卡片 | `SliverList.separated`，每段包圆角容器 + 边框 | 描述 / 人设 / 场景 / 创作者备注 / 开场白，标题行带渐变图标方块。**用局部变量做类型提升**（字段访问不会自动提升，写成 `c.personality != null && c.personality.isNotEmpty` 会报 unchecked_use_of_nullable_value） |

「开始对话」按钮（立绘上叠的）执行原有导入闭环：拉详情 → 建本地卡（幂等）→ 建/续会话 → 跳 `/chat/:id`。

> 已移除底部 `bottomNavigationBar`——CTA 已在立绘区，避免重复。

### 路由

```
/home/character/:id  →  CharacterDetailPage(characterId: id)
/home/search         →  CategoryCharactersPage()（无预选分类，从首页顶栏搜索框进入）
/home/tags           →  TagFilterPage()（标签筛选，从首页顶栏「分类」按钮 push 进入）
/home/category/:name →  CategoryCharactersPage(category: name)（预选该分类，从「更多 >」进入）
```

## 搜索筛选页（2026-09-10）

`CategoryCharactersPage` 从「按 tag 简单过滤」重写为**多维度搜索筛选页**。

### 页面结构（`lib/views/home/category_characters_page.dart`）

从上到下：

| 区域 | 实现 | 说明 |
|---|---|---|
| AppBar | 返回按钮 + 搜索输入框（`TextField`）+ 「搜索」渐变按钮 | **搜索框和搜索按钮一体化在 AppBar 行内**（不再单独占下方一行）。输入框 hint 在无预选分类时显示「搜索角色名或描述…」；从「更多 >」进入时显示 `#分类名`。回车提交，「搜索」按钮显式触发；带清除 ×。**home_shell 在 `/home/search`、`/home/tags` 和 `/home/category/:name` 路由下隐藏自己的 AppBar**（`PreferredSize(height:0)`），避免双层 AppBar 叠加，与 `/discover` 同样处理 |
| 标签横向筛选 | `ListView.separated` 横向 chips（高 44） | tags 来自所有角色并集按频次排序取前 12；可多选（AND 关系：必须包含所有选中） |
| 互动数筛选条 | 两个 `_MetricDropdown`：点赞 / 转发 | 每项可选：不限 / 100+ / 500+ / 1k+ / 5k+；下三角箭头。**收藏筛选已于 2026-11-05 移除** |
| 结果网格 | `SliverGrid` 2~3 列竖版封面卡（0.62 比例） | 空结果时显示「清除全部筛选」按钮 |

### 互动数据来源

后端 `/api/characters` 列表不下发互动数，按 `characterId.hashCode` 本地生成稳定 mock：
- 点赞：120 + (hash % 5) × 87（120 ~ 468）
- 转发：18 + (hash % 3) × 14（18 ~ 46）

与详情页互动条同源（同一 hash 公式），后续后端补字段时替换 `_likesOf` / `_sharesOf` 即可。

### 筛选逻辑

关键词匹配（name / description 包含）+ 标签 AND + 两个互动数阈值，全部满足才进入结果。`_filtered` getter 实时计算，任何筛选项变更都 `setState` 触发重建。

### 首页/分类页改动

`_openCharacter` 从 `async` 导入+跳聊天改为 `context.push('/home/character/${Uri.encodeComponent(c.id)}')`，不再直接进对话。导入逻辑移到详情页的 `_startChat`。

### 踩坑

| 问题 | 原因 | 修复 |
|---|---|---|
| `Illegal percent encoding in URI` | `Uri.decodeComponent` 在 `/home/category/:name` 路由收到含非法 `%` 的参数 | try-catch 包裹，失败时退回原始值 |
| 详情页拉取失败时 preview 被遮盖 | `_loadDetail` 失败后无条件设置 `_error`，build 走错误视图分支，列表点进来的 preview 数据被覆盖 | 失败时若 `_character != null`（有 preview）静默保留，仅无任何数据时才进入错误视图 |
| 错误消息暴露底层异常字符串 | `'加载失败：$e'` 直接拼 `Exception: xxx` | 加 `_friendlyError`：按 `SocketException` / `404` / `401`/`403` / 5xx 分类翻译 |
| 详情页立绘区固定 380 高度 | `expandedHeight: 380` 写死，窄屏（320 宽）显得过宽矮、宽屏（500+）显得过窄高，且与竖版立绘原图比例（~0.667~0.75）不符裁切过多 | 改为 `MediaQuery.size.width * 0.85` clamp 到 [300, 460]，4:5 比例折中：保留立绘主体可见，又避免占满首屏 |
| 详情页立绘向上滚动会被压成扁条再消失 | 用 `SliverAppBar` 做立绘区，`expandedHeight` 是「最大」高度，滚动时会从 heroHeight 压到 toolbarHeight（~56dp），用户看下面描述立绘就没了——「立绘在哪里」 | 重构为 `SliverToBoxAdapter + SizedBox(固定高度)`，立绘占满屏宽 × 1.25（clamp [420,580]），不再被滚动压缩。同时把 CTA「开始对话」从底部栏移到立绘上叠，整体改为沉浸式布局 |
| 详情页字段访问报 `unchecked_use_of_nullable_value` | Dart 类型提升只对局部变量生效，对类字段无效（`c.personality != null && c.personality.isNotEmpty` 编译错） | 把字段先赋给局部变量（`final p = c.personality; if (p != null && p.isNotEmpty)`） |

## 首页顶栏 / 标签筛选页 / 收藏移除 / 发现随机 / 角色页调整（2026-11-05）

### A. 首页顶栏重构（`lib/views/home/home_shell.dart`）

- 删除左上角 **☰ 抽屉按钮** 与 **"Virtual" 字标**，首页顶栏改为**一行**：
  - 左：圆角搜索框（放大镜图标 + 占位提示「搜索内容」），点击 `push('/home/search')`；
  - 右：「分类」按钮（图标 + 文字，浅色圆角块），点击 `push('/home/tags')`。
- 抽屉整体删除（`Scaffold.drawer` 与 `CosmosDrawerBody` 一并移除）。原抽屉入口的替代路径：

| 原抽屉入口 | 现可达路径 |
|---|---|
| 首页 / 发现 / 角色 | 底部导航 |
| 我的 | 底部导航 → 我的 |
| API接入 | 我的 → API接入（同时也可从「更多」进入） |
| 更多 | 我的 → 更多 |
| 世界书 / 预设 / 正则 | 我的 → 更多 → 对应条目 |
| 插件 | 我的 → 插件 |
| 主题 | 我的 → 主题 |

- 顶部状态栏 inset 规范不变：首页仍使用真实 AppBar（widget 顶端 0、高度 = 状态栏 + `kToolbarHeight`），未改 `toolbarHeight`。

### B. 标签筛选页（`lib/views/home/tag_filter_page.dart` + `tag_filter_data.dart`）

- 路由：`/home/tags`（ShellRoute 内，保留底部导航），入口 `push`，页面有返回箭头；系统返回走 pop 回首页，不退出 App。
- 布局：顶部「返回 + 标签筛选 + 搜索」；左栏竖排四组（热门标签 / 主题 / 角色 / 情节），右栏三列 chip 网格；选中态为实心紫底 + 勾选图标，组标题旁显示该组已选数量。
- 筛选语义：**同组并集、跨组交集**；空集合视为该组未启用。命中规则：`tags` 精确命中优先，其次名称 / 描述包含该词（让「角色 / 情节」这类抽取词也能筛到无对应 tag 的卡）。
- 未选任何标签时点「搜索」给出 SnackBar 提示「请先选择至少一个标签」。
- 结果复用 `CharacterCoverCard`（与首页同一组件），显示命中数；空结果显示「没有符合所选标签的角色卡」+ 减少标签建议 + 「返回筛选」。
- 标签数据来源（集中维护在 `tag_filter_data.dart`）：
  1. **优先真实数据**：`/api/characters` 下发的 `tags` 字段（种子卡 `Virtual_background/lib/database/seed.dart` 自带 tags）；
  2. 热门标签 = 真实 tag 频次降序；
  3. 主题 = 各角色 `tags.first`（与首页分类区块同一套主分类）；
  4. 角色 / 情节 = 固定词表 `TagFilterVocabulary.role/plot` 中**确实出现在数据里**的词（tag 命中或名称/描述包含），避免出现必然空结果的标签；
  5. 某组为空时用剩余真实 tag 兜底。改词只改该文件的词表。

### C. 收藏功能移除（UI only）

| 位置 | 移除内容 |
|---|---|
| `character_tab_page.dart` | 「收藏」分段、`_FavoriteView`，TabController 由 3 段改 2 段 |
| `character_detail_page.dart` | 互动条收藏按钮及 `_saved` / `_saveCount` 状态 |
| `category_characters_page.dart` | 互动数「收藏」筛选下拉与 `_savesOf` |
| `character_discover_feed.dart` | 收藏操作按钮、`_faved` 状态与收藏 SnackBar |
| `chat_character_info_page.dart` | 角色信息里的「已收藏」标志 chip（保留「已置顶」） |

底层保留：`Character.isFavorite` 字段、`CharacterProvider.toggleFavorite` / `favorites`、数据库读写与迁移逻辑均未改动，老数据不会报错。

### D. 发现页随机时机（`lib/views/discover/character_discover_feed.dart` + `lib/utils/random_order.dart`）

- 进入页面 / 翻页：保持后端顺序，不重排。
- **仅下拉刷新**（`RefreshIndicator`）时调用 `shuffledOrder` 随机重排，并回到第一张，形成「换一批」；`PageView` 使用 `PageScrollPhysics(parent: AlwaysScrollableScrollPhysics())`，保留翻页吸附同时允许第一张继续下拉触发刷新。

### E. 角色页调整（`lib/views/character/character_tab_page.dart`）

- 顶部右侧为 **搜索图标 + ⋮ 三点菜单**（角色管理 / 上传角色 / 创建角色）；搜索 `push` 进入 `/home/search`，返回回角色页。（1.0.26 起）
- 「历史」列表改为与首页一致的三列 `CharacterCoverCard` 网格（复用同一组件），点击进 `/chat/:id`；长按已改为**多选模式**（见下文「UI 打磨批次」）。
- **首页角色卡展示不全**：根因是 `home_page.dart` 分类区块 `entry.value.take(4)` 强制只渲染每类前 4 张，第 5 张起在首页完全不可见；后端分页、种子数据量与过滤条件均无问题。修复：去掉 `take(4)`，分类内全量展示，「更多 >」入口保留。

### F. 验证

- `flutter analyze`：1 warning（与基线一致，`test/community_location_test.dart:12` 未使用参数）。
- `flutter test`：新增 `test/tag_filter_test.dart` 9 条用例；最终全量 **256 通过 / 2 失败** —— `shell_status_bar_inset_test`（已于 1.0.29+30 修复：发现页错误态长文案不可滚动导致 overflow）、`app_providers_test`「新建角色页加载」（并行跑时的 `did not complete` 已知 flake，单独复跑通过）。同一套用例前一轮还出现过 `settings_provider_test` / `upstream_retry_policy_test` 的加载 flake，单独复跑 20/20 通过。
- 当时出包（1.0.24+25）：**103.0MB**（107,999,877 bytes），`versionName=1.0.24 / versionCode=25`，V2 签名 `CN=Tav`，工作区 `*.gguf` 数量 = 0。
- 当时版本：`1.0.24+25`（**当前为 1.0.30+31**，见文首「当前状态」）。

## 图片加载与缓存策略（2026-11-05，1.0.25+26）

用户反馈「图片一张一张往外蹦、每次打开都卡」。先查证后改，结论与实现如下。

### 查证事实

| 项 | 事实 |
|---|---|
| **图片来源** | ① 在线卡 `avatarUrl`：后端绝对 URL（`/api/avatars/{file}`、`/api/uploads/{file}`，**无 CDN**）；② 本地卡 `avatarPath`：可能为 http URL / `data:image/…;base64`（角色卡内嵌）/ 本地文件路径；③ 社区用户头像：http URL |
| **改造前加载方式** | 封面卡/轮播/详情用 `CachedNetworkImage`（`memCacheWidth` 400/1120、fade 120ms、无占位）；头像/聊天背景/资料页/社区头像用裸 `NetworkImage` 或 `Image.network`（**无磁盘缓存、无降采样**） |
| **磁盘缓存** | 仅 `CachedNetworkImage` 默认走 `flutter_cache_manager`（默认 200 对象 / 30 天）；裸 `NetworkImage`/`Image.network` 无磁盘缓存。**进程重启后仅部分图命中**，列表大量图每次都重新下载解码 → 用户感知的「没有本地缓存」 |
| **抽样（`Virtual_background/public/avatars`）** | `char-001.jpg` 1368×768 / 167,485 B；`char-002.jpg` 1368×768 / 199,216 B；`char-003.jpg` 1368×768 / 164,487 B。**列表卡显示宽约 170–180dp，改造前基本按原图直出** |
| **网络侧** | `/api/avatars/*`、`/api/uploads/*` 仅返回 `Cache-Control: public, max-age=86400`，**无 ETag、无缩略图端点**；列表接口 `avatar_url` 返回的也是原图 |

### 实现

| 位置 | 改动 |
|---|---|
| `lib/services/app_image_cache.dart`（新增） | 统一 `providerFor()`：http → `CachedNetworkImageProvider`（共享 `CacheManager`）；`data:` → base64 LRU（24 条）复用 `MemoryImage`；本地文件 → `FileImage`；统一按 `decodeWidth` 套 `ResizeImage`。另含 `keyFor()`（URL 去 fragment/trim）、`decodeWidthFor()`（显示宽 × DPR，上限 4096）、`lookaheadIndices()` 纯函数 |
| `lib/views/common/cached_app_image.dart`（新增） | `CachedAppImage`：`LayoutBuilder` 自动按实际宽度 × DPR 降采样；浅色骨架占位；150ms 淡入；失败显示重试图标，点击清该 URL 的磁盘缓存并重试。`AppImagePreloader`：并发上限 **2**、队列去重 |
| 列表 | `character_cover_card.dart`、`character_tab_page.dart`、`character_list_page.dart` 全部改走统一组件/Provider |
| 详情与背景 | `character_detail_page.dart`（hero 传 `decodeWidth: 0` = 原图）、`chat_background.dart`、`chat_page.dart`、`chat_character_info_page.dart`、`discover_page.dart`、`profile_page.dart`、`profile_edit_page.dart`、`user_profile_page.dart`、`post_detail_page.dart`（含评论头像） |
| 预加载 | 首页分类/搜索结果网格、标签筛选结果网格、发现页翻页：`lookaheadIndices(..., lookahead: 2)` + `AppImagePreloader.preload`，只预取接下来 2 张 |

### 参数

| 项 | 值 |
|---|---|
| 磁盘缓存目录 | 插件托管（Android `…/cache/libCachedImageData/`，iOS `Library/Caches`），名 `virtual_app_image_cache` |
| 容量 / 过期 | **400 张 / 30 天**（`AppImageCache.maxObjects` / `stalePeriod`，可配置） |
| 缓存 key | 仅 URL（去 `#fragment`、trim），不含解码宽度 → 同一原图只存一份 |
| 列表降采样 | 显示宽 × `MediaQuery.devicePixelRatio`，上限 4096px；详情/全屏解原图 |
| 占位 / 淡入 | 主题色骨架（`surfaceContainerHighest` 35% 或卡片色）；淡入 **150ms** |
| 预加载并发 | **2**，同 URL 队列内去重，仅 http(s) |
| base64 内嵌图 | 解码结果 LRU 24 条，复用同一 `Uint8List`，避免每次重建重新解码 |

### 说明与取舍

后端只提供原图（无缩略图字段、无 ETag）。本次采用「客户端降采样 + 磁盘缓存」：列表图只按显示尺寸解码，流量仍按原图下载一次（首屏后命中磁盘缓存）。若后续要进一步降低首屏流量与首打开耗时，建议后端新增 `avatar_thumb_url`（如 400px 宽 WebP），客户端优先读缩略图、详情再取原图。

## UI 打磨批次（2026-11-05，1.0.26+27）

按用户 5 张截图逐项修复，只动这 5 处，未改列表结构与整体布局。

| # | 问题 | 改动 |
|---|---|---|
| 1 | 标签筛选页右上角「搜索」挤成一团（渐变圆底 + 图标 + 文字） | 改为**纯放大镜 `IconButton`**（`Icons.search_rounded`，无文字/无渐变底），点击行为不变；默认 48×48 热区 ≥ 40dp |
| 2 | 首页顶栏搜索框与「分类」两侧留白过多 | `_homeTopBar` 改为 `Expanded(flex: 4)` 搜索框 + `Expanded(flex: 1)` 分类按钮，**4 : 1**；两者高度统一 **40dp**；左右内边距 **5dp**（1.0.27 起，由 16dp 收紧） |
| 3 | 角色页「历史」是深色渐变遮罩 + 白字，「角色」是图下标题，两种样式不一致 | `CharacterCoverCard` 增加排版枚举 `CharacterCoverCardStyle { overlay, below }`；「角色」「历史」两段统一用 `style: below`（**图片在上、标题与描述在图下、无深色遮罩**），复用同一组件，不再有第二套卡片实现 |
| 4 | 长按弹出单个小菜单 | 长按进入**多选模式**：卡片右上角勾选圈（选中实心勾）、点击卡片切换选中；顶栏切换为「已选 N 项」+ 全选 / 置顶 / 删除 / 取消；删除二次确认；置顶只对选中的本地条目生效，失效项忽略并提示；`PopScope` 在多选态拦截一次系统返回（先退出多选） |
| 5 | 角色页顶栏缺搜索按钮 | 顶栏右侧依次为**搜索图标 + ⋮**（搜索在左、⋮ 最右）；搜索 `push('/home/search')`，返回回角色页 |

### 多选状态（`lib/utils/multi_select.dart`）

- `MultiSelectState` 为不可变纯逻辑：`toggle(id)`、`selectAll(ids)`、`clear()`、`count`、`contains(id)`；页面用 `setState` 替换实例。
- 分段切换（角色 ↔ 历史）自动退出多选，避免两段 id 混淆。
- 「全选」以当前分段顺序取 id；「置顶」角色段写 `Character.isPinned`，历史段调 `ChatProvider.pinConversation`；「删除」统一走二次确认对话框。

### 验证

- `flutter analyze`：1 warning（与基线一致，`test/community_location_test.dart:12`）。
- `flutter test -j 1`：**276 通过 / 1 失败**，唯一失败为 `shell_status_bar_inset_test`（**已于 1.0.29+30 修复**：发现页错误态在 360×780 下长错误文案不可滚动，Column overflow 101px）；新增 `test/multi_select_test.dart` 7 条用例全过。并行跑时偶发 `did not complete` 的加载 flake（`world_info_binding_test` 等），单独复跑通过。
- 当时出包（1.0.26+27）：**103.0MB（108,004,385 B）**，`versionName=1.0.26 / versionCode=27`，V2 签名 `CN=Tav`，APK 内与工作区 `*.gguf` = 0。
  （当前以文首「当前状态」为准。）

## 发现页加载优化（2026-11-05，1.0.27+28）

### 查证结论

| 项 | 事实 |
|---|---|
| 进入时请求序列 | 改造前**首屏 4 个请求并发**：`GET /api/posts`（推荐）、`GET /api/follows`（关注列表）、`GET /api/posts?following=true`（关注流）、`GET /api/characters`（角色卡流）。其中前 3 个属于「推荐 / 关注」Tab，默认停留在「发现」Tab 时并不需要 |
| 是否 N+1 | 否。角色卡流只有 1 个列表请求，没有逐条详情请求 |
| 列表接口 | `GET /api/characters` **不分页、无 LIMIT/OFFSET、无 ETag**，一次返回全部角色；`toSummaryJson` 每条含 `description` / `greeting` / `persona` 长文本 + `avatarUrl`（当前端只用到 id/name/description/avatarUrl/tags） |
| 图片 | 全部走 `CachedAppImage`（磁盘缓存 400 张 / 30 天）；种子图 1368×768、165–200KB；线上卡无缩略图 |
| 解码 | `CachedAppImage` 按 `LayoutBuilder.maxWidth × DPR` 降采样（411dp / DPR 2.75 → 约 1130px 宽），整屏即解整屏所需 |
| 预取 | 改造前 `lookahead=2`（进入即预取后 2 张，并发 2），会与首张抢带宽 |
| 首帧 | 列表返回前显示 `CircularProgressIndicator` 居中占位（深色页可见，但信息为空）；无同步 JSON 解析或全量 build 阻塞首帧 |
| 后端耗时 | 本次本地未启动后端，无法实测响应时间；代码层确认无分页、无 `ETag`、无缩略图 |

### 改动

1. **发现页社区数据懒加载**（`discover_page.dart`）：`initState` 不再拉推荐/关注，等切到对应 Tab 才发请求；进入发现页首屏请求 **4 → 1**（只 `/api/characters`），减少带宽争用。
2. **预取减半**（`character_discover_feed.dart`）：`lookahead` 由 2 改为 **1**，进入只预取下一张，翻页后再预取再下一张；并发上限仍为 2。
3. **客户端分批呈现**：后端无分页，客户端先渲染 **12 张**，滑到本批末尾前 2 张时追加 12 张（`_visibleCount`），避免首帧为全部卡片建 widget/解码。
4. **首屏骨架**：列表未返回时显示深色渐变 + 图片块 + 文字条骨架（右上一个 18dp 细进度圈），不再空白等待。
5. **降采样**：沿用 `CachedAppImage` 的「屏宽 × DPR」策略，详情才解原图。

### 优化前后对比（代码层预期）

| 指标 | 优化前 | 优化后 |
|---|---|---|
| 进入发现页首屏请求数 | 4（posts ×2 + follows + characters） | **1**（`/api/characters`） |
| 首屏渲染 | 居中转圈，列表到达才出现内容 | **立即出现骨架**，列表到达后替换 |
| 进入即预取图片数 | 2 张（并发 2） | **1 张**（下一张），翻页再预取 |
| 首帧构建卡片数 | 全部（后端一次返回多少就建多少） | **12 张**，滑动追加 |
| 单张解码宽 | 1130px（411dp×2.75） | 同左（未超屏需） |
| 二次进入 | 图片命中磁盘缓存 | 同左（无回退） |

> 无法真机计时：后端未启动，且本次不跑设备。首张可见时间仍取决于「`/api/characters` 响应 + 首张图下载/解码」，但少了 3 个并发请求与 1 张抢先预取，弱网下改善最明显。

### 后端建议（本次未改）

- `/api/characters` 增加 `limit` / `offset` 分页（每页 10–20），并加 `ETag`；
- 摘要里去掉 `persona` / `greeting`（客户端列表不用，改为详情接口返回）；
- 增加 `avatar_thumb_url`（约 400px 宽），列表读缩略图、发现页大图按需取原图。

## 角色立绘全屏背景（2026-11-06，1.0.28+29）

聊天页新增「角色卡 PNG 立绘铺满全屏」能力，作为背景设置的一部分。

### 数据与开关

| 项 | 说明 |
|---|---|
| 存储 | 复用 `ChatTheme`（每对话 `conv-bg-<conversationId>`）：新增 `useCharacterPortrait`（bool）与 `portraitScrimOpacity`（double） |
| 默认值 | 开关 **true**（新对话/从未设背景）；遮罩 **0.55**，clamp 到 `0.0–0.85` |
| 老数据兼容 | `fromJson` 缺字段时：**有** `backgroundImage` → 开关 `false`（保留用户已选背景）；**无** → `true` |
| 立绘来源 | `Character.avatarPath`：http URL（在线卡）/ `data:image/...` base64（本地导入的 PNG/CCv2 嵌入图）/ 本地文件路径 |
| 回落规则 | 立绘不可渲染（Web 本地路径、空值、无法识别）或开关关闭 → 走原 `backgroundImage`（渐变/图片）；两者都没有 → 不套背景层 |

### 渲染（`views/chat/chat_background.dart` → `ChatBackgroundLayer`）

- 立绘优先于 `backgroundImage`，用 `CachedAppImage` 的 `BoxFit.cover` + `Alignment(0, -0.25)`（人物居中偏上）铺满整个 body（含状态栏下方到输入区之间的画布）；
- 立绘之上叠 `Colors.black.withValues(alpha: portraitScrimOpacity)` 遮罩，保证气泡与文字对比度；0% 不压暗、85% 接近纯黑；
- 解码走 `CachedAppImage` → `AppImageCache`：按「显示宽 × DPR」降采样（整屏宽 411dp/DPR 2.75 ≈ 1130px），同一 provider 命中 Flutter image cache，**只解一次**，滚动/流式输出不会重复解码；
- `usablePortraitPath()` 先判定可渲染，聊天页据此决定 `hasBg`（AppBar 透明与 `topInset` 逻辑不变）。

### 设置页（`views/chat/chat_background_page.dart`）

- 新增「使用角色立绘作为全屏背景」开关（角色无可用立绘时禁用并提示会回落）；
- 新增「遮罩深度」滑杆（0–85%，17 档 = 5% 步进），默认 55%；
- 预览与聊天页共用 `ChatBackgroundLayer`，实时反映开关/遮罩；
- 「当前来源」文案在立绘生效时显示「角色立绘（PNG 卡面）」。

### 验证（1.0.28+29）

- `flutter analyze`：仅基线 1 warning（`test/community_location_test.dart:12` 的未使用 `status` 参数），无新增；
- `flutter test`：**281 通过 / 1 失败**，失败仅为历史用例 `shell_status_bar_inset_test`；新增 5 例（JSON 往返、老数据默认、遮罩 clamp、可用性判定、立绘层铺满）；
- 出包：`flutter build apk --release --target-platform android-arm64` → **108,010,149 B（103.0MB）**，versionName `1.0.28` / versionCode `29`，V2 签名 `CN=Tav`（SHA-256 `3fcf3a98…d52d24`），APK 内 `*.gguf` = 0，工作区 `*.gguf` = 0。

## 发现页错误态溢出修复（2026-11-06，1.0.29+30）

长期失败的 `test/shell_status_bar_inset_test.dart`（`RenderFlex overflowed by 101 pixels on the bottom`）已修复，**未删用例、未 `skip`、未降低断言**。

### 根因（真布局脆弱，被测试环境触发）

| 证据 | 内容 |
|---|---|
| 出错页面 | `/discover` 的 `CharacterDiscoverFeed`（Shell body，测试窗口 1080×2340@3 → 360×780dp，状态栏 44dp） |
| 出错 widget | `character_discover_feed.dart` 错误态 `Column`；约束 `w<=312, h<=559`，自然高度约 660dp |
| 触发链 | 测试环境无后端 → `GET /api/characters` 返回 400 → 错误态把整段 `DioException.toString()` 直接上屏（含请求/响应详情，多行超长） |
| 定性 | **真布局问题**：错误态用不可滚动的 `Center → Padding → Column(mainAxisSize.min)`，文案长度不可控；真机后端不可达/返回错误体时同样会溢出，只是测试环境稳定复现 |

### 改动（只改页面，不动断言）

- `lib/views/discover/character_discover_feed.dart` 错误态：`Center → SingleChildScrollView(padding: 24) → Column`，重试按钮不变；
- `lib/views/discover/discover_page.dart`（`_ErrorState`，同类风险）：同样改为可滚动错误态，图标/文案/重试按钮不变；
- 断言语义保持不变：有返回箭头的页面避开状态栏、根页面顶端为 0、高度 = 状态栏 + 56。

### 验证（1.0.29+30）

- 单跑 `flutter test test/shell_status_bar_inset_test.dart`：**All tests passed**；
- 全量 `flutter test -j 1`：**282 通过 / 0 失败**（此前 `281 通过 / 1 失败`）；
- 状态栏巡检（0 / 24 / 48dp × 10 条路由：`/home`、`/discover`、`/characters`、`/profile`、`/endpoints`、`/chat`、`/settings`、`/home/tags`、`/character/new`、沉浸式对话探针）：未发现其它 overflow；
- `flutter analyze`：仍为基线 1 warning（`test/community_location_test.dart:12` 未使用 `status` 参数）；
- 出包：`--target-platform android-arm64` → **108,010,353 B（103.0MB）**，versionName `1.0.29` / versionCode `30`，V2 签名 `CN=Tav`（证书 SHA-256 `560b2ac5…5fe117`），APK 内 `*.gguf` = 0。

## 本地部署恢复与 GGUF 导入（2026-11-06，1.0.30+31）

### 改动清单

| 文件 | 改动 |
|---|---|
| `lib/config/app_feature_flags.dart` | `localDeployEnabled = true`，开关保留可一键关闭 |
| `lib/providers/chat_provider.dart` | 移除 3 处「本地部署已停用」守卫；`_buildLocalPrompt` 支持精简/完整两档，完整模式复用 `PromptService.assembleSystem` + `ContextWindowService.trim`（按端点 `contextSize` 裁剪） |
| `lib/models/endpoint.dart` | 新增 `LocalPromptMode { concise, full }` 与字段 `localPromptMode`（默认精简、JSON 兼容旧数据）、`usesFullLocalPrompt` |
| `lib/views/endpoint/endpoint_edit_page.dart` | 恢复「接入 / 部署」切换；部署区新增模型选择/更换/删除、手填路径、文件状态（存在 + 字节数 + App 目录/外部路径）、提示词模式选择与说明 |
| `lib/services/gguf_header.dart` | 纯 Dart GGUF 头校验（magic `GGUF` + 版本 1–3） |
| `lib/services/local_model_service*.dart` | 条件导入的模型服务：流式复制、`.partial` → rename、同名同大小幂等跳过、进度/取消、只删 App 目录内文件；Web 走 stub 明确不支持 |
| `test/local_model_import_test.dart` | 8 例：头校验（合法/改名/空/版本）、导入回填、幂等跳过、取消清理、非法拒绝、状态与删除边界、路径拼接 |
| `test/local_prompt_mode_test.dart` | 6 例：模式默认/切换/JSON 兼容、用户输入不被裁剪、只保留最近 4 轮 |

### 导入流程与提示词模式

- 流程：选择 `.gguf`（SAF，无存储权限）→ 前 8 字节校验 → 流式写入 `getExternalFilesDir(null)/models/<name>.gguf.partial` → `rename` → 回填路径；
- 失败提示：头非法 / 选择器失败 / 空间不足（ENOSPC、Windows 112）/ 写入失败分别有中文提示；取消不报错；
- 精简（默认）：压缩角色卡（≤300 token）+ 最近 4 轮 + 本轮指令；完整：完整角色卡 + 世界书 + 预设 + 历史裁剪；
- 精简模式本轮用户输入 1:1 保留，system 与历史独立；适配器的 `ask` + 75% 阈值增量上下文未改。

### 验证（1.0.30+31）

- `flutter test -j 1`：**296 通过 / 0 失败**（原 282 例全保留 + 新增 14 例）；
  - 并行跑时偶发 `did not complete` / `Connection closed before test suite loaded` 加载 flake（`home_shell_compose_nav_test`、`png_card_writer_test`），单跑均通过，属既有 flake；
- `flutter analyze`：仍为基线 1 warning（`test/community_location_test.dart:12` 未使用 `status` 参数）；
- 出包：`--target-platform android-arm64` → **108,036,733 B（103.0MB）**，versionName `1.0.30` / versionCode `31`，
  V2 签名 `CN=Tav`（证书 SHA-256 `560b2ac5…5fe117`），SHA-256 `A2836882…ADBECC310`，APK 内 `*.gguf` = **0**。

### 真机复测点

1. 新建部署端点 → 选择 1–2B GGUF（如 Qwen2.5-1.5B-Instruct Q4_K_M）→ 精简模式发消息，确认有回复且不是「复读设定」；
2. 切换完整模式 + 3–4B 模型（如 Qwen3-4B / Gemma-3-4B），确认世界书条目命中、角色卡细节进入回复；
3. 同一文件重复选择应提示「跳过复制」；导入中途退出/取消应无残留 `.partial`；
4. 删除模型后路径清空；手填外部路径的文件点删除应只提示、不删除；
5. 断网/后端不可达时聊天页、发现页错误态均可滚动，无 RenderFlex overflow。






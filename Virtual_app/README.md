# Virtual

Virtual 是一个基于 Flutter 的 AI 角色聊天客户端，定位为“本地优先、角色扮演、跨模型接入”的应用。

它目前的代码结构已经具备完整的客户端闭环：角色管理、聊天历史、模型端点配置、主题设置、插件/世界书/预设/正则规则等模块均在项目中实现。

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
  providers/                   # 状态管理
    settings_provider.dart
    metadata_provider.dart
    endpoint_provider.dart
    character_provider.dart
    chat_provider.dart
  route/
    app_router.dart            # 路由配置
  services/
    api_service.dart
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
  views/
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

当前主路由包括：

- /chat
- /chat/:id
- /characters
- /character/new
- /character/:id/edit
- /endpoints
- /endpoint/new
- /endpoint/:id/edit
- /lorebooks
- /regex
- /presets
- /settings
- /plugins
- /more
- /debug

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

### 5. 模型与端点管理

端点和模型配置位于：

- [lib/providers/endpoint_provider.dart](lib/providers/endpoint_provider.dart)
- [lib/services/model_registry_service.dart](lib/services/model_registry_service.dart)
- [lib/services/adapters](lib/services/adapters)

项目支持多家模型接入，当前实现中已具备 OpenAI / Anthropic / Gemini 适配器结构，说明应用设计目标是“多模型切换”，不是单一厂商绑定。

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
| 1 | AppBar 右上角搜索图标 | `IconButton(Icons.search)` | **点击跳转到 `/home/search` 搜索筛选页**（不再在首页内展开搜索框）。原页内搜索框 `HomePage.searchVisible` 逻辑保留但不再被触发，作为备用 |
| 2 | 轮播图（横版，比例 1.58） | `views/home/banner_carousel.dart` | 数据在备案时才占位，**拉不到就不渲染**，不留空白 |
| 3 | 分类 chips（高 44，横向滚动，选中走渐变） | `_categoryChip` | 分类来自所有角色的 `tags` 并集 |
| 4 | 竖版封面卡网格（比例 0.62，2~3 列） | `views/common/character_cover_card.dart` | 其余为空 / 加载中 / 错误态占满剩余空间 |
| 5 | 分类区块「更多 >」按钮 | `context.go('/home/category/:name')` | 跳转到搜索筛选页，预选中该分类 tag |

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

## 发现页社区功能（2026-09-10）

发现页从工具入口网格改为**社区聚合页**，定位为用户内容发现与社交入口。

### 页面结构

发现页为 `Column(TabBar + Expanded(TabBarView))` 结构（不使用内层 Scaffold，避免与 home_shell 双层 AppBar 冲突），home_shell 在 `/discover` 路由下隐藏 AppBar（`PreferredSize(height: 0)`）。

两个 Tab：

| Tab | 内容 | 数据来源 |
|---|---|---|
| 关注 | 顶部横向关注列表（头像+ID+「找更多」）→ 创作者发布的角色卡宣传 / 对话炫耀 | Mock（后续接后端 API） |
| 推荐 | 顶部横向社区分类（治愈/冒险/恋爱/奇幻/科幻/日常/战斗/悬疑）→ 热门角色卡 + 用户对话炫耀 + 官方公告 | Mock |

### 帖子类型

| 类型 | 说明 | 组件 |
|---|---|---|
| `characterCard` | 用户发布的角色卡宣传，封面 + 描述 + 标签 + 互动 | `_CharacterPostCard` |
| `conversationShowcase` | 用户炫耀对话片段，气泡式渲染对话行 | `_ConversationShowcaseCard` |
| `announcement` | 官方公告/版本更新，渐变背景 | `_AnnouncementCard` |

### 数据模型

- `lib/models/community_post.dart`：`Creator`、`CommunityPost`、`DialogueLine`、`CommunityTag` + Mock 假数据
- 第一版使用写死的示例数据，后续替换为后端 API 即可（模型已定义好 `fromJson` 可扩展）

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
| 互动条 | 圆角胶囊容器，左：评分（星+分+评分数），右：点赞/转发/收藏 | 点赞/收藏可本地 toggle 切换状态，转发给 toast「开发中」。互动数由 characterId hash 生成稳定 mock（后端暂无该字段） |
| 创作人区 | 渐变头像（首字母）+ 名字 + ID + 关注按钮 | 关注按钮本地 toggle |
| 详情卡片 | `SliverList.separated`，每段包圆角容器 + 边框 | 描述 / 人设 / 场景 / 创作者备注 / 开场白，标题行带渐变图标方块。**用局部变量做类型提升**（字段访问不会自动提升，写成 `c.personality != null && c.personality.isNotEmpty` 会报 unchecked_use_of_nullable_value） |

「开始对话」按钮（立绘上叠的）执行原有导入闭环：拉详情 → 建本地卡（幂等）→ 建/续会话 → 跳 `/chat/:id`。

> 已移除底部 `bottomNavigationBar`——CTA 已在立绘区，避免重复。

### 路由

```
/home/character/:id  →  CharacterDetailPage(characterId: id)
/home/search         →  CategoryCharactersPage()（无预选分类，从首页搜索图标进入）
/home/category/:name →  CategoryCharactersPage(category: name)（预选该分类，从「更多 >」进入）
```

## 搜索筛选页（2026-09-10）

`CategoryCharactersPage` 从「按 tag 简单过滤」重写为**多维度搜索筛选页**。

### 页面结构（`lib/views/home/category_characters_page.dart`）

从上到下：

| 区域 | 实现 | 说明 |
|---|---|---|
| AppBar | 返回按钮 + 搜索输入框（`TextField`）+ 「搜索」渐变按钮 | **搜索框和搜索按钮一体化在 AppBar 行内**（不再单独占下方一行）。输入框 hint 在无预选分类时显示「搜索角色名或描述…」；从「更多 >」进入时显示 `#分类名`。回车提交，「搜索」按钮显式触发；带清除 ×。**home_shell 在 `/home/search` 和 `/home/category/:name` 路由下隐藏自己的 AppBar**（`PreferredSize(height:0)`），避免双层 AppBar 叠加，与 `/discover` 同样处理 |
| 标签横向筛选 | `ListView.separated` 横向 chips（高 44） | tags 来自所有角色并集按频次排序取前 12；可多选（AND 关系：必须包含所有选中） |
| 互动数筛选条 | 三个 `_MetricDropdown`：点赞 / 收藏 / 转发 | 每项可选：不限 / 100+ / 500+ / 1k+ / 5k+；下三角箭头 |
| 结果网格 | `SliverGrid` 2~3 列竖版封面卡（0.62 比例） | 空结果时显示「清除全部筛选」按钮 |

### 互动数据来源

后端 `/api/characters` 列表不下发互动数，按 `characterId.hashCode` 本地生成稳定 mock：
- 点赞：120 + (hash % 5) × 87（120 ~ 468）
- 收藏：56 + (hash % 7) × 23（56 ~ 218）
- 转发：18 + (hash % 3) × 14（18 ~ 46）

与详情页互动条同源（同一 hash 公式），后续后端补字段时替换 `_likesOf` / `_savesOf` / `_sharesOf` 即可。

### 筛选逻辑

关键词匹配（name / description 包含）+ 标签 AND + 三个互动数阈值，全部满足才进入结果。`_filtered` getter 实时计算，任何筛选项变更都 `setState` 触发重建。

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

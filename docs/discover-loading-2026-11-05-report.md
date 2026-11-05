# 首页顶栏留白 + 发现页加载优化报告（1.0.27+28）

日期：2026-11-05　　范围：① 首页顶栏左右留白 16dp → 5dp；② 发现页慢排查与针对性优化　　git commit / 上传：**均未执行**

---

## 一、首页顶栏留白

| 项 | 改动 |
|---|---|
| 文件 | `lib/views/home/home_shell.dart`（`_homeTopBar` 外层 AppBar） |
| 改动 | 首页根路由 `titleSpacing` 16 → **5**，右侧 `actions` 占位 `SizedBox(width: 16)` → **5**；非首页（返回按钮态）仍保持 16dp |
| 保持不变 | 搜索框 : 分类按钮 = **4 : 1**（`Expanded` flex 4 / 1）；两者高度 **40dp** |
| 效果 | 左右不再各留一块 16dp 空白，搜索框与分类按钮更贴近屏幕边缘 |

---

## 二、发现页慢：查证事实表

| # | 事实 | 结论 |
|---|---|---|
| 1 | **进入发现页的请求序列**：改造前 `DiscoverPage.initState` 立刻 `Future.wait` 发出 3 个请求（`GET /api/posts`、`GET /api/follows`、`GET /api/posts?following=true`），同时「发现」角色卡流自己发 `GET /api/characters` → **首屏 4 个并发请求** | 前 3 个属于「推荐 / 关注」Tab，默认停在「发现」Tab 时完全用不到；它们与首张立绘抢带宽 |
| 2 | **是否 N+1** | 否。角色卡流只有 1 个列表请求，没有逐条请求详情 |
| 3 | **列表接口返回条数与负载** | `routes/api/characters/index.dart`：`SELECT … FROM characters`，**无 LIMIT / OFFSET、无分页参数、无 ETag**，一次返回全部。单条 `toSummaryJson` 含 `id / name / description / avatarUrl / tags / greeting / persona / creator / characterVersion / updatedAt / popularity`，其中 `greeting`、`persona` 是长文本，客户端列表只用到 id/name/description/avatarUrl/tags。种子库 5 条；线上卡数量未知（后端未启动，无法实测响应体大小与耗时） |
| 4 | **大图规格** | 种子立绘 1368×768、167–199KB（`char-001/002/003.jpg`），线上卡无缩略图；发现页大图不是「原图直出」——统一走 `CachedAppImage`，按 `LayoutBuilder.maxWidth × DPR` 降采样（411dp / DPR 2.75 ≈ 1130px 宽），像素量约为原图 68% |
| 5 | **PageView 预加载策略** | 改造前：进入后 `_preloadAround(_index)` 用 `lookaheadIndices(..., lookahead: 2)`，即**进入就预取后 2 张**（`AppImagePreloader` 并发 2）；PageView 本身只构建当前页 |
| 6 | **首帧是否被阻塞** | 无同步 JSON 解析、无同步解码、无全量 build；但列表返回前只有居中 `CircularProgressIndicator`，属于「无信息空等」；且后端一次返回全部时 PageView 的 `itemCount = 全部` |
| 7 | **后端响应时间与分页** | 后端未在本机运行（`localhost:8080` 无响应，`dart_frog` CLI 未安装），**无法实测耗时**；代码确认**不分页** |

---

## 三、改动位置

| 文件 | 改动 |
|---|---|
| `lib/views/discover/discover_page.dart` | 社区数据（推荐/关注）改为**懒加载**：`initState` 不再请求；`TabController` 监听切到 index 0/2 时才 `_load()`；加载中/已加载标志避免重复请求；进入发现页首屏请求 4 → **1** |
| `lib/views/discover/character_discover_feed.dart` | ① 预取 `lookahead` 2 → **1**（进入只预取下一张）；② 客户端分批呈现：`_pageSize = 12`、`_visibleCount`，`PageView.itemCount = _renderedCount`，滑到本批末尾前 2 张追加下一批；③ 首屏骨架 `_FeedSkeleton`（深色渐变 + 图片块 + 文字条 + 右上 18dp 细进度圈）；④ 刷新/随机重排后重置到首批 12 张 |
| `lib/views/home/home_shell.dart` | 首页顶栏左右内边距 5dp |
| `pubspec.yaml` | 版本 `1.0.27+28` |
| `README.md`（根） | 版本表 1.0.27+28 |
| `Virtual_app/README.md` | 顶栏 4:1 行补「左右 5dp」；新增「发现页加载优化（1.0.27+28）」章节（查证、改动、前后对比、后端建议） |

> 未改后端；没有新增网络接口；没有改动发现页 UI 结构与 Tab 顺序。

---

## 四、优化前后对比（代码层数据 + 预期）

| 指标 | 优化前 | 优化后 |
|---|---|---|
| 进入发现页首屏请求数 | 3（社区）+ 1（角色卡）= **4 并发** | **1**（仅 `/api/characters`） |
| 首屏视觉 | 居中转圈（无内容信息），列表返回后一次性出现 | **立即出现骨架**，列表返回后替换为卡片 |
| 进入即预取图片 | **2 张**（并发 2） | **1 张**（下一张），翻页再预取；并发上限仍 2 |
| 首帧构建卡片数 | 全部（后端返回多少建多少） | **12 张**，滑近末尾追加 12 |
| 单张解码尺寸 | 1130×634（411dp × DPR 2.75），源图 1368×768 | 同左（已按屏宽×DPR，不超屏需） |
| 单张图片网络字节 | 原图 165–200KB（后端无缩略图） | **不变**（客户端无法减字节） |
| 二次进入 | 图片命中磁盘缓存（400 张 / 30 天） | 同左 |
| 弱网首张可见 | 4 请求争用 + 2 张预取抢带宽 | 单请求 + 仅 1 张预取，预期首张更快、翻页更稳 |

**可观测方式（真机）**：进入发现页时抓 Dio 日志，应只看到 1 条 `/api/characters`；切到「推荐」后才出现 `/api/posts`、`/api/follows`。翻页时 `AppImagePreloader` 一次最多 2 个下载任务。

**无法量化的部分**：`/api/characters` 的响应时间与响应体大小（本机后端未运行），以及首张可见毫秒数（本次未跑真机）。

---

## 五、测试与构建数据

| 项 | 结果 |
|---|---|
| `flutter analyze` | **1 warning**：`test/community_location_test.dart:12 unused_element_parameter`（与基线一致，无新增） |
| `flutter test -j 1` | **276 通过 / 1 失败**；唯一失败为历史用例 `shell_status_bar_inset_test`（基线既有），无新增失败 |
| 构建命令 | `flutter build apk --release --target-platform android-arm64` |
| APK | **108,003,841 B（103.0MB）**，与上一版 108,004,385 B 基本持平（-544 B） |
| 版本 | `versionName=1.0.27` / `versionCode=28` / `package=app.bitbear.virtual` |
| 签名 | V2 `Verified`，`CN=Tav`，SHA-256 `560b2ac5f682840b46a20aed07e00dcc8187a1d515019058bccc81ad4a5fe117` |
| `*.gguf` | APK 内 **0**，工作区 **0** |

---

## 六、真机复测点

1. **首张出现时间**：清缓存后首次进入发现页 → 应先看到骨架（不是空白/黑屏），列表到达后首张图淡入；对比旧版（转圈）主观等待更短。
2. **首屏请求数**：抓包/日志确认进入时只有 `/api/characters`；切到「推荐」或「关注」后才出现 posts/follows 请求。
3. **翻页是否卡**：连续快速滑动 10+ 张 → 每批 12 张追加，无明显掉帧；预取只提前 1 张，不应出现多张同时下载的排队。
4. **二次进入**：退出发现页再进入 → 首张图应立即从磁盘缓存出现，不重新下载。
5. **弱网表现**：限速 3G/丢包 → 骨架稳定，不白屏；首张失败时显示占位与重试；翻页加载下一张不阻塞当前页。
6. **社区 Tab 回归**：切到「推荐」「关注」→ 数据正常加载；登录/退出后关注流会重新拉取；下拉刷新仍正常。
7. **首页顶栏**：左右各 5dp，搜索框 : 分类约 4 : 1，高度对齐；左上/右上贴边但不裁切。

---

## 七、后端建议（本次未改）

1. `/api/characters` 增加 `limit` / `offset` 分页（每页 10–20）并返回 `X-Total-Count`，客户端按页请求；
2. 响应头增加 `ETag` / `Last-Modified`，配合 `Cache-Control` 做条件请求；
3. 摘要去掉 `persona` / `greeting`（列表不用），详情接口再返回完整字段；
4. 增加 `avatar_thumb_url`（约 400px 宽 WebP），列表与发现页首屏读缩略图，进入详情再取原图。

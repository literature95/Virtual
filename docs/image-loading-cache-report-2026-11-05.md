# 图片加载与缓存整改报告（1.0.25+26）

日期：2026-11-05　　范围：仅 App 端图片加载链路（不改列表结构与 UI 布局）　　git commit / 上传：**均未执行**

---

## A. 查证事实表

### A1. 图片来源与使用位置

| 来源 | 形态 | 使用位置 |
|---|---|---|
| 在线角色卡 | 后端绝对 URL：`{backend}/api/avatars/{file}`、`/api/uploads/{file}`；**无 CDN** | 首页封面卡、分类区块、搜索结果、标签筛选结果、轮播横幅、角色详情 hero、发现页大卡、聊天背景、聊天角色信息、资料页头像 |
| 本地角色卡 | `avatarPath` 三选一：http URL / `data:image/…;base64`（角色卡 PNG 内嵌）/ 本地文件路径 | 角色页三列历史网格、本地角色列表、角色信息页、聊天页背景与头像 |
| 社区用户 | http URL（后端 `/api/uploads/*`） | 发现页顶部「关注的人」、动态详情作者头像、评论头像、用户主页头像 |

### A2. 改造前加载方式

| 位置 | 旧实现 | 磁盘缓存 | 降采样 | 占位/错误态 |
|---|---|---|---|---|
| 封面卡 / 轮播 / 详情 | `CachedNetworkImage` | 有（默认 200 张 / 30 天） | `memCacheWidth` 400 / 1120（固定值，不按 DPR） | 无占位，错误为 `SizedBox.shrink` |
| 头像 / 聊天背景 / 资料页 | 裸 `Image.network` 或 `NetworkImage` | **无** | **无（原图解码）** | 无 |
| 社区头像（发现/详情/评论/主页） | 裸 `NetworkImage` / `BoxDecoration.image` | **无** | **无** | 无 |

### A3. 磁盘缓存现状

- 只有走 `CachedNetworkImage` 的那部分有磁盘缓存（`flutter_cache_manager` 默认 200 对象 / 30 天，未自定义目录与容量）。
- 裸 `NetworkImage` / `Image.network` **只在内存 `imageCache` 里**，进程重启即失联 → 每次冷启动列表都要重新下载并解码原图，这就是用户感知的「没有本地缓存、一张一张往外蹦」。
- 角色卡内嵌 base64：每次卡片重建都会重新 `base64Decode`，没有解码结果复用。

### A4. 抽样数据（2–3 张，来源 `Virtual_background/public/avatars`）

| 文件 | 像素尺寸 | 字节数 |
|---|---|---|
| `char-001.jpg` | 1368×768 | 167,485 B |
| `char-002.jpg` | 1368×768 | 199,216 B |
| `char-003.jpg` | 1368×768 | 164,487 B |

- 列表卡片实际显示宽约 170–180dp（2 列时约 170dp，3 列更小）。改造前**基本原图直出**：一张 1368×768 解码约占 4.2MB 位图内存；一屏 4–6 张卡 ≈ 17–25MB，滚动时反复解码，是卡顿主因。
- 首屏通常同时加载：轮播 1 张 + 分类区块 4–6 张 + 头像 5–10 个。

### A5. 网络侧

| 项 | 事实 |
|---|---|
| 响应头 | `/api/avatars/[file].dart` 与 `/api/uploads/[file].dart` 均只有 `cache-control: public, max-age=86400` |
| `ETag` | **无** |
| 缩略图端点 | **无** |
| 列表接口图片字段 | `avatar_url` 指向原图（不是缩略图） |

---

## B. 改动位置

### B1. 新增

| 文件 | 作用 |
|---|---|
| `Virtual_app/lib/services/app_image_cache.dart` | 统一 `ImageProvider` 工厂 + 共享磁盘缓存 + 降采样计算 + base64 LRU + `lookaheadIndices` 纯函数 |
| `Virtual_app/lib/views/common/cached_app_image.dart` | `CachedAppImage` 组件（自动降采样/骨架/150ms 淡入/失败重试）、`AppImagePreloader`（并发 2 + 去重） |
| `Virtual_app/test/app_image_cache_test.dart` | 12 条纯逻辑单测 |

### B2. 接入替换

| 文件 | 改动 |
|---|---|
| `views/common/character_cover_card.dart` | 删除本地 `resolveAvatarImage`，改 `CachedAppImage`（自动按卡宽 × DPR 解码） |
| `views/home/banner_carousel.dart` | `CachedNetworkImage` → `CachedAppImage` |
| `views/home/character_detail_page.dart` | hero 改 `CachedAppImage(decodeWidth: 0)`（**详情解原图**），保留兜底 |
| `views/home/home_page.dart` | 分类网格 / 搜索结果网格接入 `_preloadAround`（下一张 + 2） |
| `views/home/tag_filter_page.dart` | 结果网格接入 `_preloadAround` |
| `views/character/character_tab_page.dart` | 历史三列网格、上传选择列表 → `AppImageCache.providerFor` |
| `views/character/character_list_page.dart` | 列表头像 → `AppImageCache.providerFor` |
| `views/discover/character_discover_feed.dart` | 卡片 → `CachedAppImage`；翻页时预取后 2 张 |
| `views/discover/discover_page.dart` | 关注头像 → `AppImageCache.providerFor(decodeWidth: 180)` |
| `views/discover/user_profile_page.dart` | 顶部头像 → `decodeWidth: 200` |
| `views/discover/post_detail_page.dart` | 作者头像 96px、评论头像 96px |
| `views/chat/chat_background.dart` | 网络背景 → `CachedAppImage`（本地文件仍走 `Image.file`） |
| `views/chat/chat_page.dart` | 聊天背景 → `providerFor(decodeWidth: 160)`；本地壁纸仍 `Image.file` |
| `views/chat/chat_character_info_page.dart` | 角色立绘 → `decodeWidth: 320` |
| `views/profile/profile_page.dart` / `profile_edit_page.dart` | 头像 → `CachedAppImage`（200 / 280） |
| `pubspec.yaml` | 新增直接依赖 `flutter_cache_manager: ^3.4.2`；版本 `1.0.25+26` |

**替换后 `lib/` 内 `Image.network`、裸 `NetworkImage`、`resolveAvatarImage` 均已清零**（`Image.file` 仅剩本地壁纸/背景相关 3 处，属本地文件，无网络缓存需求）。

---

## C. 缓存与降采样参数

| 项 | 值 | 代码位置 |
|---|---|---|
| 缓存管理器 | 全局单例 `CacheManager(Config('virtual_app_image_cache', stalePeriod: 30d, maxNrOfCacheObjects: 400))` | `AppImageCache.manager` |
| 磁盘目录 | 插件托管：Android `…/cache/libCachedImageData/`，iOS `Library/Caches` | 插件默认 |
| 容量 / 过期 | **400 张 / 30 天**（改常量即可配置） | `maxObjects` / `stalePeriod` |
| 缓存 key | URL trim + 去掉 `#fragment`，**不掺解码宽度** → 同一原图只存一份 | `AppImageCache.keyFor` |
| 降采样 | `round(显示宽 × DPR)`，封顶 4096px；`ResizeImage(allowUpscaling: false)` | `decodeWidthFor` + `_maybeResize` |
| 列表示例 | 411dp 宽屏、2 列、DPR 2.75：卡宽 = (411−32−12)/2 = 183.5dp → 解码 505px（原图 1368px，像素量约为原来的 1/7.3） | `CachedAppImage` 自动计算 |
| 详情/全屏 | `decodeWidth: 0` → 原图 | `character_detail_page.dart` |
| 占位 | 主题 `surfaceContainerHighest` 35%（可传卡片底色） | `CachedAppImage.placeholderColor` |
| 淡入 | **150ms** | `fadeInDuration` |
| 失败态 | 刷新图标，点击 `evict()` + `removeFile()` 后重试 | `_retry` |
| 预加载 | `lookaheadIndices(index, length, lookahead: 2)`；全局限并发 **2**；同 URL 去重；仅 http(s) | `AppImagePreloader` |
| base64 内嵌 | 解码结果 LRU 24 条，复用同一个 `Uint8List` | `_decodedDataUrls` |

---

## D. 测试与构建数据

| 项 | 结果 |
|---|---|
| `flutter analyze` | **1 issue**：`test/community_location_test.dart:12 unused_element_parameter`（与基线完全一致，无新增） |
| `flutter test test/app_image_cache_test.dart` | **12/12 通过**（keyFor 4、decodeWidthFor 4、lookaheadIndices 4） |
| `flutter test`（全量） | **269 通过 / 1 失败**：仅 `shell_status_bar_inset_test`（历史失败，布局 overflow，本次未改动其规范） |
| 出包 | `flutter build apk --release --target-platform android-arm64` → **103.0MB（107,999,865 B）**，与上一版 107,999,877 B 基本持平（+12 B 变动来自代码） |
| 版本 | `versionName=1.0.25` / `versionCode=26` / package `app.bitbear.virtual` |
| 签名 | V2 签名 `CN=Tav, OU=Dev, O=Tav, L=Beijing, ST=Beijing, C=CN`；SHA-256 `560b2ac5…5fe117` |
| `*.gguf` | APK 内 **0**；工作区 **0** |

---

## E. 真机复测点

1. **首次加载**：清数据/新装 → 首页缓慢滚动，封面应从浅色骨架过度到 150ms 淡入，不应出现「整块空白后突然蹦出」。
2. **二次打开（热启动）**：杀进程重开 → 首页/标签页/发现页图片应几乎即时出现（命中磁盘缓存），滚动无重新下载转圈。
3. **弱网**：限速/丢包 → 骨架保持稳定，失败卡片显示刷新图标，点击可重试成功。
4. **清缓存后**：系统设置清除缓存（或调试调用 `AppImageCache.clear()`）→ 再次进入应按首次加载表现，不崩溃。
5. **列表快速滚动**：连续快速滑动 10+ 屏 → 预加载并发不超过 2，不出现请求风暴或明显掉帧；内存占用不随滚动持续上涨。
6. **详情/全屏**：进入角色详情，hero 应清晰（解原图）；返回列表后列表仍清晰。
7. **本地角色卡**：导入含 base64 立绘的卡 → 反复进出角色页，立绘不应每次重新解码造成明显卡顿。

---

## F. 取舍建议（后端）

当前后端只返回原图，无 ETag、无缩略图。本次已在客户端完成**降采样 + 磁盘缓存**，首屏后不再重复下载解码。若要进一步降低首打开流量与耗时，建议后端新增 `avatar_thumb_url`（约 400px 宽 WebP/JPEG），列表读缩略图、详情读原图；无需改客户端结构，仅改 `providerFor` 的优先级。

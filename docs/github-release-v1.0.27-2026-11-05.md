# GitHub 版本补齐报告（v1.0.27）

- 日期：2026-11-05
- 仓库：`literature95/Virtual`
- 远程：`git@github.com:literature95/Virtual.git`（SSH，未改动）
- 约束：未使用破坏性 git 操作；未 force push；未写入凭据文件或 remote URL

## 一、凭据校验

| 项 | 结果 |
| --- | --- |
| 校验方式 | `GET https://api.github.com/user`，`Authorization: Bearer <token>` |
| HTTP | **200** |
| 账号 | `literature95`（用户 id `49809494`） |
| Token 展示 | `ghp_Hu****（已掩码，仅保留前 6 位）` |
| 使用方式 | 仅随命令临时传入，未写入 `.git/config`、`~/.git-credentials`、remote URL 或任何文件 |

> **提醒：本次任务已使用该 PAT，请尽快到 GitHub Settings → Developer settings 撤销/轮换。**

## 二、提交（4 组）

| # | Commit | 说明 | 文件数 |
| --- | --- | --- | --- |
| 1 | `dc9a17e` | refactor: 撤回本地模型打包与部署入口，统一二级页导航与 AppBar 规范 | 34 |
| 2 | `2c56b9a` | feat(chat): 剧情选项与继续生成、隐藏消息、限流重试与对话串行锁 | 14 |
| 3 | `886aee7` | perf(image): 统一磁盘缓存与 DPR 降采样，发现页懒加载分批渲染 | 18 |
| 4 | `3f67068` | feat(ui): 首页顶栏 4:1、标签筛选、卡片统一与批量多选，web 增加 GitHub 入口 | 19 |

合计：`85 files changed`（含删除文件与新增文档）。已核对 `HEAD~4..HEAD` 变更文件，**无 `*.gguf`、`build/`、`*.apk`、`dist/`、`node_modules`**。

### 2.1 第 1 组 `dc9a17e`（34 个文件）

- 配置 / 模型撤回：[app_feature_flags.dart](file:///d:/Documents/Desktop/Virtual/Virtual_app/lib/config/app_feature_flags.dart)、`builtin_model_service.dart`（删除）、`adapters/nobodywho_adapter.dart`、`adapters/nobodywho_adapter_stub.dart`、`local_prompt_builder.dart`
- 入口与路由：`route/app_router.dart`、`models/endpoint.dart`、`views/endpoint/endpoint_edit_page.dart`、`views/endpoint/endpoint_list_page.dart`
- 打包：`android/app/build.gradle`、`android/app/src/main/kotlin/MainActivity.kt`、`android/gradle.properties`
- 导航 / AppBar：`settings/settings_page.dart`、`asr_settings_page.dart`、`backup_page.dart`、`image_gen_settings_page.dart`、`tts_settings_page.dart`、`web_search_settings_page.dart`、`more/more_page.dart`、`debug/debug_page.dart`、`lorebook/lorebook_edit_page.dart`、`lorebook_list_page.dart`、`preset/preset_edit_page.dart`、`preset_list_page.dart`、`regex/regex_edit_page.dart`、`regex_list_page.dart`、`plugin/plugin_list_page.dart`、`theme/theme_list_page.dart`、`profile/change_password_page.dart`、`character/character_edit_page.dart`、`chat/chat_list_page.dart`、`chat/chat_background_page.dart`
- 其他：`services/api_service.dart`（本地模型上下文 + 首 token 指标）、`test/local_prompt_builder_test.dart`

### 2.2 第 2 组 `2c56b9a`（14 个文件）

- 数据与状态：`models/chat_message.dart`、`providers/chat_provider.dart`
- 对话服务：`services/prompt_service.dart`（隐藏消息进入上下文）、`retry_policy.dart`、`conversation_request_lock.dart`、`plot_option_parser.dart`、`chat_action_policy.dart`
- 适配器：`services/adapters/anthropic_adapter.dart`、`gemini_adapter.dart`、`llm_adapter.dart`、`openai_adapter.dart`
- 页面：`views/chat/chat_page.dart`（选项 / 换一批 / 继续生成）
- 测试：`test/plot_option_test.dart`、`test/upstream_retry_policy_test.dart`

### 2.3 第 3 组 `886aee7`（18 个文件）

- 图片基础：`services/app_image_cache.dart`、`views/common/cached_app_image.dart`
- 替换点 / 性能：`views/chat/chat_background.dart`、`views/discover/character_discover_feed.dart`、`discover_page.dart`、`post_detail_page.dart`、`user_profile_page.dart`、`views/home/banner_carousel.dart`、`home_page.dart`、`utils/random_order.dart`
- 跨组归入：`views/profile/profile_page.dart`、`profile_edit_page.dart`、`views/character/character_list_page.dart`（图片替换为主，导航改动随文件提交）
- 依赖与版本：`pubspec.yaml`、`pubspec.lock`（`cached_network_image` / `flutter_cache_manager`，版本 `1.0.27+28`）
- 测试与文档：`test/app_image_cache_test.dart`、`docs/image-loading-cache-report-2026-11-05.md`、`docs/discover-loading-2026-11-05-report.md`

### 2.4 第 4 组 `3f67068`（19 个文件）

- UI：`views/home/home_shell.dart`、`tag_filter_page.dart`、`tag_filter_data.dart`、`views/character/character_tab_page.dart`、`views/common/character_cover_card.dart`、`views/home/category_characters_page.dart`、`views/home/character_detail_page.dart`、`views/chat/chat_character_info_page.dart`（收藏 UI 移除）、`utils/multi_select.dart`
- 测试：`test/multi_select_test.dart`、`test/tag_filter_test.dart`、`test/shell_status_bar_inset_test.dart`
- Web：`Virtual_web/src/App.jsx`、`App.css`、`public/version.json`
- 文档：`README.md`、`Virtual_app/README.md`、`docs/ui-polish-2026-11-05-report.md`、`docs/web-github-and-release-1.0.27-2026-11-05.md`

### 2.5 分组取舍说明

- `profile_page` / `profile_edit_page` / `character_list_page`：同时含导航与图片替换，按“主要改动”归入第 3 组（图片/性能）。
- `home_page`：含分类入口 push 与图片预取，预取与降采样为主，归第 3 组。
- `chat_page`：同时含选项 UI 与图片替换，主改动是对话能力，归第 2 组。
- `character_detail_page` / `chat_character_info_page` / `category_characters_page`：收藏 UI 移除为主，归第 4 组。
- `pubspec.yaml` 的版本号随图片依赖一起进入第 3 组；未单独拆提交。
- `shell_status_bar_inset_test.dart` 原计划属第 1 组，实际暂存时遗漏，最终随第 4 组提交（**分组偏差，已无法在不改写历史的前提下调整**）。
- Web 改动与 README 无对应分组，归入第 4 组（均为 UI/文档类）。

## 三、Tag 与推送

| 项 | 结果 |
| --- | --- |
| Tag | `v1.0.27`（附注 tag，tag object `13a482e`） |
| Tag 指向 | `3f67068c9f24882e2811d1d277b97d56211df391` |
| `pubspec.yaml` | `version: 1.0.27+28` |
| `git push origin main` | `d8d3898..3f67068  main -> main` |
| `git push origin v1.0.27` | `* [new tag] v1.0.27 -> v1.0.27` |
| 远端 `refs/heads/main` | `3f67068…` |
| 远端 `refs/tags/v1.0.27^{}` | `3f67068…` |

## 四、GitHub Release

> 本机未安装 `gh` CLI（`gh --version` 不可用），因此改用 GitHub REST API 完成创建与上传；结果等价，且 token 仅随请求头临时传入。

| 项 | 值 |
| --- | --- |
| Release | `v1.0.27` — “Virtual 1.0.27” |
| Release id | `435007508` |
| 页面 | https://github.com/literature95/Virtual/releases/tag/v1.0.27 |
| Asset 名称 | `Virtual-1.0.27-arm64.apk` |
| Asset id | `712857452` |
| Asset size | **108,003,841**（与本地一致） |
| Asset state | `uploaded` |
| Asset digest | `sha256:f5d4a4595c641c45bb55e9348bc864428060e18d7a61cb45d6ed0cbd0ecb2610`（与本地一致） |
| 下载地址 | https://github.com/literature95/Virtual/releases/download/v1.0.27/Virtual-1.0.27-arm64.apk |
| 校验方式 | `GET /repos/literature95/Virtual/releases/435007508/assets`（替代 `gh release view --json assets`） |
| 上传重试 | 0 次（首次即 201） |

Release notes 为中文 Markdown，覆盖：本地模型撤回、导航/返回规范、剧情选项与继续生成、限流重试、图片缓存与降采样、发现页首屏精简、首页顶栏与标签筛选、卡片样式与批量多选、官网 GitHub 入口。

## 五、剩余未提交 / 未纳入项

| 文件 | 状态 | 原因 |
| --- | --- | --- |
| `spec.md` | 未跟踪 | 本地模型阶段的旧规划文档，与“撤回本地模型”方向不一致，未纳入发版提交 |
| `tasks.md` | 未跟踪 | 同上 |
| 本报告 | 未跟踪 | 发布完成后生成，仅作交付文档，未再追加提交 |

工作区其余文件已全部提交；无 APK、`build/`、`dist/`、`.gguf` 进入仓库。

## 六、需要人工确认的点

1. **撤销 PAT**：请立即在 GitHub 撤销/轮换 `ghp_Hu****`，本次已使用完毕。
2. **Release 文案/标题**：标题为 “Virtual 1.0.27”，如需改成 “Virtual 1.0.27+28” 可在网页端编辑。
3. **分组偏差**：`shell_status_bar_inset_test.dart` 实际落在第 4 组；若必须严格归组，需要改写已推送的历史（本次按要求未做 force push）。
4. **逐提交可构建性**：4 个提交按功能分组，拆分时未对每个中间提交单独执行 `flutter analyze/test`；最终 `HEAD` 为已验证通过的 1.0.27+28 代码。
5. **Release 与官网 APK 同源**：GitHub asset 与官网 `app-release.apk` 的 SHA-256 相同（`f5d4a459…`），可放心分发。
6. **GitHub Release 未挂版本说明以外的二进制**：仅一个 arm64 APK；未上传 ABI 分包或符号表。

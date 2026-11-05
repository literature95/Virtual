# UI 打磨批次交付报告（1.0.26+27）

日期：2026-11-05　　范围：用户 5 张截图对应的 5 处问题，未扩大改动面　　git commit / 上传：**均未执行**

---

## 一、改动位置

| # | 文件 | 改动 |
|---|---|---|
| 1 | `lib/views/home/tag_filter_page.dart` | 右上角「搜索」由渐变胶囊（图标+文字）改为**纯放大镜 `IconButton`**，`onPressed: _search` 行为不变；`IconButton` 默认 48×48 热区 |
| 2 | `lib/views/home/home_shell.dart` | `_homeTopBar` 改为 `Expanded(flex: 4)` 搜索框 + 固定 10dp 间距 + `Expanded(flex: 1)` 分类按钮（**4 : 1**）；两者高度统一 40dp；分类按钮内部图标 16、文字 13、可省略号收缩；左右不再额外留白 |
| 3 | `lib/views/common/character_cover_card.dart` | 新增 `enum CharacterCoverCardStyle { overlay, below }` 与字段 `style / selectionMode / selected / onLongPress`；`below` 布局 = 图片（圆角 14）在上 + 标题 13 + 描述 11 在图下，无深色渐变；`overlay` 保持原样（首页/搜索/发现未受影响） |
| 3 | `lib/views/character/character_tab_page.dart` | 「角色」`_ShelfView` 与「历史」`_HistoryView` 均改用 `CharacterCoverCard(style: below)`；删除旧的 `_ShelfCard` 与历史卡片菜单，**只保留一套卡片实现** |
| 4 | `lib/views/character/character_tab_page.dart` | 长按进入多选：页面级 `_selecting` + `MultiSelectState`；顶栏切换「已选 N 项」+ 全选/置顶/删除/取消；`PopScope` 拦截返回；长按菜单与 `_showMenu` 全部移除 |
| 4 | `lib/utils/multi_select.dart`（新增） | 不可变多选状态：`toggle / selectAll / clear / count / contains` |
| 5 | `lib/views/character/character_tab_page.dart` | 普通顶栏 `actions` 依次为搜索图标、`⋮`（搜索在左、⋮ 最右）；搜索 `context.push('/home/search')`，返回回角色页 |
| — | `lib/views/character/character_tab_page.dart` | 抽出顶栏构造 `_normalAppBar` / `_selectionAppBar`，`sortedConversations(...)` 纯函数（置顶优先 + 最近消息倒序） |
| — | `pubspec.yaml` | 版本 `1.0.26+27` |
| — | `README.md`（根） | 版本表更新为 1.0.26+27 |
| — | `Virtual_app/README.md` | 新增「UI 打磨批次（2026-11-05，1.0.26+27）」小节，并更新角色页 E 节的旧描述 |

---

## 二、交互说明

### 1. 标签筛选页搜索
- 只显示放大镜图标（线性圆角），无文字、无渐变圆底；点击后仍执行原有 `_search`（未选标签时提示「请至少选择一个标签」，有选则带筛选条件跳转搜索）。
- 位于 AppBar `actions` 最右，热区 48×48dp。

### 2. 首页顶栏比例
- 搜索框 : 分类按钮 = **4 : 1**（`Expanded` flex）。
- 两者高度均 40dp，基线对齐；水平内边距由 AppBar 统一 16dp，不再出现「两边各挤一块留白」。
- 分类按钮为「网格图标 + 分类」，窄屏下文字可省略但图标与小字始终可见。

### 3. 卡片统一
- 「角色」「历史」两段都是：图片（圆角）在上、名称（13/w600）与最近消息（11）在图下，**无深色渐变遮罩、无白字覆盖**。
- 首页、搜索结果、发现页仍保持原来的封面式（overlay）样式，不受影响。
- 点击行为：单选态点卡片 = 进入对话 / 继续对话；「角色」段不再保留长按小菜单。

### 4. 多选模式
- **进入**：长按任意卡片 → 顶栏切换为操作栏，该卡默认选中。
- **选中态**：图片右上角 24dp 圆圈，未选为半透明黑底白边，选中为主题色实心 + 白色对勾；点击卡片切换。
- **顶栏**：标题「已选 N 项」，右侧 `全选 / 置顶 / 删除 / 取消`。
- **全选**：选中当前分段全部条目（角色段 = 角色库全部；历史段 = 全部对话）。
- **置顶**：角色段写 `isPinned=true`；历史段 `pinConversation(id, true)`；已失效条目自动忽略，并在 SnackBar 提示「已置顶 X 项，Y 项已失效，已忽略」。
- **删除**：先弹二次确认（角色：不可恢复；对话：不可恢复），确认后批量删除并提示数量。
- **取消**：退出多选并清空选中。
- **系统返回**：`PopScope(canPop: !_selecting)` 在多选态拦截一次 → 先退出多选；再次返回才退页面。切换「角色 / 历史」分段自动退出多选。

### 5. 角色页顶栏搜索
- 右侧顺序：`搜索` → `⋮`；搜索 `push('/home/search')`，返回落在角色页；`⋮` 菜单（角色管理 / 上传角色 / 创建角色）保持不变。

---

## 三、测试与构建数据

| 项 | 结果 |
|---|---|
| `flutter analyze` | **1 warning**：`test/community_location_test.dart:12 unused_element_parameter`（与基线一致，无新增） |
| 新增单测 | `test/multi_select_test.dart` **7/7 通过**（初始空态、toggle 增删、不可变、selectAll 合并/空集/去重、clear 归零） |
| 全量测试 | `flutter test -j 1` → **276 通过 / 1 失败**；唯一失败为历史用例 `shell_status_bar_inset_test`（布局 overflow，基线既有） |
| 并行 flake | 并行 `flutter test` 偶发 `did not complete`（`world_info_binding_test` / `chat_menu_and_background_test`），单独复跑均通过，与本次改动无关 |
| 构建命令 | `flutter build apk --release --target-platform android-arm64` |
| APK | **108,004,385 B（103.0MB）**，与上一版 107,999,865 B 基本持平 |
| 版本 | `versionName=1.0.26` / `versionCode=27` / `package=app.bitbear.virtual` |
| 签名 | V2 `Verified`，`CN=Tav, OU=Dev, O=Tav, L=Beijing, ST=Beijing, C=CN` |
| `*.gguf` | APK 内 **0**，工作区 **0** |

---

## 四、真机复测点

1. **标签筛选页**：右上角只显示放大镜图标；点击在未选标签/已选标签两种情况下表现与旧版一致；热区易点。
2. **首页顶栏**：不同屏宽（360 / 411 / 平板）下，搜索框与分类按钮宽度比约 4 : 1，高度对齐，左右无多余留白；分类文字不被截成乱码。
3. **角色页「角色 / 历史」**：两段卡片均为「图片上、标题与描述下」，无深色遮罩；竖图不拉伸、标题与描述各一行省略；点击进入对话正常。
4. **多选流程**（两段都测）：
   - 长按 → 顶栏变为「已选 1 项」；再点其他卡 → 计数增加；再点已选卡 → 取消。
   - 全选 → 计数等于当前分段条目数；取消 → 回到普通顶栏。
   - 置顶 → 退出多选，列表置顶项排到最前；含失效项时出现「已忽略」提示。
   - 删除 → 二次确认；取消不删除；确认后条目消失并提示数量。
   - 多选态按系统返回 → 只退出多选；再按才退到上一页。
   - 多选态切换分段 → 自动退出多选，无残留勾选。
5. **角色页搜索**：顶栏图标顺序为「搜索、⋮」；点搜索进入搜索页，返回键回到角色页（不是回到首页）。
6. **回归**：首页封面卡 / 标签结果卡仍为原覆盖式样式；角色详情、聊天页不受影响。

---

## 五、未做事项

- 立绘背景（排队中，未动）。
- 未 git commit、未上传服务器。

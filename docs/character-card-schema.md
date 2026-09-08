# 角色卡规范与字段映射

> 建立时间：2026-09-08
> 触发事件：对照真实第三方卡片 chub.ai @cutenotlewd / Cricket（`Character Card v2`，约 1.4k tokens）
> 检视本项目角色卡管线，修复了三处「静默丢数据」缺陷。

## 一、为什么要写这份文档

角色卡不是一个「头像 + 一句话人设」的数据结构，它是**模型的全部先验**。
一轮对话里，模型能拿到的关于这个角色的信息只有 system prompt 里的这些文本。
缺失任何一块，模型会用「通用助手」的先验去填补——表现为三轮之后角色漂移（OOC）。

对照结论：

| | 成熟第三方卡片（Cricket） | 本项目旧种子数据 |
|---|---|---|
| `description` 体量 | 3,191 字符 | 约 20 字（一句话） |
| `first_mes` | 1,035 字符（含动作描写与场景） | 约 40 字 |
| `mes_example` | 1,674 字符（2 组示例对话） | 无 |
| `character_book`（世界书） | 2 条条目（地点/货币/债务） | 无 |
| `alternate_greetings` | 2 条 | 无 |

差距约 **7–10 倍**。这不是文案优劣问题，是结构性缺失。

## 二、Character Card v2/v3 → App Character 字段映射

导入入口：`Virtual_app/lib/services/character_import_service.dart`
导出入口：`Virtual_app/lib/services/character_export_service.dart`
两者构成无损回环（`import → export → import` 有回归测试覆盖）。

| CCv3 字段 | App `Character` 字段 | 备注 |
|---|---|---|
| `name` | `name` | 同时用于示例对话的说话人归属判定 |
| `nickname` | `nickname` | |
| `description` | `description` | 人设主体，也是 token 厚度的最大来源 |
| `personality` | `personality` | |
| `scenario` | `scenario` | |
| `first_mes` | `firstMessage` | |
| `avatar` | `avatarPath` | 支持外链 URL |
| `mes_example` | `exampleMessages` | **见第三节**，本项目最关键的解析器 |
| `creator_notes` | `creatorNotes` | **不自动进 prompt**，仅 `{{charCreatorNotes}}` 可用 |
| `system_prompt` | `systemPrompt` | 优先级最高，排在 system prompt 首位 |
| `post_history_instructions` | `postHistoryInstructions` | 排在最末 |
| `alternate_greetings` | `alternateGreetings` | |
| `group_only_greetings` | `groupOnlyGreetings` | |
| `tags` | `tags` | |
| `creator` / `character_version` | `creator` / `characterVersion` | |
| `creator_notes_multilingual` | `creatorNotesMultilingual` | |
| `extensions` | `extensions` | 归一化后同时写 `depthPrompt`、`sourceUrl` |
| `character_book` | `Lorebook`（独立入库，通过 `lorebookId` 关联） | **见第四节** |
| 无（本地字段） | `source` | 记录导入来源，如 `Character Card v2.0` |

### extensions 归一化规则

第三方厂商把扩展塞在 `extensions` 里，键名多为 snake_case，而 App 的 Prompt 组装层
（`prompt_service.dart`）读的是 camelCase。导入时做一次提升，两者都保留：

```
extensions.depth_prompt.depth  → extensions['depth']
extensions.chub.full_path      → extensions['sourceUrl'] = "https://chub.ai/characters/<path>"
```

原始 `depth_prompt` / `chub` / `agnai` 结构保持原样，避免导出时丢厂商信息。

## 三、`mes_example` 解析器：说话人归属

CCv2/v3 只规定「用 `<START>` 分隔示例」，**没有规定行内写法**。实测至少三种：

1. `{{user}}: …` / `{{char}}: …`（宏前缀）
2. `User: …` / `Assistant: …`（固定名）
3. `Handsome Dragonborn: …` / `Cricket: …`（任意角色名，chub.ai 与 SillyTavern 常见）

Cricket 这张卡用的是第 3 种，且**完全不含 `<START>`**，只用 `1.` `2.` 编号分隔。
旧解析器只认第 1、2 种 → 全部台词被判定为「没有说话人」→ 返回两条空消息，示例对话整段丢失。

`Character.parseMesExample(raw, {charName})` 现行规则：

| 输入 | 归属 |
|---|---|
| 说话人 == `charName`（忽略大小写/空白） | assistant 侧 |
| `{{char}}` / `char` / `assistant` / `ai` / `bot` / `model` / `system` | assistant 侧 |
| `{{user}}` / `user` / `you` / `human` / `player` | user 侧 |
| 其他任意名字（`Handsome Dragonborn`、`Potential Client`） | user 侧 |
| 行首有缩进 / 不含 `Name:` 结构 / 含 `*{}<>` 的叙述行 | 续写，归并到上一位说话人 |
| 独立序号行（`1.` `2)` `1、`） | 作为示例分界线 |

> 注意：「任意未知名字 → user 侧」是刻意选择。示例对话中出现第三方角色时，
> 从模型视角看那确实是对话的另一方。

## 四、`character_book` → Lorebook 映射

世界书承载「专有名词的定义」：地点、货币体系、组织派系、债务数额。
没有它，模型只能凭训练数据猜一个奇幻世界的物价。

| CCv3 entry 字段 | App `LorebookEntry` 字段 |
|---|---|
| `keys[]` | `keys[]`（首个同时写入 `key` 便于 UI 展示） |
| `secondary_keys[]` | `secondaryKeys[]` |
| `content` | `content` |
| `comment` | `comment` |
| `enabled` | `enabled` |
| `insertion_order` | `order` |
| `case_sensitive` | `caseSensitive` |
| `priority` | `priority` |
| `probability` | `probability` |
| `selective` | `selective` |
| `constant` | `constant` |
| `extensions.depth` | `depth` |
| `extensions.*` | `extensions`（原样保留 chub 私有字段） |
| `position` | `position`（见下方映射表） |

| CCv3 position | App position |
|---|---|
| `before_char` / `before_scenario` | `beforeSystem` |
| `after_char` | `afterSystem`（最常用） |
| `before_example` | `beforeUser` |
| `after_example` | `afterUser` |

书籍级：`scan_depth → scanDepth`、`token_budget → tokenBudget`、
`recursive_scanning → recursiveScanning`。

匹配语义（`lorebook_service.dart`）：常驻条目（`constant`）无条件注入；
主关键词任一命中即候选；`selective == true` 时次要关键词须全部命中（AND），
否则次要关键词作为补充触发器（OR）。

## 五、Prompt 组装顺序（`prompt_service.dart`）

1. `systemPrompt`（角色专属，最高优先级）
2. `description`
3. `personality`
4. `scenario`（可被会话覆盖）
5. `extensions['depthPrompt']`
6. Persona 描述
7. `postHistoryInstructions`
8. `exampleMessages` 渲染结果
9. memories / summary / override / jailbreak

**`creatorNotes` 不在此列。** 创作者备注是作者写给「人」看的元信息
（推荐采样参数、prompt 排版建议等），第三方卡片常含 `{{...}}` 宏片段或 Markdown 代码块，
直接注入会污染甚至误导模型。需要时用 `{{charCreatorNotes}}` 宏显式引用。

> 历史缺陷：旧实现中 `_extractCharInstruction()` 把 `creatorNotes` 作为兜底返回，
> 而拼装逻辑末尾又追加了一次 creatorNotes，导致同一段文本注入两次。

## 六、后端 `characters` 表 schema

列名用 snake_case（与 CCv3 一致），API 输出用 camelCase（与 App `OnlineCharacter`
解析一致），转换集中在 `Virtual_background/lib/character_card_mapper.dart`。

| 列 | 类型 | 说明 |
|---|---|---|
| `id` / `name` / `nickname` | TEXT | |
| `description` / `personality` / `scenario` | TEXT | 结构化多人设 |
| `first_message` / `greeting` / `persona` | TEXT | `greeting`/`persona` 为兼容旧字段 |
| `example_messages` | JSONB | `[{userMessage, assistantMessage}]` |
| `alternate_greetings` / `group_only_greetings` / `tags` | JSONB | |
| `system_prompt` / `post_history_instructions` / `creator_notes` | TEXT | |
| `creator` / `character_version` / `source` | TEXT | |
| `extensions` / `creator_notes_multilingual` | JSONB | |
| `avatar_url` | TEXT | 相对路径 `/avatars/*.jpg` |

增量迁移在 `lib/database/db.dart` 的 `_characterColumnMigrations`，
全部为 `ADD COLUMN IF NOT EXISTS`，可重复执行，旧库无需手工升级。

## 七、密度护栏（防回归）

`Virtual_background/test/seed_data_test.dart` 里有一条「人设密度达标」测试，
把上述结论固化成可量化的下限：

- `description` > 400 字符且含换行（必须结构化，不能是一句话）
- `personality` > 60 字符、`scenario` > 40 字符
- `first_mes` > 150 字符
- `example_messages` ≥ 2 组，每组的 assistant 回复 > 80 字符
- `alternate_greetings` ≥ 2 条

谁把种子角色改回「一句话人设」，CI 会直接失败。

## 八、参考素材

- 真实样本卡片：`docs/examples/cricket-674c71b2.json`（chub.ai @cutenotlewd / Cricket）
- 回归基线：`Virtual_app/test/fixtures/cricket_card.dart`（上者的 Dart 常量版本）
- 缺陷分析：`docs/project-analysis-2026-09-08.md`

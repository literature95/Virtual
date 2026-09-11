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

> 本节只讲 **CCv3 `character_book`**（`entries` 为数组）。独立的世界书 JSON
> 文件用的是另一套形态（SillyTavern World Info：`entries` 为对象、`disable`
> 反语义、`position` 为整数），字段映射与陷阱见**第九节** —— 两套混用会静默出错。

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

## 八、PNG 容器解析（导入传输层）

角色卡有两种投递形态：**裸 JSON** 与**内嵌 PNG**。二者承载同一份 `data`，
只是外层容器不同。PNG 形态是 SillyTavern / chub.ai 的默认导出方式，玩家手上的
卡片绝大多数是 PNG，因此容器解析不是可选功能，而是导入的主路径。

### 8.1 容器布局

角色卡写在 PNG 的**文本块**里，按规范逐块遍历即可定位：

```
PNG 签名(8B) → IHDR → [IDAT...] → tEXt / zTXt / iTXt（角色卡在此） → ... → IEND

chunk 结构：长度(4B 大端) | 类型(4B) | 数据 | CRC(4B)

tEXt 数据：keyword \0 value
zTXt 数据：keyword \0 compressionMethod(1) zlib(value)
iTXt 数据：keyword \0 compressionFlag(1) compressionMethod(1) \
           langTag \0 translatedKeyword \0 value
```

三种块**都要支持**：`tEXt` 是绝对主流（793 张真实卡片统计：`tEXt` 1567 块、
`iTXt` 5 块、`zTXt` 0 块），但 `zTXt` / `iTXt` 是规范的一部分，实现成本极低
（一次 zlib 解压），不值得为省几十行代码留下"某些卡莫名导不进来"的坑。

关键字取值集合（比较时统一转小写）：

| 关键字 | 来源 |
| --- | --- |
| `chara` | Character Card V2 / SillyTavern 约定 |
| `ccv3` | Character Card V3 约定 |
| `chara_card_v2` / `chara_card_v3` | 少数工具直接以 spec 名作关键字 |

### 8.2 值为 base64，这是最容易踩错的一点

**规范要求文本块的值是 `base64(UTF-8 JSON)`，不是原始 JSON。**
base64 字母表（`A-Za-z0-9+/=`）不含 `{` / `}`，因此**任何"把整个 PNG 当字符串
跑正则找 JSON"的实现都必然零匹配** —— 文件完好、HTTP 200，却报"未找到角色卡数据"。

解析顺序固定为：

1. 逐块遍历，取文本块关键字，命中上述集合；
2. 若为 `zTXt`，或 `iTXt` 的 `compressionFlag == 1`，先做 **zlib 解压**
   （`package:archive` 的 `ZLibDecoder`，原生端自动走 `dart:io` 的 `ZLibCodec`）；
3. 块值先补齐 `=` 填充（导出工具常省略），再做 `base64Decode`
   （同时容忍 URL-safe 字母表），最后 `utf8.decode`；
4. 非规范工具会把 JSON 直写进块值 —— 保留该分支做兼容，但**必须 UTF-8 优先**：
   按 latin1 逐字节映射也能得到"看起来合法的 JSON"，中文却全是乱码，而
   `jsonDecode` 不会报错，乱码会被静默写库。

### 8.2.1 多块命中时取 spec 更高的一份

真实卡片常**同时**写 `chara` 与 `ccv3` 两块（前者是向后兼容副本）。实测 20 张
样本两块内容完全一致，但不能依赖这一点：当二者不一致时，`chara` 里往往只有
V2 兼容字段，直接取"首个命中"会静默丢掉 V3 独有字段
（`assets` / `nickname` / `group_only_greetings` / `creator_notes_multilingual`）。

因此规则是：**收集全部命中块，取 `spec` 版本号（`chara_card_v3` > `chara_card_v2`）
最高者；版本相同则取文档顺序靠前者**。顺序相同时不做排序（Dart 的 `List.sort`
不稳定，会破坏"文档顺序优先"的语义）。

### 8.3 实现约束

- 解析器必须是**纯函数**（`lib/utils/png_card_extractor.dart`），只依赖
  `dart:typed_data` + `dart:convert` + `package:archive`：不引 `dart:io`、不引
  Flutter。这样 Web / 桌面 / 移动 / 单测共用一条路径，Web 上不会因 `File` 缺失而失败。
  `archive` 是**纯 Dart** 实现且原生端自动委托给 `dart:io` 的 `ZLibCodec`，
  因此 `lib/` 下无需任何条件导入（`if (dart.library.io)`）。
- **输入是字节，不是路径。** 入口统一为 `importBundleFromBytes(Uint8List)`；
  文件选取由 UI 层用 `file_picker` 的 `withData: true` 完成（`image_picker`
  在桌面端按后缀过滤、在 Web 端固定 `accept="image/*"`，都选不中 `.json`）。
- **畸形文件不得抛异常**：长度字段越界（下载中断）、非 PNG 签名、无文本块、
  压缩流损坏，一律返回 null 交给调用方回退，而不是中断导入流程。
- 失败提示要能区分三种情形：非 PNG 且非 JSON、PNG 但无卡片文本块（用户拖了
  插画）、有文本块但解不出。三者对用户的下一步动作完全不同。
- 兜底路径中的嵌套 JSON 必须用**花括号配平**切分，不能用 `\{[^{}]*…[^{}]*\}` ——
  CCv2/v3 包装体必然嵌套 `data` 对象，`[^{}]*` 跨不过内层花括号。

### 8.4 回归基线

`Virtual_app/test/character_png_import_test.dart` 覆盖：

| 维度 | 用例 |
| --- | --- |
| 容器 | `tEXt`、`zTXt`（压缩 base64 与压缩原始 JSON）、`iTXt`（未压缩 / `compressionFlag=1`） |
| 编码 | base64（含缺 `=` 填充）、URL-safe 字母表、非规范直写 JSON、裸 JSON、带 BOM |
| 关键字 | `chara` / `ccv3` / 大小写混杂 / 非卡片关键字（应 null） |
| 多块 | 两块内容相同（取 `chara`）、内容不同（取 spec 更高者，顺序无关） |
| 健壮性 | 空字节、<8 字节、签名不符、文件截断、压缩流损坏、纯插画 PNG 的错误文案 |

夹具由 `test/support/png_builder.dart` **在内存中构造**，不依赖二进制样本，
块类型与编码方式在用例里显式声明，便于评审。

真实卡片回归用 `Virtual_app/tool/card_png_probe.dart <目录>`：递归扫描目录下
全部 `*.png`，输出成功率、命中关键字分布与失败清单。实测 **793 张真实卡片中
783 张成功**；剩余 10 张经诊断均为**本身不含任何文本块的普通插画**
（其中 1 张还是 IDAT 中途截断的残缺文件），属正确拒绝而非解析缺口。

**Web 压缩路径的覆盖方式**：`flutter test` 跑在 VM 上，`ZLibDecoder()` 会走
`dart:io` 的 `ZLibCodec`；而 Web 上走的是 archive 的**纯 Dart inflate**，
两者是不同的实现。为让 CI 覆盖后者，`extractPngCard` 暴露了可选的
`zlibInflate` 参数，测试中传入 `ZLibDecoderWeb` 强制走纯 Dart 分支。
另有一组固化的**Python `zlib.compress` 字节**（`_pythonZlibPayload`）用于验证
纯 Dart inflate 能解开外部工具产生的流 —— 只测自家 encoder 与 decoder 自洽
是不够的，真实卡片来自第三方实现。

## 九、格式约束：角色卡 = PNG，世界书 = JSON

**这是项目级约定，不是可选实现细节。** 两条传输通道各自只有一种格式：

| 内容 | 唯一格式 | 导入入口 | 导出入口 |
| --- | --- | --- | --- |
| 角色卡 | **PNG**（内嵌 base64 CCv3 JSON） | 角色管理 → 从 PNG 卡片导入 | 角色长按 → 导出角色卡 |
| 世界书 | **JSON** | Lorebook 管理 → 从 JSON 导入 | Lorebook 条目菜单 → 导出 JSON |

理由：角色卡是「立绘 + 数据」的复合体，PNG 是唯一既能承载图像、又能承载
元数据并被各家前端一致支持的容器；世界书没有图像，JSON 就是各家的通用交换格式。

三处边界需要明确：

1. **「从 URL 导入」仍保留**，可导入 JSON 直链 —— 它是"远程获取"通道，
   本约定约束的是**本地文件**的格式。
2. **角色卡内嵌的 `character_book` 仍随卡一并导入**并落地为独立 Lorebook。
   它是卡片的一个字段，不受"世界书用 JSON"约束。
3. 选择本地文件时，选择器只开放 `png`（角色卡）/ `json`（世界书），
   把约定前移到入口，而不是等解析失败再报错。

### 9.1 PNG 写入侧（`lib/utils/png_card_writer.dart`）

写入与读取必须对称，否则会出现"写出去的卡自己都读不回来"。实现要点：

| 项 | 取值 | 原因 |
| --- | --- | --- |
| 块类型 | `tEXt` | 最通用；`zTXt` / `iTXt` 只需读取侧兼容 |
| 关键字 | `chara` **与** `ccv3` 各写一份 | 真实卡片实测全部同时写两块：SillyTavern 读 `chara`，按 CCv3 实现的前端读 `ccv3`。只写其一会让另一半前端读不到 |
| 值 | `base64(UTF-8 JSON)` | 规范要求；base64 字母表不含 `{` / `}`，若写成原始 JSON，"整包跑正则"式的解析器必然失效 |
| 实现 | `package:image` 的 `PngEncoder`（其 `Image.textData` 会自动产出 `tEXt`） | 纯 Dart，Web 与原生同一条路径；不自研 chunk 组装 + CRC32 |

**必须剥离内嵌头像**：从 PNG 导入的角色，其 `avatarPath` 是
`data:image/png;base64,…`（几十到几百 KB）。若原样写进卡 JSON，等于把同一张图
在文件里存两遍、体积翻倍，且语义重复（PNG 自身就是立绘）。导出时统一归为
`"none"` —— 这也是真实卡片的写法。

底图优先级：显式传入 > `avatarPath`（`data:` 就地解码 / `http(s)` 拉取）>
品牌色渐变占位图。**拉取失败不致命**，回落占位图：卡片主体是内嵌 JSON，
不该因为一张立绘拉不到就让整个导出失败。

**往返契约是语义级全等，不是字节级全等**：导出时 `_dropNulls` 会剥掉空字符串，
因此 `""` 与"缺字段"等价。比对必须按此口径 —— 否则每张真实卡都会刷出一屏
无意义差异（实测某张真实卡有 8 个空串字段），把真正的字段丢失淹没掉。

### 9.2 世界书 JSON：三种形态的自动识别

`LorebookImportService` 按下列顺序判定，用户无需选择：

| 判据 | 识别为 | 说明 |
| --- | --- | --- |
| `entries` 是**对象** | SillyTavern World Info | 真实世界书的主流形态（实测 221/231） |
| `entries` 是**数组**且含 `createdAt` | Virtual Lorebook | 本 App 自身导出 |
| `entries` 是**数组** | CCv3 `character_book` | 角色卡内嵌节点 |
| 含 `spec` / `data` | 角色卡 —— **拒绝** | 提示改用 PNG 入口 |
| 其他 | 拒绝 | 多为 SillyTavern 预设（`temperature` / `chat_completion_source` 等采样参数） |

失败清单须**按原因归类**输出，避免"导入成功但条目凭空少了几条"这类静默问题。
另有两处静默风险的兜底：非对象的条目会被跳过并计入提示；顶层无 `name` 时
回退到**文件名**（221 个真实文件中仅 7 个带 `name`，否则用户会看到一屏同名
"World Book"）。

### 9.3 SillyTavern World Info 字段映射

**这一节必须逐条对齐。** SillyTavern 与 CCv3 的同名字段语义不同，想当然地
照搬会产生**静默错误** —— 不是解析失败，而是世界书内容全错。

| SillyTavern | 本模型 | 陷阱 |
| --- | --- | --- |
| `key` / `keysecondary` | `keys` / `secondaryKeys` | 规范上是数组，历史上允许单个字符串；只按数组解析会丢掉触发词 |
| `disable` | `enabled`（**取反**） | 直接把 `disable` 赋给 `enabled`，会把全部条目反转成启用状态 |
| `position` 整数 `0..4` | `position` 枚举 | 见 9.4 |
| `order` | `order` | CCv3 侧对应字段名是 `insertion_order` |
| `selective` + `selectiveLogic` | `selective` | 只有 `3`（AND_ALL）等价于本模型的 `selective: true`；`0`（AND_ANY）等价于 `false`；`1` / `2` 是取反逻辑，本模型无法表达 |
| `useProbability` | — | 为 `false` 时 `probability` 必须归 100，否则条目会按概率随机失效 |
| `useRegex` | `matchStrategy` | `true` → regex |
| `constant` | `constant` | 常驻注入，忽略关键词匹配 |
| 其余（`group` / `scanDepth` / `matchWholeWords` / `sticky` / `excludeRecursion` …） | `extensions` | 原样保留，导出时回写 |

条目 `id` 由 `_nowId()` 生成，且附**进程内单调序号** —— 一次解析可能连续构造
数千个条目，只靠 `microsecondsSinceEpoch` 会撞出重复 id，导致编辑页条目互相覆盖。

### 9.4 SillyTavern `position` 整数映射

| 值 | SillyTavern | 本模型 | 实测条目数 |
| --- | --- | --- | --- |
| 0 | `before_char` | `beforeSystem` | 2158 |
| 1 | `after_char` | `afterSystem` | 2461 |
| 2 | `before_AN` | `beforeUser` | 311 |
| 3 | `after_AN` | `afterUser` | 933 |
| 4 | `at_depth` | `beforeUser`（原始深度值保留在 `extensions.depth`） | 112 |

本模型的注入管线以 system 为核心，不支持"按消息深度插入"，因此 AN 与
`at_depth` 都归到对话尾部的「用户消息之前 / 之后」。

**已知降级**：`position=4` 导出时会写成 `2`，即往返**不保持该字段原值**。
这是有意为之 —— 行为语义一致（都在用户消息前注入），但字节不再相同。

### 9.5 回归基线

| 资产 | 覆盖 |
| --- | --- |
| `test/lorebook_worldinfo_import_test.dart` | 对象 / 数组两种形态、`disable` 反语义、整数 position 全值、`selectiveLogic`、字符串 `key`、缺 `name` 回退、条目 id 唯一性、角色卡与预设的拒绝、导出往返 |
| `test/png_card_writer_test.dart` | 写入 → 读回闭环、真实卡导入导出全等、JPEG 底图、非法底图、占位图不含卡数据、data URL 头像剥离、文件名安全化 |
| `tool/lorebook_probe.dart <目录>` | 批量扫描真实世界书，输出形态分布与**按原因归类**的失败清单 |
| `tool/card_png_export_probe.dart <目录>` | 批量往返比对，输出**字段级**差异清单（可选落盘导出产物） |

真实语料实测（2026-09-11）：

- **世界书**：231 个 JSON 中 221 个解析成功（5975 条目、0 提示）；其余 10 个经
  逐文件诊断均为**非世界书**（3 类是 SillyTavern 预设、2 类是角色卡），属正确拒绝。
- **角色卡**：793 张 PNG 中 783 张成功解析，其中往返比对**零字段差异**；
  其余 10 张本身不含任何文本块（纯插画 / IDAT 截断的残缺文件）。
- **独立交叉验证**：导出产物交由 **Python 解析器**（不同语言、不同实现）复核：
  chunk 顺序 `IHDR → tEXt → tEXt → IDAT → IEND`、每个 chunk 的 **CRC32 正确**、
  base64 可解为合法 UTF-8 JSON、`spec=chara_card_v3`。
  自研读写互相自洽不算证据，故必须引入异构实现。

## 十、参考素材

- 真实样本卡片：`docs/examples/cricket-674c71b2.json`（chub.ai @cutenotlewd / Cricket）
- 回归基线：`Virtual_app/test/fixtures/cricket_card.dart`（上者的 Dart 常量版本）
- PNG 夹具构造器：`Virtual_app/test/support/png_builder.dart`
- 批量样本生成：`Virtual_app/tool/make_card_pngs.py`（产出规范 / 非规范 / 紧凑 /
  `zTXt` / `iTXt` 等容器变体到 `build/card_samples/`）
- 卡片诊断与批量回归：`Virtual_app/tool/card_png_probe.dart <文件或目录>`
  —— 传文件时打印单张卡详情，传目录时递归扫描 `*.png` 并汇报成功率与失败清单，
  用于回答"这张卡为什么导不进来"以及"改解析器有没有打破存量卡片"
- 往返比对：`Virtual_app/tool/card_png_export_probe.dart <文件或目录> [输出目录]`
  —— 解析 → 重新导出 PNG → 再解析，逐字段比对；指定输出目录可落盘，
  便于用其它语言的解析器交叉验证
- 世界书批量回归：`Virtual_app/tool/lorebook_probe.dart <文件或目录>`
- 块级取证（看某张 PNG 到底有哪些 chunk）：`Virtual_app/tool/inspect_card_png.py <文件>`
- 缺陷分析：`docs/project-analysis-2026-09-08.md`


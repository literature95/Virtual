# 角色发布协议设计（§1 数据模型 + §2 API 与上传协议）

> 建立时间：2026-09-09
> 修订依据：用真实卡样本（Cricket，CCv2，`docs/examples/cricket-674c71b2.json`）对 v1 方案做 round-trip 检验后，发现两处会丢数据的缺口，并结合 `db.dart` 现状（部分列已存在）收紧迁移范围。
> v2.1（2026-09-09 15:00）：主键定稿为复合主键（删 row_id，见 10.2-1）；上传立绘定稿落 `public/uploads/`（见 10.2-2）；§2 已编写。

## 一、目标（不变）

1. 同一角色多版本（一版本一行）
2. 角色卡与世界书一体存储
3. 兼容现有 GET 语义：App 侧 `id` 语义、解析逻辑零改动
4. **round-trip 保真**：上传 → 再导出，语义级完全一致（唯一预期差异：`avatar` 字段重写为服务器路径）

## 二、v1 → v2 修订点总览

| # | v1 原案 | v2 修订 | 原因 |
|---|---|---|---|
| M1 | 新增 `row_id` 主键、`character_id` 列 | **保留 `id` 列不动（语义 = character_id），主键改复合 `PRIMARY KEY (id, character_version)`**，不引入 row_id | 避免列改名迁移；`gen_random_uuid()` 依赖 PG13+（老库需 pgcrypto），复合主键零扩展依赖；「身份+版本」本就是天然唯一键 |
| M2 | 新增 `character_version` | **已存在**（`db.dart:70`，TEXT） | 无需迁移，只需回填 `'1.0'` 消除 NULL |
| M3 | 新增 `character_book JSONB` | 新增，且明确**原样存储**：写入/读出都不经 Lorebook 模型往返 | Cricket 卡的 entry 带 15 个字段（含 `priority`/`case_sensitive`/`probability`/`selectiveLogic`/`extensions.depth`/`characterFilter`/`excludeRecursion`…），经模型往返必丢字段 |
| M4 | 数据级 `extensions` 无落点（v1 缺口②） | **复用已有 `extensions JSONB` 列**（`db.dart:74`）存 CCv2 `data.extensions`（chub/agnai/depth_prompt） | 无需新列；`depth_prompt` 丢失会影响很多前端的行为 |
| M5 | 无 | 新增 **`raw_card JSONB`**：存上传卡 `data` 的原始整包，人设列是它的投影 | round-trip 的单一事实来源；导出直接基于它重组，天然无损。见第四节取舍 |
| M6 | UNIQUE(character_id, character_version) | **复合主键 `PRIMARY KEY (id, character_version)` 兼任唯一约束**（不再单建 UNIQUE）；建前回填 `character_version='1.0'`（PK 对 NULL 不去重） | 一石二鸟：PK 即去重键，`ON CONFLICT (id, character_version)` 直接可用 |
| M7 | 无 | 补 **round-trip 回归测试**（Cricket 卡作夹具） | 防未来改表/改 mapper 时静默丢数据 |

## 三、目标表结构

```sql
CREATE TABLE IF NOT EXISTS characters (
  id                 TEXT NOT NULL,              -- 角色身份（= v1 的 character_id；API 对外仍叫 id）
  character_version  TEXT NOT NULL DEFAULT '1.0',
  name               TEXT NOT NULL,
  -- 人设列（不变）
  description        TEXT,
  nickname           TEXT,
  personality        TEXT,
  scenario           TEXT,
  avatar_url         TEXT,                       -- 落盘相对路径 /avatars/（种子）或 /uploads/（用户上传）
  tags               JSONB DEFAULT '[]',
  greeting           TEXT,
  first_message      TEXT,
  persona            TEXT,
  example_messages   JSONB,
  system_prompt      TEXT,
  post_history_instructions TEXT,
  creator_notes      TEXT,
  creator            TEXT,
  source             TEXT,
  alternate_greetings       JSONB,
  group_only_greetings      JSONB,
  creator_notes_multilingual JSONB,
  -- v2 新增
  extensions         JSONB,                      -- CCv2 data.extensions（已有列，语义扩充）
  character_book     JSONB DEFAULT '{}'::jsonb,  -- CCv3 character_book 原样
  raw_card           JSONB,                      -- 上传卡 data 原始整包（round-trip 源）
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW(),
  -- 同身份同版本唯一：再发覆盖，换版本号新行（PK 兼任 upsert 冲突目标）
  PRIMARY KEY (id, character_version)
);
```

## 四、`raw_card` 方案取舍

| | 仅 extensions + character_book 两列 | 加 raw_card（推荐） |
|---|---|---|
| round-trip 保真 | 依赖逐字段投影逻辑，Card 规范升级时要追列 | 原包即事实，天然无损 |
| 导出实现 | 需从列重组 data | 直接 `raw_card` 改 avatar 字段即输出 |
| 存储成本 | 低 | 每行多 ~20 KB（一张卡一行的场景可忽略） |
| 查询人设列 | 直接查列 | 仍直接查列（人设列照常维护，raw_card 只是归档源） |

**采用加 `raw_card`**。写入时同时维护投影列（列表/详情查询不变）；导出时以 `raw_card` 为准。

## 五、增量迁移（追加进 `_characterColumnMigrations` + 新增 DO 块）

```sql
-- 1) 新列（ADD COLUMN IF NOT EXISTS，并入现有迁移列表）
ALTER TABLE characters ADD COLUMN IF NOT EXISTS character_book JSONB DEFAULT '{}'::jsonb;
ALTER TABLE characters ADD COLUMN IF NOT EXISTS raw_card JSONB;

-- 2) 版本回填（必须在 PK 切换之前：PK 对 NULL 不去重）
UPDATE characters SET character_version = '1.0' WHERE character_version IS NULL;

-- 3) PK 切换：旧库 PK 在 id 上 → 切到复合主键（已是复合主键的新库跳过）
DO $$
DECLARE def TEXT;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO def
    FROM pg_constraint WHERE conname = 'characters_pkey';
  IF def IS NOT NULL AND def NOT LIKE '%character_version%' THEN
    ALTER TABLE characters DROP CONSTRAINT characters_pkey;
    ALTER TABLE characters ADD PRIMARY KEY (id, character_version);
  END IF;
END $$;
```

> 注：无需单建 `UNIQUE (id, character_version)`——复合主键已兼任。也不再需要 `row_id` 与 `gen_random_uuid()`（后者依赖 PG13+ / pgcrypto，自托管场景不赌版本）。

旧种子兼容：迁移后每个种子行 `id = 原 id`、`character_version = '1.0'`、`character_book = {}`、`raw_card = NULL`（导出时 raw_card 为 NULL 则回退到「由列重组」，种子数据密度护栏测试继续生效）。

## 六、写路径：POST upsert（§2 展开，此处定协议要点）

```sql
INSERT INTO characters (id, name, character_version, description, /* …人设列… */,
                        extensions, character_book, raw_card, avatar_url)
VALUES (@id, @name, @version, /* … */)
ON CONFLICT (id, character_version) DO UPDATE SET
  name = EXCLUDED.name,
  /* …全部可变列… */
  extensions     = EXCLUDED.extensions,
  character_book = EXCLUDED.character_book,
  raw_card       = EXCLUDED.raw_card,
  avatar_url     = COALESCE(EXCLUDED.avatar_url, characters.avatar_url),  -- 未传新图则保留旧图
  updated_at     = NOW();
```

- `character_version` 默认取卡内 `data.character_version`；缺失/空时 `'1.0'`。**类型 TEXT**——实测卡内是 `"main"` 这类任意字符串。
- 立绘：multipart 的 avatar 文件落 `public/uploads/`（**上传图与种子立绘分离**，`uploads/` 进 `.gitignore` 不入库；读图走新路由 `/api/uploads/[file]` 继承 CORS，`resolveAvatarUrl` 同步把 `/uploads/` 改写为 `/api/uploads/`）；卡内原 `avatar` 值（外链）保留在 `raw_card` 里。
- **PG 不可用时：POST 直接 503**；GET 仍降级种子。

## 七、读路径（第一期）

```sql
-- 列表：按身份去重，只回最新版
SELECT DISTINCT ON (id) * FROM characters ORDER BY id, updated_at DESC;
-- 详情：按 character_id 取最新版（WHERE id = @id ORDER BY updated_at DESC LIMIT 1）
```

- JSON 输出 `id = id`（语义即 character_id），App 解析零改动。
- 详情在现有字段基础上**追加 `characterBook`**（CCv3 原样 JSON，与 App `lorebook.dart` 的 `fromCharacterBook/toCharacterBook` 双向映射兼容）与 `rawCard` 可选项（§2 定是否下发）。
- 版本历史列表第一期不做（表结构已支持）。

## 八、回归测试（M7）

新增 `Virtual_background/test/character_roundtrip_test.dart`：

1. 夹具：`docs/examples/cricket-674c71b2.json`（真实 chub 卡）
2. 断言链：上传（走 mapper 的行转换函数，纯内存即可测）→ 行数据 → 反向导出 CCv2 → 规范化 JSON（递归排序键）后 deep-diff
3. 预期：除 `avatar` 字段外全等；重点盯 `character_book.entries[*].extensions`（`characterFilter`/`excludeRecursion`/`displayIndex`）与 `data.extensions.chub/agnai/depth_prompt`
4. 该测试同时验证 M3「原样存储、不经模型往返」的约束

## 九、改动清单（代码层）

| 文件 | 改动 |
|---|---|
| `lib/database/db.dart` | 追加迁移 SQL（第五节）；新库 CREATE TABLE 换第三节结构 |
| `lib/character_card_mapper.dart` | 新增「CCv2 卡 ↔ DB 行」双向函数（含 character_book/raw_card 原样透传）；`toApiJson` 追加 `characterBook` |
| `routes/api/characters/index.dart` | 列表查询改 `DISTINCT ON (id)`；新增 POST 分支（503 门控） |
| `routes/api/characters/[id].dart` | 详情查询取最新版；输出追加 `characterBook` |
| `routes/api/uploads/[file].dart` | 新增（读 `public/uploads/`，仿 avatars 路由：扩展名白名单 + 防穿越 + CORS） |
| `lib/avatar_url.dart` | `resolveAvatarUrl` 追加 `/uploads/` → `/api/uploads/` 改写 |
| `public/.gitignore` | 追加 `uploads/` |
| `test/character_roundtrip_test.dart` | 新增（第八节） |
| `docs/character-card-schema.md` §六 | 实现落地后同步表结构说明 |

## 十、可行性核实与修订建议（2026-09-09）

用 `pub` 缓存中实际安装的 `dart_frog-1.2.6` 源码核实了 §1 的落地前提，结论：**方案可落地，无需新增任何依赖**。

### 10.1 核实结果（附证据）

| 前提 | 结论 | 证据 |
|---|---|---|
| multipart 解析 | ✅ 原生支持 | `dart_frog-1.2.6/lib/src/request.dart:168` `request.formData()`；`FormData` = `fields`(Map<String,String>) + `files`(Map<String,UploadedFile>)；`UploadedFile.readAsBytes()` / `.openRead()` |
| JSONB 参数绑定 | ✅ 已验证 | `character_card_mapper.dart` `jsonb()` 用 `jsonEncode`，路由层在用 |
| `DISTINCT ON (id)` | ✅ 可行 | 现有列表查询改造即可 |
| upsert | ✅ 可行，依赖唯一约束 | 需先建 UNIQUE(id, character_version) |
| 立绘写盘 | ✅ 低风险 | 已有 `routes/api/avatars/[file].dart` 读 + 白名单 + 防穿越，反着写即可 |

### 10.2 三个待拍板点（**已于 2026-09-09 拍板采用**，正文相应定稿）

1. **主键方案：删 row_id，改用复合主键（推荐）**
   §1 的 `row_id UUID DEFAULT gen_random_uuid()` 依赖 PG13+ 内置函数，更老版本需 `pgcrypto` 扩展——自托管场景不应赌版本。
   **改为 `PRIMARY KEY (id, character_version)`**：「身份+版本」本就是天然唯一键，少一列、少一次 PK 切换、零扩展依赖。`DISTINCT ON (id)` 不受影响。若未来要软删除/行内修订再补 row_id 不迟（YAGNI）。
   对应迁移简化：
   ```sql
   ALTER TABLE characters ADD COLUMN IF NOT EXISTS character_book JSONB DEFAULT '{}'::jsonb;
   ALTER TABLE characters ADD COLUMN IF NOT EXISTS raw_card JSONB;
   UPDATE characters SET character_version = '1.0' WHERE character_version IS NULL;
   DO $$
   DECLARE def TEXT;
   BEGIN
     SELECT pg_get_constraintdef(oid) INTO def FROM pg_constraint WHERE conname = 'characters_pkey';
     IF def IS NOT NULL AND def NOT LIKE '%character_version%' THEN
       ALTER TABLE characters DROP CONSTRAINT characters_pkey;
       ALTER TABLE characters ADD PRIMARY KEY (id, character_version);
     END IF;
   END $$;
   ```

2. **上传立绘的 git 归属**：`public/avatars/` 当前**未被 .gitignore 忽略**（仅前端产物被忽略）。
   用户每上传一张卡，立绘就进版本库。建议上传图单独落 `public/uploads/` 并加入 `.gitignore`，
   与内置种子立绘（`avatars/`）分离。

3. **multipart 字段语义**：`card` 走 `fields`（JSON 字符串，需 `jsonDecode`），`avatar` 走 `files`（二进制）。
   Dart Frog `FormData` 两者严格分离，实现时按名取，勿混。

---

# §2：API 与上传协议

> 状态：已定稿（2026-09-09）。实现以本文为准；落地后回填「实现状态」列。

## 2.1 POST /api/characters — 发布（一次打完整包）

**请求**：`Content-Type: multipart/form-data`

| 字段 | 位置 | 必填 | 说明 |
|---|---|---|---|
| `card` | form field | ✅ | CCv2/v3 完整包 JSON 字符串（`{spec, spec_version, data}`）；**兼容**直接传 `data` 对象（含 `name` 键即按 data 处理） |
| `avatar` | form file | 可选 | 图片文件；未传时沿用库内旧图（同 id+version）或卡内 `data.avatar` 外链兜底 |
| `character_id` | form field | 可选 | 覆盖角色身份；默认 App 本地 `Character.id` |
| `character_version` | form field | 可选 | 覆盖版本号；优先级：**该字段 > 卡内 `data.character_version` > `'1.0'`** |

**处理流程**（顺序固定）：

1. 鉴权（见 2.4）→ 401
2. `db.isAvailable` 检查 → 不可用 **503**（内存种子不能持久化上传）
3. `jsonDecode(fields['card'])` → 取 `data`（或识别为 data 本体）→ 校验 `name` 非空 → 400
4. 版本决策（上表优先级）
5. 立绘落盘（若 `files['avatar']` 存在）：
   - content-type 白名单：`image/jpeg→.jpg`、`image/png→.png`、`image/webp→.webp`、`image/gif→.gif`，其余 **415**
   - 文件名：`char-<id>-<version>.<ext>`，`id`/`version` 先 sanitize（`[^A-Za-z0-9_-]` → `_`）；**不信任客户端文件名**；同 (id,version) 重传 = 覆盖，与 upsert 语义一致
   - 写 `public/uploads/`；先写盘后入库（写盘失败即 500 不入库；极端情况 upsert 失败留孤儿文件，可接受，注释说明）
6. upsert（§1 第六节 SQL，冲突目标 `(id, character_version)`）
7. 返回 201（新建）/ 200（覆盖）

**成功响应体**：

```json
{
  "id": "cricket-674c71b2",
  "characterVersion": "main",
  "avatarUrl": "http://localhost:8080/api/uploads/char-cricket-674c71b2-main.jpg",
  "action": "created"
}
```

`action` ∈ `created` | `updated`。`avatarUrl` 为绝对 URL（经 `resolveAvatarUrl`），App 直接可用。

**错误码**：

| 码 | 条件 |
|---|---|
| 400 | `card` 缺失 / JSON 非法 / `name` 缺失 |
| 401 | 配置了 PUBLISH_TOKEN 且不匹配 |
| 413 | avatar > 10 MB（防滥用上限） |
| 415 | avatar 类型不在白名单 |
| 503 | PG 不可用 |
| 500 | 写盘/其他未预期错误 |

**`avatarUrl` 输出合成规则**（读接口通用）：

```
落盘图存在（avatar_url 非空）→ resolveAvatarUrl(avatar_url)   // /uploads/ 或 /avatars/ → 绝对 URL
否则卡内 data.avatar 是 http(s) 外链      → 原样透传          // App CachedNetworkImage 本就支持外链
否则                                       → null（App 显示占位）
```

外链**不做服务端抓取下载**（避免 SSRF 与网络依赖），原值始终保留在 `raw_card.avatar`，导出时还原。

## 2.2 读接口（定稿）

| 端点 | 语义 |
|---|---|
| `GET /api/characters` | `SELECT DISTINCT ON (id) * … ORDER BY id, updated_at DESC`；输出 `toSummaryJson`（不变），`id` 语义 = character_id |
| `GET /api/characters/:id` | 最新版详情；在现有字段基础上**追加 `characterBook`**（值 = CCv3 原样 JSON）。`rawCard` **不下发**（体积大且 App 无消费方；导出走 2.3） |
| PG 不可用 | 两者降级种子（现状不变）；种子的 `characterBook` 为空对象 |

## 2.3 GET /api/characters/:id/export — 导出（round-trip 承诺的兑现端点）

- 响应：`application/json` + `Content-Disposition: attachment; filename="<id>.json"`
- body = 完整 CCv2 包：`{spec: "chara_card_v2", spec_version: "2.0", data: …}`
- `data` 来源：`raw_card` 非空 → **原样吐回**（唯一改写：`avatar` 字段保留原值，即上传时的外链）；`raw_card` 为 NULL（旧种子）→ 由人设列 + character_book 重组（与 App 导出服务同一套重组规则）
- PG 不可用时种子角色也可导出（列重组路径），但仅限 `id` 命中种子
- 该端点是 §1 第八节 round-trip 测试的线上形态；实现很薄（raw_card + spec 包装），第一期一起做

## 2.4 鉴权（第一期最小方案）

- 后端现状无鉴权（已知债务 R1，CORS `*`）。POST 是首个写接口，加**可选** token：
  - 启动时 `--dart-define=PUBLISH_TOKEN=<值>` 注入（复用 R3 的 `String.fromEnvironment` 模式）
  - **未配置 = 不校验**（本地开发零门槛，与现有开放度一致）
  - 配置了则要求请求头 `X-Api-Token` 匹配，否则 401
- 不引入用户体系（与「本地优先 / 自托管」定位一致）

## 2.5 边界与非目标（第一期）

- **App 发布 UI**：属 App 侧新功能，另立任务；本期 API 先行，可用 curl / 任意 HTTP 客户端验证
- **版本历史列表接口**：不做（表已支持，后加是纯查询）
- **外链立绘服务端化**：不做（SSRF/网络依赖，见 2.1 合成规则）
- **删除接口**：不做（避免误删；需要时后续加 `DELETE /api/characters/:id/:version`）

## 2.6 实现顺序（TDD）

1. `character_card_mapper.dart`：卡 ↔ 行双向函数 + round-trip 纯内存测试（Cricket 夹具）→ **先红后绿**
2. `db.dart` 迁移 + 复合主键
3. `index.dart` POST 分支（503 门控、版本决策、错误码）
4. 立绘落盘 + `/api/uploads/` 路由 + `avatar_url.dart` 改写（沿用 avatar_url_test 模式补测试）
5. 详情 `characterBook` + 导出端点
6. 收尾：`docs/character-card-schema.md` §六 同步、README 接口清单更新

---

## 三、实现结果（2026-09-10 完成并实现端到端验证）

### 3.1 落地清单

| 文件 | 状态 |
|---|---|
| `lib/character_card_mapper.dart` | 新增 `cardToRow` / `rowToExportData` / `exportEnvelope` / `normalizeCardJson` / `sanitizeFilename` / `canonicalJson` |
| `lib/mes_example_parser.dart` | 新增（App `Character.parseMesExample` 规则的后端移植：`{{user}}:` / `User:` / 任意角色名前缀 + `1.` 编号分界） |
| `lib/database/db.dart` | 新列 `character_book` / `raw_card`；回填 `character_version='1.0'`；PK 切复合键 `(id, character_version)`；**空库启动自动灌种子** |
| `lib/database/seed.dart` | upsert 冲突目标改复合键；`Sql.named` 修正（见 3.3） |
| `routes/api/characters/index.dart` | 列表改 `DISTINCT ON (id)`；新增 POST multipart 发布 |
| `routes/api/characters/[id].dart` | 取最新版；追加 `characterBook` |
| `routes/api/characters/[id]/export.dart` | 新增导出端点 |
| `routes/api/uploads/[file].dart` | 新增上传立绘读路由（继承 CORS） |
| `lib/avatar_url.dart` | `/uploads/` 一并改写为 `/api/uploads/` |
| `test/character_roundtrip_test.dart` + `test/fixtures/cricket_card_v2.json` | 新增 12 个用例（含上传→导出语义全等） |

### 3.2 端到端验证结果（PostgreSQL 18.1 实机）

| 验证项 | 结果 |
|---|---|
| POST 上传 Cricket 卡 + 立绘 | 201 `{"action":"created"}`；立绘落 `public/uploads/char-cricket-main.jpg` |
| 同版本重传 | 200 `action:"updated"` |
| 换版本号重传 | 201 `action:"created"`，旧版本行保留 |
| 未传立绘文件 | 回退卡内 `avatar` 外链（不抓取，防 SSRF） |
| **上传 → 导出 round-trip** | **`data` 层 16 字段全等，0 差异**；`spec` / `spec_version` 一致 |
| 详情 `characterBook` | 世界书 2 entries、entry 16 字段原样保留 |
| 种子导出（无 raw_card） | 列重组路径 19 字段，200 |
| 立绘访问 | `GET /api/uploads/char-cricket-main.jpg` → 200 `image/jpeg` |
| 错误码 | 缺 card→400、非 multipart→400、非法图片类型→415、角色不存在→404 |
| 静态分析 / 测试 | `dart analyze` 0 issues；`dart test` 24 全绿 |

### 3.3 实现期发现并修复的 4 个缺陷

1. **`postgres` 3.5 驱动 `execute(String, parameters:)` 不解析 `@命名参数`** —— 必须用 `Sql.named(...)` 包裹，否则整个 parameters Map 被当作单值、抛
   `Maps are only supported by Sql.named`。**该问题此前一直存在**：`seed.dart` 的 upsert 从未真正写入，异常被 `catch` 静默吞掉，表现为「PG 连上了但列表是空的」。
   现已全部改为 `Sql.named`（`index.dart` / `seed.dart` / `[id].dart` / `export.dart`）。
2. **`writeToDb()` 从未被调用** —— 种子只作为内存降级数据存在，PG 可用时表是空的（此前 PG 一直不可用，问题被掩盖）。
   现 `AppDatabase.init()` 在 `characters` 表为空时延迟导入并灌入种子（用户已上传过角色则不再灌，避免复活已删数据）。
3. **JSONB 列取值不能先 `toString()`** —— 驱动对 jsonb 返回的已是 `Map`，`toString()` 得到 Dart 风格字符串（键无引号），
   再 `jsonDecode` 必然失败 → 世界书被静默置空为 `{}`。详情路由已改为原样透传 + `decodeJson` 归一化，并补单元测试守住。
4. **未传立绘时 `avatarUrl` 为 null** —— 未按 §2.1 回退卡内外链；已修（落盘图 > 卡内外链 > null）。

### 3.4 环境事实（本机）

- PostgreSQL 18.1 在线，但 **`virtual` 库此前不存在**（只有 postgres / qmjy / novelist 等）。
  库不存在时驱动报 `FormatException: Missing extension byte`，比「库不存在」的语义难辨认 —— 已建库（UTF8）。
  这也是后端长期静默降级内存的真正原因（不是连不上，是库不存在）。

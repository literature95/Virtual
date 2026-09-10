# virtual_background

[![style: dart frog lint][dart_frog_lint_badge]][dart_frog_lint_link]
[![License: MIT][license_badge]][license_link]
[![Powered by Dart Frog](https://img.shields.io/endpoint?url=https://tinyurl.com/dartfrog-badge)](https://dart-frog.dev)

An example application built with dart_frog

## 接口一览

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/health` | 健康检查 |
| GET | `/api/app-info` | 客户端版本 / 更新信息 |
| GET | `/api/metadata` | 客户端元信息 |
| GET | `/api/characters` | 在线角色卡列表（省略 `mes_example` 等重字段） |
| GET | `/api/characters/:id` | 角色卡详情（完整人设 / 示例对话 / 世界书） |
| POST | `/api/characters` | 发布/导入角色卡（multipart：`card` + 可选 `avatar`），CCv2/v3 均可，需 PostgreSQL |
| GET | `/api/characters/:id/export` | 导出完整 CCv2 spec 包（`raw_card` 原样 round-trip） |
| GET | `/api/banners` | 首页轮播位（横版图 + 关联角色 ID） |
| GET | `/avatars/:file` | 本地立绘静态资源；扩展名白名单 + 路径穿越防护 |
| GET | `/uploads/:file` | 发布时上传的立绘静态资源 |

> 未安装 PostgreSQL 时自动降级到 `lib/database/seed.dart` 内存种子，
> 上述 GET `/api/*` 全部照常可用；但 **POST 发布接口在无 PG 时返回 503**
>（内存种子无法持久化）。`/avatars/*`、`/uploads/*` 始终读磁盘文件。

### 角色卡导入 / 发布（CCv2 / CCv3）

`POST /api/characters` 接收 `multipart/form-data`（协议细节见
[`docs/character-publish-design.md`](../docs/character-publish-design.md) §2）：

- `card`（form 字段，必填）：Character Card 完整 spec 包
  `{spec, spec_version, data}` 或裸 `data` 的 JSON 字符串，v2/v3 均收
- `avatar`（form 文件，可选）：立绘，jpeg/png/webp/gif，≤10MB，落
  `public/uploads/`；不传则回退卡内 `avatar` 外链（原样透传，服务端不抓取）
- `character_id` / `character_version`（form 字段，可选）：覆盖身份/版本；
  版本优先级 = 请求字段 > 卡内 `character_version` > `1.0`
- 同 `(id, character_version)` 重复上传 = 覆盖（upsert），换版本号 = 新行
- `data` 原样存入 `raw_card` JSONB 作为唯一事实来源，`character_book` /
  `extensions` 等各存 JSONB 列；导出时原样吐回，语义级无损

命令行示例（PowerShell / curl.exe）：

```powershell
curl.exe -X POST -F "card=<D:\path\to\card_spec_v2.json" http://localhost:8080/api/characters
# 带立绘：
curl.exe -X POST -F "card=<card.json>" -F "avatar=@avatar.png" http://localhost:8080/api/characters
```

已验证：chub.ai 真实卡 `main_cricket-674c71b2_spec_v2.json`（Cricket，
含 character_book 世界书、chub/agnai/depth_prompt 扩展）可直接导入，
导入后 `id=cricket`、`version=main`，导出包与源文件字段一致
（契约测试 `test/character_roundtrip_test.dart`，18 项全过）。

### /api/banners

数据源是常量 [`lib/banner_seed.dart`](lib/banner_seed.dart) —— 运营位数据量小、
没有用户数据，因此不建表。**必须配横版图**：轮播是横幅构图，正好复用 16:9 的
`char-00X.jpg` 角色立绘原图（同一批素材塞进 0.62 的竖版封面卡会被裁掉大半）。

`imageUrl` 以相对路径 `/avatars/xxx.jpg` 存储，响应时由 `lib/avatar_url.dart`
按**请求来源**补全为绝对 URL —— App / Web 端零改动，真机调试自动适配局域网 IP。

[dart_frog_lint_badge]: https://img.shields.io/badge/style-dart_frog_lint-1DF9D2.svg
[dart_frog_lint_link]: https://pub.dev/packages/dart_frog_lint
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
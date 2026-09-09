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
| GET | `/api/banners` | 首页轮播位（横版图 + 关联角色 ID） |
| GET | `/avatars/:file` | 本地立绘静态资源；扩展名白名单 + 路径穿越防护 |

> 未安装 PostgreSQL 时自动降级到 `lib/database/seed.dart` 内存种子，
> 上述 `/api/*` 全部照常可用；`/avatars/*` 始终读 `public/avatars/` 磁盘文件。

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
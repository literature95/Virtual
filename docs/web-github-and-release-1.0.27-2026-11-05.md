# Web GitHub 入口 + 1.0.27+28 线上发布报告

- 日期：2026-11-05
- 范围：官网顶栏 GitHub 图标、线上 APK / version.json 发布、只读校验
- 约束：未 `git commit`、未上传 GitHub Release；服务器只做本次发布所需写操作

## 一、Web 改动位置

| 文件 | 位置 | 改动 |
| --- | --- | --- |
| `Virtual_web/src/App.jsx` | 顶栏 `.nav-right`（约 46-75 行） | 新增 `.nav-actions` 容器：GitHub 图标在左、「下载 App」在右，同一行相邻 |
| `Virtual_web/src/App.css` | `.nav-right` 之后（约 148-172 行） | 新增 `.nav-actions` / `.nav-github` 样式；560px 以下收紧间距 |
| `Virtual_web/public/version.json` | 全文 | 版本改为 `1.0.27+28`，notes/changes 换成本次真实改动 |

交互与规范：

- GitHub 图标为**内联 SVG**（18×18，`fill: currentColor`），单色，跟随主题文字色；hover 时提亮 + 轻微紫色光晕，`focus-visible` 有 2px 紫色描边。
- 无文字标签，无边框圆角块（32×32，圆角 10px），视觉权重低于渐变描边的「下载 App」。
- 链接：`https://github.com/literature95/Virtual`，`target="_blank"` + `rel="noopener noreferrer"`。
- 无障碍：`aria-label="GitHub 仓库"`、`title="GitHub 仓库"`，SVG `aria-hidden="true"` + `focusable="false"`。
- 窄屏：≤560px 时隐藏「首页 / 角色卡」文字链接，GitHub 图标与下载按钮仍保留，间距 6px，不换行、不遮挡。

构建产物：`dist/assets/index-DhoLSyPq.js`、`dist/assets/index-DWdIzpcE.css`、`dist/index.html`、`dist/version.json`。

## 二、发布步骤与校验数据

### 2.1 本地 APK 基线

| 项 | 值 |
| --- | --- |
| 路径 | `Virtual_app/build/app/outputs/flutter-apk/app-release.apk` |
| 字节数 | **108,003,841 B**（约 103.0 MiB） |
| SHA-256 | `f5d4a4595c641c45bb55e9348bc864428060e18d7a61cb45d6ed0cbd0ecb2610` |
| 包名 / 版本 | `app.bitbear.virtual` / `versionCode=28`、`versionName=1.0.27` |

> 上传前重新用 `Get-FileHash -Algorithm SHA256` 计算，并以该值作为本次发布基准。

### 2.2 步骤

1. `df -h /` 确认：`40G` 总量、`22G` 已用、`16G` 可用（59%）。
2. 备份线上旧包与版本文件：
   - `app-release.apk` → `app-release.apk.bak-20261105165818`（596,004,902 B）
   - `version.json` → `version.json.bak-20261105165818`（354 B）
3. `scp` 上传本地 APK 到 `app-release.apk.new`（不直接覆盖线上文件）。
4. 服务器端校验 `stat -c %s` 与 `sha256sum`，与本地一致后才替换。
5. `chmod 644 app-release.apk.new` → `mv -f` 原子替换 → `chmod 644 app-release.apk`。
6. Web：`npm run build`（Vite 8.2.2，993ms，29 modules）→ 先传新 `assets/index-*.js|css`，再传 `index.html` 与 `version.json`。仅上传指定文件，未触碰 `app-release.apk`。
7. 只读复核（见 2.4）。

### 2.3 version.json 本次文案

```json
{
  "version": "1.0.27+28",
  "downloadUrl": "https://virtual.literature95.com/app-release.apk",
  "notes": "1.0.27+28：本地模型入口下线、返回键与 AppBar 统一、剧情选项/继续生成、限流重试、图片缓存降采样、发现页首屏精简、首页顶栏与卡片多选",
  "changes": [
    "撤回本地 GGUF 模型打包与部署入口，仅保留云端接入型端点",
    "统一二级页面返回键与 AppBar 规范，返回不再直接退出 App",
    "聊天新增「生成选项 / 换一批 / 继续生成」，支持剧情分支",
    "上游限流（429/5xx）按 Retry-After 退避重试，同一对话串行请求",
    "图片统一磁盘缓存 + 按屏宽 DPR 降采样，首屏骨架与淡入",
    "发现页首屏只发 1 个请求，预取下一张、首批 12 张分批渲染",
    "首页顶栏搜索/分类 4:1 布局、左右留白 5dp，标签筛选页搜索改图标",
    "角色页与历史卡样式统一，长按进入批量置顶/删除多选"
  ]
}
```

### 2.4 校验结果（全部通过）

| 校验 | 结果 |
| --- | --- |
| `curl -I /app-release.apk` | `HTTP/1.1 200 OK`，`Content-Length: 108003841`，`Content-Type: application/octet-stream`，`Accept-Ranges: bytes`，`ETag: "6aec4586-6700201"` |
| 远端 `sha256sum app-release.apk` | `f5d4a4595c641c45bb55e9348bc864428060e18d7a61cb45d6ed0cbd0ecb2610`（与本地一致） |
| 远端字节数 | `108003841`（与本地一致） |
| `GET /version.json` | `version: "1.0.27+28"`，notes/changes 为本次文案 |
| APK 首 1KB（Range 0-1023） | 长度 1024，magic `50 4B 03 04`（`PK\x03\x04`），非 SPA 回退的 index.html |
| 线上首页引用资源 | `index-DhoLSyPq.js`、`index-DWdIzpcE.css`（均为新产物） |
| 线上 JS 中 grep 仓库地址 | 命中 `https://github.com/literature95/Virtual`，并包含 `noopener noreferrer` |
| 发布后 `df -h /` | `40G` 总量、`23G` 已用、**`16G` 可用**（60%） |

## 三、备份文件清单（`/var/www/virtual/dist/`）

| 文件 | 字节数 | 说明 |
| --- | --- | --- |
| `app-release.apk` | 108,003,841 | 本次发布的 1.0.27+28 |
| `app-release.apk.bak-20261105165818` | 596,004,902 | 发布前线上旧包（保留 1 份） |
| `app-release.apk.bak-20260921181742` | 51,314,412 | 更早历史备份（49M） |
| `app-release-1.0.16.apk` | 51,312,536 | 1.0.16 命名包（历史留存） |
| `version.json` | 1,007 | 本次新版本信息 |
| `version.json.bak-20261105165818` | 354 | 发布前版本文件 |
| `version.json.bak` | 354 | 9 月历史备份 |

> 备份轮转：仅保留 1 份 569M 级旧包，未累积多份；`16G` 可用空间充足。
> 过程中曾因 PowerShell 转义生成两个带尾部空格的误建备份（`app-release.apk.bak- ` / `version.json.bak- `），已删除，不计入清单。

## 四、已做 / 未做

### 已做

- Web 顶栏 GitHub 图标入口（桌面 + 窄屏），构建并推送新 `assets` / `index.html` / `version.json`。
- 线上 APK 备份 → `.new` 上传 → 字节数 + SHA-256 双向校验 → 原子替换 → `chmod 644`。
- `version.json` 更新为 `1.0.27+28`，文案覆盖本批全部移动端改动。
- 全部只读校验项通过；记录发布后磁盘余量。
- README 同步：发版说明中的 APK 体积/本地模型描述、官网已实现项新增 GitHub 入口。

### 未做

- 未 `git commit`，未推送 GitHub，未更新 GitHub Release（Release 仍停留在旧 tag）。
- 未把 103MB APK 加入 git（见下）。
- 未部署后端（本次无后端改动）。
- 未做浏览器像素级走查（仅构建产物与线上 JS grep 验证）。

### APK 是否入库的取舍

- `Virtual_web/.gitignore` 已包含 `public/app-release.apk`，`dist` 也在忽略列表；`git check-ignore` 已确认生效。
- 因此仓库不承载 103MB 二进制；发布走「本地构建产物 → scp 到服务器 `/var/www/virtual/dist/`」。
- 现有 `deploy/deploy_apk.sh` 会把 APK 复制到 `Virtual_web/public/`（仍被 gitignore），并同步服务器；本机 `public/app-release.apk` 仍是 51MB 旧包，但该文件不会进入 git，也不影响线上（线上已直接替换）。
- 取舍原因：避免仓库膨胀与每次 clone 变慢；代价是部署必须依赖构建机 + 服务器直传，不能仅靠 git 拉取产物。

## 五、需要人工确认的点

1. **视觉走查**：请用桌面与 320–390px 窄屏打开 https://virtual.literature95.com 确认 GitHub 图标与「下载 App」不换行、不遮挡，hover/focus 效果符合预期。
2. **GitHub Release 是否同步**：官网已发 1.0.27+28，但 GitHub Release 最新仍是旧 tag；如需对外统一，需要另行执行 Release 上传（本次未做）。
3. **版本文案**：`notes/changes` 为概括性描述，如需更产品化措辞可在下次发布前调整。
4. **备份策略**：当前保留 1 份 569M 旧包 + 2 份 49M 历史包；如后续继续发版，建议沿用「只留最近 1 份大包」。
5. **CDN / 缓存**：若站点前置 CDN，需确认 `app-release.apk` 与 `version.json` 已刷新缓存；源站 nginx 当前返回 200 且内容已更新。

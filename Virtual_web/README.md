# Virtual_web

Virtual 官网与角色卡浏览站（React + Vite），生产地址 https://virtual.literature95.com 。

本目录只负责 Web 端；App（`Virtual_app`）与后端（`Virtual_background`）见仓库根 `README.md`。

## 技术栈

| 项 | 值 |
|---|---|
| React | 19 |
| Vite | 8（`@vitejs/plugin-react`） |
| 路由 | `react-router-dom` 7 |
| 代码检查 | oxlint |
| 开发端口 | `5173`（`/api` 代理到后端 `http://localhost:8080`） |

## 页面与目录

```text
src/
  App.jsx            # 应用壳：顶栏（GitHub 图标 + 「下载 App」按钮）、路由出口
  App.css            # 深空设计系统（近黑 #0e0e0e + 三色渐变 + 玻璃拟态）
  main.jsx           # 入口
  api/client.js      # 后端 API 封装
  lib/charaCard.js   # 角色卡解析/导出复用逻辑
  pages/
    Home.jsx         # 首页：Hero + 角色卡预览 + 应用介绍
    Characters.jsx   # 角色卡浏览页（后端 /api/characters + 详情弹窗）
  assets/            # 品牌图标、hero 图等静态资源
```

顶栏右上角除「下载 App」（`/app-release.apk`）外，左侧相邻的 **GitHub 图标**为内联 SVG，
链接 `https://github.com/literature95/Virtual`，`target="_blank"` + `rel="noopener noreferrer"`，
`aria-label="GitHub 仓库"`；窄屏同样可见，不抢「下载 App」的视觉权重。

## 本地开发

```bash
npm install
npm run dev     # http://localhost:5173（已代理 /api → :8080）
npm run build   # 产出 dist/
npm run preview
npm run lint    # oxlint
```

后端未启动时，首页/角色页的数据请求会失败，页面外壳与「下载 App」仍可正常打开（角色区暂无内容）。

## 版本与发布

- `public/version.json` 是官网的版本/更新说明来源，**必须与 `Virtual_app/pubspec.yaml` 的 `version` 一致**（当前 `1.0.27+28`）。
- `public/app-release.apk` 不入库（见 `Virtual_web/.gitignore`），由部署脚本从构建产物同步；`dist/app-release.apk` 同样不入库。
- 部署静态站：在仓库根执行 `bash deploy/push_web_dist.sh`。脚本会排除本地 `app-release.apk`、清空远端 `dist`（保留线上 APK 与备份）后再上传，避免 Web 构建覆盖正在分发的安装包。
- 完整发版流程（升版本 → 测试 → 构建 APK → 部署静态站 → tag/Release）见根 `README.md`「发版流程」。

## 注意事项

- 站点是 SPA，nginx 对不存在的路径会 `try_files` 回退到 `index.html` 并返回 **200**；确认线上文件是否存在必须比对内容哈希，不能只看状态码。
- 线上 `app-release.apk` 与 `version.json` 是用户实际下载/更新的依据，发布后需核对字节数与 SHA256。

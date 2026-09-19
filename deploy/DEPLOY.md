# Virtual 服务器部署指南（后端 + Web）

> 适用场景：单台 Linux 服务器，已安装 PostgreSQL（`postgres` / `1234`，监听 `127.0.0.1:5433`）。
> 对外仅暴露 **443**，后端 8080 与 PG 5433 全部仅在服务器内网回环，靠防火墙封死公网。

## 端口总览（最终落地）

| 进程 | 监听地址 | 对外公网 | 说明 |
|---|---|---|---|
| **nginx** | `0.0.0.0:443` + `:80`(跳转) | ✅ 唯一公网入口 | 托管 `/var/www/virtual/dist` 静态站 + 反代 `/api` |
| **Virtual_background** | `127.0.0.1:8080` | ❌ | 仅被本机 nginx 调用 |
| **PostgreSQL** | `127.0.0.1:5433` | ❌ | 仅被本机后端调用 |

> 静态网站（Virtual_web 的 `dist/`）**没有独立端口**，它由 nginx 在 443 上直接读文件发出。

## 一、准备数据库

服务器 PG 已就绪，凭据 `postgres` / `1234`，**端口 5433**（非默认 5432）。后端按 `DB_*` 环境变量连接。

```bash
# 建库（若不存在）
psql -U postgres -h 127.0.0.1 -p 5433 -c "CREATE DATABASE virtual;"
# 确认监听回环（postgresql.conf）
# listen_addresses = 'localhost'   # 默认即 127.0.0.1，切勿改 '0.0.0.0'
```

> ⚠️ **安全提醒**：`1234` 是弱密码。请尽快改为强密码，并同步更新 `deploy/backend.env` 的
> `DB_PASSWORD`。若 PG 暴露在公网口令暴力破解风险极高。

## 二、构建并运行后端（Virtual_background）

```bash
cd Virtual_background
dart pub get
dart_frog build                       # 生成 build/bin/server.dart

# 加载运行环境变量（含 DB 凭据）
set -a; source ../deploy/backend.env; set +a
# ① 先生成固定 JWT_SECRET：
#   export JWT_SECRET=$(openssl rand -hex 32)

# 运行（解释型，省去编译步骤）
dart build/bin/server.dart
# 或编译为原生可执行（更省内存，推荐生产）：
#   dart compile exe build/bin/server.dart -o build/bin/server
#   ./build/bin/server
```

后端启动后应监听 `0.0.0.0:8080`（Dart Frog 默认）。因只被同机 nginx 访问，
**防火墙必须 DROP 8080 入站**（见第五节）。

## 三、构建 Web 静态站（Virtual_web）

```bash
cd Virtual_web
npm ci
npm run build                        # 产物在 dist/
sudo mkdir -p /var/www/virtual/dist
sudo cp -r dist/* /var/www/virtual/dist/
```

> 生产构建**不含** `vite.config.js` 里的 `/api` dev 代理，靠 nginx 反代 `/api` 解决，
> 因此构建时**不需要**设 `VITE_API_BASE`。

## 三之二、部署 App 的 release APK（用脚本，别手动）

App 分发包存在于**三处**，必须保持同步，否则用户下载到的仍是旧版本：

| 位置 | 角色 |
|---|---|
| `Virtual_app/build/app/outputs/flutter-apk/app-release.apk` | 构建产物（**唯一真源**，附 `.sha1`） |
| `Virtual_web/public/app-release.apk` | Vite 源，`npm run build` 时进入 `dist/` |
| `/var/www/virtual/dist/app-release.apk` | nginx 实际对外提供的文件 |

**一键同步（推荐）**：

```bash
cd Virtual_app && flutter build apk --release
cd .. && bash deploy/deploy_apk.sh
```

脚本会依次完成：本地 `.sha1` 自检 → 同步 Web 源 → 上传到服务器 `.new` → 服务器端哈希比对 →
**备份轮转** → 原子替换 → 下载线上文件比对哈希。任一步失败即中止，不会留下半成品。

- `--no-web`：只更新线上，跳过 Web 源同步。
- 环境变量 `VIRTUAL_KEEP_APK_BACKUPS`（默认 `1`）：保留最近几个备份，`0` 表示不留。

> 🔴 **备份必须轮转**：单个 APK 约 49MB，每次部署留一份备份会快速累积占满磁盘。
> 脚本已固化「只留最近 1 份」，请勿手动 `cp` 出无限制的备份。

> 🔴 **验证要用哈希，不能用状态码**：站点是 SPA，nginx 对不存在的路径会
> `try_files` 回退到 `index.html` 并返回 **200**。因此「URL 返回 200」**不能**证明
> 文件存在（曾据此误判"备份没删掉"）。判据必须是下载内容与本地构建的 sha1 一致。
> 注意 Git Bash 下不要用 `mktemp`/`-o` 临时文件路径（会被路径转换破坏），
> 直接用管道 `curl ... | sha1sum`。

## 四、配置并启动 nginx

域名已确认为 **virtual.literature95.com**，SSL 证书自备（仓库 `ssl/` 文件夹：
`virtual.literature95.com.pem` + `virtual.literature95.com.key`）。`nginx.conf` 中的
`server_name` 与证书路径**已改为真实值，无需再手动改**。

1. 先把自备证书上传到服务器（私钥权限务必收紧）：
   ```bash
   sudo mkdir -p /etc/nginx/ssl/virtual
   sudo cp "ssl/virtual.literature95.com.pem" /etc/nginx/ssl/virtual/
   sudo cp "ssl/virtual.literature95.com.key" /etc/nginx/ssl/virtual/
   sudo chmod 600 /etc/nginx/ssl/virtual/virtual.literature95.com.key
   ```
2. 把 `deploy/nginx.conf` 放到站点目录：
   ```bash
   sudo cp deploy/nginx.conf /etc/nginx/sites-available/virtual
   ```
3. 启用站点并移除默认：
   ```bash
   sudo ln -s /etc/nginx/sites-available/virtual /etc/nginx/sites-enabled/
   sudo rm -f /etc/nginx/sites-enabled/default
   sudo nginx -t && sudo systemctl reload nginx
   ```

## 五、防火墙（关键）

只放行 80/443，封死 8080 与 5432 入站：

```bash
sudo ufw default deny incoming
sudo ufw allow 22/tcp        # SSH，别锁死自己
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 8080/tcp       # 后端仅内网
sudo ufw deny 5433/tcp       # 数据库仅内网
sudo ufw enable
```

## 六、App 端（别忘了）

用户安装 App 后，进入 **设置 → 后端地址**，填：`https://virtual.literature95.com`
（**不带** `/api`，App 代码会自动拼 `/api/*`）。

## 七、可选：容器化后端

若希望后端以容器运行，用根目录 `Virtual_background/Dockerfile`（已修正）：

```bash
cd Virtual_background
docker build -t virtual-backend .
docker run -d --network host \
  -e DB_HOST=127.0.0.1 -e DB_PORT=5433 -e DB_NAME=virtual \
  -e DB_USER=postgres -e DB_PASSWORD=1234 \
  -e JWT_SECRET=<64位随机串> \
  --name virtual-backend virtual-backend
```

`--network host` 下容器共享宿主网络，`127.0.0.1:8080` 即宿主回环，nginx 同机可直连。
**注意**：容器化后端仍连**宿主 PG**（非容器 PG），故无需 `docker-compose` 起数据库。

## 八、部署后校验

```bash
curl -fsS https://virtual.literature95.com/api/characters | head      # 应返回角色列表 JSON
curl -fsS https://virtual.literature95.com/ | head                    # 应返回 index.html
```

## 已知待办（部署前建议处理，见 README）

- `/api/characters` 全量返回、无分页；卡库大时列表会拖垮 → 建议先加分页。
- CORS 当前 `*`，nginx 反代后可收紧到你的域名。
- `PUT/PATCH/DELETE /api/characters` 缺失；`X-Install-Token` 未做。

#!/usr/bin/env bash
#
# 部署 App release APK 到线上站点。
#
# 背景：App 分发包存在于三处，必须保持同步，否则用户下载到的仍是旧版本：
#   1) Virtual_app/build/app/outputs/flutter-apk/app-release.apk   ← 构建产物（唯一真源）
#   2) Virtual_web/public/app-release.apk                          ← Vite 源（构建时进 dist/）
#   3) 服务器 /var/www/virtual/dist/app-release.apk                ← nginx 实际对外提供的文件
#
# 用法（在仓库根目录执行）：
#   bash deploy/deploy_apk.sh              # 同步三处 + 校验
#   bash deploy/deploy_apk.sh --no-web     # 跳过第 2 步（只想更新线上时）
#
# 依赖：ssh 免密登录 root@120.55.194.238
set -euo pipefail

SERVER="${VIRTUAL_SERVER:-root@120.55.194.238}"
REMOTE_DIR="/var/www/virtual/dist"
REMOTE_APK="$REMOTE_DIR/app-release.apk"
LOCAL_APK="Virtual_app/build/app/outputs/flutter-apk/app-release.apk"
LOCAL_SHA1="$LOCAL_APK.sha1"
WEB_APK="Virtual_web/public/app-release.apk"
KEEP_BACKUPS="${VIRTUAL_KEEP_APK_BACKUPS:-1}"   # 保留最近 N 个备份，0 = 不留

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

info() { printf '\033[36m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m✔ %s\033[0m\n' "$*"; }
die()  { printf '\033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

# ── 0. 前置检查 ────────────────────────────────────────────────
[ -f "$LOCAL_APK" ] || die "未找到构建产物 $LOCAL_APK，请先执行 flutter build apk --release"
LOCAL_SIZE=$(stat -c %s "$LOCAL_APK" 2>/dev/null || stat -f %z "$LOCAL_APK")
[ "$LOCAL_SIZE" -gt 1000000 ] || die "构建产物仅 ${LOCAL_SIZE}B，疑似不完整，已中止"

info "构建产物：$LOCAL_APK ($(( LOCAL_SIZE / 1024 / 1024 ))MB)"
if [ -f "$LOCAL_SHA1" ]; then
  EXPECTED_SHA=$(tr -d '[:space:]' < "$LOCAL_SHA1")
  ACTUAL_SHA=$(sha1sum "$LOCAL_APK" | awk '{print $1}')
  [ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] \
    || die "构建产物与其自带 .sha1 不一致（文件可能已损坏）\n  期望 $EXPECTED_SHA\n  实际 $ACTUAL_SHA"
  ok "本地哈希自检通过：$ACTUAL_SHA"
else
  ACTUAL_SHA=$(sha1sum "$LOCAL_APK" | awk '{print $1}')
  info "未找到 $LOCAL_SHA1，直接计算哈希：$ACTUAL_SHA"
fi

# ── 1. 同步到 Web 源 ──────────────────────────────────────────
if [ "${1:-}" != "--no-web" ]; then
  info "同步到 Virtual_web/public/"
  cp "$LOCAL_APK" "$WEB_APK"
  ok "Web 源已同步"
fi

# ── 2. 上传到服务器（先传 .new，避免传输中断破坏线上文件）────
info "上传到 $SERVER:$REMOTE_APK.new"
ssh -o StrictHostKeyChecking=no "$SERVER" "cat > $REMOTE_APK.new" < "$LOCAL_APK"
ok "上传完成"

info "服务器端哈希校验"
REMOTE_SHA=$(ssh -o StrictHostKeyChecking=no "$SERVER" "sha1sum $REMOTE_APK.new" | awk '{print $1}')
[ "$REMOTE_SHA" = "$ACTUAL_SHA" ] \
  || die "传输后哈希不一致，已保留原文件未做替换\n  本地 $ACTUAL_SHA\n  远程 $REMOTE_SHA"
ok "哈希一致：$REMOTE_SHA"

# ── 3. 备份轮转 + 原子替换 ────────────────────────────────────
info "备份轮转（保留最近 $KEEP_BACKUPS 个）并替换线上文件"
ssh -o StrictHostKeyChecking=no "$SERVER" "
  set -e
  cd '$REMOTE_DIR'

  # 备份当前线上版本
  if [ -f app-release.apk ]; then
    cp -p app-release.apk \"app-release.apk.bak-\$(date +%Y%m%d%H%M%S)\"
  fi

  # 轮转：只保留最近 N 个备份，其余删除（避免 49MB × N 累积占满磁盘）
  KEEP=$KEEP_BACKUPS
  if [ \"\$KEEP\" -eq 0 ]; then
    rm -f app-release.apk.bak-*
  else
    ls -1t app-release.apk.bak-* 2>/dev/null | tail -n +\$((KEEP + 1)) | xargs -r rm -f
  fi

  chmod 644 app-release.apk.new
  mv -f app-release.apk.new app-release.apk
  chmod 644 app-release.apk
"
ok "线上文件已替换"

# ── 4. 校验对外可访问（用哈希而非状态码）─────────────────────
# ⚠️ 站点是 SPA，nginx 对不存在路径会 try_files 回退到 index.html 并返回 200，
#    因此「状态码 200」不能证明文件存在；必须比对下载内容哈希。
# 🔴 必须「先下载到文件再 sha1sum」，不可用管道 `curl ... | sha1sum`：
#    实测该写法会因大流量经管道传输而丢字节（49MB 文件哈希随机不符），
#    且与进度条无关（加 --no-progress-meter 仍错），是纯假警报来源。
info "下载线上文件并比对哈希（约 49MB）"
# 用 Git Bash 原生路径，规避 TMPDIR 被设为 Windows 路径（C:\Users\...）导致
# `$TMPDIR/xxx` 拼成混合路径而失败；同时避免 -o 相对路径被路径转换破坏。
TMP="/tmp/virtual-apk-verify.bin"
trap 'rm -f "$TMP"' EXIT
curl -fsS --noproxy '*' -o "$TMP" https://virtual.literature95.com/app-release.apk \
  || die "线上 APK 下载失败"
DOWNLOADED_SIZE=$(wc -c < "$TMP" | tr -d '[:space:]')
[ "$DOWNLOADED_SIZE" -eq "$LOCAL_SIZE" ] \
  || die "下载体积不符：本地 ${LOCAL_SIZE}B，线上 ${DOWNLOADED_SIZE}B"
SERVED_SHA=$(sha1sum "$TMP" | awk '{print $1}' | tr -cd '0-9a-f')
[ "$SERVED_SHA" = "$ACTUAL_SHA" ] \
  || die "线上提供的文件与本地构建不一致！\n  本地 $ACTUAL_SHA\n  线上 $SERVED_SHA"
ok "线上校验通过：$SERVED_SHA"

# ── 5. 汇总 ───────────────────────────────────────────────────
printf '\n\033[32m=== 部署完成 ===\033[0m\n'
ssh -o StrictHostKeyChecking=no "$SERVER" "ls -lh $REMOTE_DIR/app-release.apk* ; echo; df -h / | tail -1"
printf '\n下载地址：https://virtual.literature95.com/app-release.apk\n'

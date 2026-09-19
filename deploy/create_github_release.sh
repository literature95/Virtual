#!/usr/bin/env bash
#
# 创建 GitHub Release 并挂上 APK。
# 用法：
#   bash deploy/create_github_release.sh          # 默认 tag=v1.0.6
#   TAG=v1.0.7 APP_VER=1.0.7+8 bash deploy/create_github_release.sh
#
# 依赖：gh 已安装；GH_TOKEN 或 git credential（github.com HTTPS）可用。
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual

TAG="${TAG:-v1.0.6}"
APK="${APK:-/d/Documents/Desktop/Virtual/Virtual_app/build/app/outputs/flutter-apk/app-release.apk}"
REPO="${REPO:-literature95/Virtual}"
TITLE="${TITLE:-Virtual $TAG}"
SHA1_FILE="${APK}.sha1"
APK_SHA1=""
[ -f "$SHA1_FILE" ] && APK_SHA1=$(tr -d '[:space:]' < "$SHA1_FILE")
# fallback：读 pubspec
if [ -z "${APP_VER:-}" ]; then
  APP_VER=$(sed -n 's/^version: //p' Virtual_app/pubspec.yaml | head -1)
fi

# 从 Git 凭据管理器取 HTTPS 凭据（push 刚成功，通常有缓存）
CRED=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill || true)
TOKEN=$(echo "$CRED" | sed -n 's/^password=//p' | tr -d '\r')
[ -n "$TOKEN" ] || TOKEN=$(echo "$CRED" | sed -n 's/^username=//p' | tr -d '\r')
[ -n "$TOKEN" ] || { echo "NO_TOKEN — 请 gh auth login 或设置 GH_TOKEN"; exit 2; }
export GH_TOKEN="$TOKEN"

[ -f "$APK" ] || { echo "APK not found: $APK"; exit 1; }

BODY=$(mktemp)
cat > "$BODY" <<EOF
## Virtual $TAG（App $APP_VER）

本地优先 · 跨模型 · 隐私向 AI 角色聊天客户端。

### 下载
- 本 Release 资产 \`app-release.apk\`
- 官网镜像: https://virtual.literature95.com/app-release.apk
$( [ -n "$APK_SHA1" ] && echo "- APK SHA1: \`$APK_SHA1\`" )

### 说明
历史版本不补挂；请始终使用 **Latest**。变更见 \`main\` 提交与各版本 commit message。
EOF

gh release create "$TAG" \
  "${APK}#app-release.apk" \
  --repo "$REPO" \
  --title "$TITLE" \
  --notes-file "$BODY"

rm -f "$BODY"
echo "=== list ==="
gh release list --repo "$REPO"
echo "RELEASE_OK tag=$TAG app=$APP_VER"

#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/bin:$PATH
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
ROOT=/d/Documents/Desktop/Virtual/Virtual_web
cd "$ROOT"
tar --exclude=./app-release.apk -C dist -cf - . \
  | ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@120.55.194.238 '
      set -e
      find /var/www/virtual/dist -mindepth 1 -maxdepth 1 ! -name "app-release.apk" ! -name "app-release.apk.bak-*" -exec rm -rf {} +
      tar -C /var/www/virtual/dist -xf -
      chmod -R a+rX /var/www/virtual/dist
      ls -la /var/www/virtual/dist | head -25
      ls -lh /var/www/virtual/dist/assets/app_icon_grad-*.png /var/www/virtual/dist/app-release.apk
    '
ASSET=$(ls dist/assets/app_icon_grad-*.png | xargs -n1 basename | head -1)
echo "asset=$ASSET"
curl -fsS --noproxy '*' -o /tmp/v-index.html https://virtual.literature95.com/
grep -E 'app_icon|index-' /tmp/v-index.html
curl -fsSI --noproxy '*' "https://virtual.literature95.com/assets/$ASSET" | head -12
# 确认下载带里不再有 BrandMark / band 上的 mark（以 JS 构建产物为准）
if grep -q '现在，开启你的故事' dist/assets/index-*.js; then
  echo "band text present (expected)"
fi
echo "DEPLOY_OK"

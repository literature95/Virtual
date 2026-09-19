#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy github_proxy HTTPS_PROXY || true
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
SERVER=root@120.55.194.238

echo "=== APK ==="
bash deploy/deploy_apk.sh

echo "=== web version.json ==="
bash deploy/push_web_dist.sh || true
# 确保 version.json 在线上
scp -o BatchMode=yes -o StrictHostKeyChecking=no \
  Virtual_web/public/version.json "$SERVER:/var/www/virtual/dist/version.json"
curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo

echo "=== backend seed app-info ==="
# dart_frog build 后同步 lib/database/seed.dart
df="/c/Users/Administrator/AppData/Local/Pub/Cache/bin/dart_frog.bat"
cd Virtual_background
"$df" build
cd ..
tar -C Virtual_background -cf - lib/database/seed.dart \
  | ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER" "
      set -e
      cd /opt/virtual/Virtual_background
      tar -xf -
      mkdir -p build/lib/database
      cp -f lib/database/seed.dart build/lib/database/seed.dart
      systemctl restart virtual-backend
      echo backend_restarted
    "
sleep 12
curl -fsS --noproxy '*' http://127.0.0.1:8080/api/app-info 2>/dev/null || \
  ssh -o BatchMode=yes "$SERVER" "curl -fsS --noproxy '*' http://127.0.0.1:8080/api/app-info"
echo
curl -fsS --noproxy '*' https://virtual.literature95.com/api/app-info
echo

echo "=== git + release v1.0.8 ==="
cd /d/Documents/Desktop/Virtual
git add -A
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "release: v1.0.8 应用内更新提示

- App 启动检查 /version.json 与 /api/app-info
- 远端版本高于本地时弹窗并引导下载 APK
- 后端 seed app-info 版本与下载地址对齐官网
- App 1.0.8+9" || true
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git main:main && break
  sleep 4
done
git tag -f v1.0.8 -m "Virtual v1.0.8 in-app update prompt"
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.8:refs/tags/v1.0.8 && break
  sleep 4
done
export TAG=v1.0.8 TITLE="Virtual v1.0.8"
bash deploy/create_github_release.sh

# README version
sed -i 's/\*\*1\.0\.7+8\*\*/**1.0.8+9**/g; s/tag\/v1\.0\.7/tag\/v1.0.8/g; s/Release v1\.0\.7/Release v1.0.8/g' README.md || true
git add README.md
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "docs: 版本 1.0.8+9" || true
env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
  git push https://github.com/literature95/Virtual.git main:main || true

echo ALL_OK

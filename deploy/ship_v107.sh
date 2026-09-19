#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual

echo "=== deploy APK ==="
bash deploy/deploy_apk.sh

echo "=== git commit + push ==="
git add -A
git -c user.name="literature95" -c user.email="literature95@users.noreply.github.com" \
  commit -m "release: v1.0.7 高德 Web服务 Key 修复逆地理 USERKEY_PLAT_NOMATCH

- Android Key 与 Web服务 Key 分离
- 无 Web Key 时降级为坐标展示，不阻塞发动态
- App 1.0.7+8" || true

env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
  git push https://github.com/literature95/Virtual.git main:main
git tag -f v1.0.7 -m "Virtual v1.0.7 — AMap Web key for regeo"
env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
  git push https://github.com/literature95/Virtual.git refs/tags/v1.0.7:refs/tags/v1.0.7

echo "=== github release ==="
export TAG=v1.0.7
export TITLE="Virtual v1.0.7"
bash deploy/create_github_release.sh

echo "ALL_OK"

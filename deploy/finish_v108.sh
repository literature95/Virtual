#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
SERVER=root@120.55.194.238

echo "wait backend..."
for i in 1 2 3 4 5 6 7 8 9 10; do
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER" \
      "curl -fsS --noproxy '*' http://127.0.0.1:8080/api/app-info"; then
    echo
    echo BACKEND_APPINFO_OK
    break
  fi
  echo wait $i
  sleep 4
done
curl -fsS --noproxy '*' https://virtual.literature95.com/api/app-info
echo
curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo

cd /d/Documents/Desktop/Virtual
git add -A
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "release: v1.0.8 应用内更新提示

- App 启动检查 version.json / app-info，远端更新时弹窗下载
- seed 与线上 version.json 对齐 1.0.8+9
- App 1.0.8+9" || true
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git main:main && echo PUSH_MAIN_OK && break
  sleep 4
done
git tag -f v1.0.8 -m "Virtual v1.0.8 in-app update prompt"
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.8:refs/tags/v1.0.8 && echo PUSH_TAG_OK && break
  sleep 4
done
export TAG=v1.0.8 TITLE="Virtual v1.0.8"
bash deploy/create_github_release.sh
echo ALL_OK

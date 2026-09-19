#!/usr/bin/env bash
set -euo pipefail
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
cd /d/Documents/Desktop/Virtual

git add README.md Virtual_app/pubspec.yaml 2>/dev/null || true
if ! git diff --cached --quiet; then
  git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
    commit -m "docs: 版本号更新为 1.0.7+8" || true
fi

ok=0
for i in 1 2 3 4 5 6; do
  if env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
      git push https://github.com/literature95/Virtual.git main:main; then
    echo PUSH_MAIN_OK
    ok=1
    break
  fi
  echo "retry main push $i"
  sleep 4
done
[ "$ok" = "1" ] || { echo PUSH_MAIN_FAIL; exit 1; }

git tag -f v1.0.7 -m "Virtual v1.0.7 — AMap Web key for regeo"
ok=0
for i in 1 2 3 4 5 6; do
  if env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
      git push https://github.com/literature95/Virtual.git refs/tags/v1.0.7:refs/tags/v1.0.7; then
    echo PUSH_TAG_OK
    ok=1
    break
  fi
  echo "retry tag push $i"
  sleep 4
done
[ "$ok" = "1" ] || { echo PUSH_TAG_FAIL; exit 1; }

export TAG=v1.0.7
export TITLE="Virtual v1.0.7"
bash deploy/create_github_release.sh
echo ALL_OK

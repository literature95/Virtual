#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/bin:/d/Git/Git/cmd:$PATH
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual

# 绝不提交 ssl/ 私钥
git status --porcelain | grep -E '^\?\?.*ssl/|^\?\?.*\.key$' && exit 1 || true

git add -A
# 再次确认
if git status --porcelain | grep -E 'ssl/|\.key$'; then
  echo "ABORT: would commit secrets"
  exit 1
fi

git status -sb | head -80

git -c user.name="${GIT_AUTHOR_NAME:-literature95}" \
    -c user.email="${GIT_AUTHOR_EMAIL:-literature95@users.noreply.github.com}" \
    commit -m "release: v1.0.6 全页发动态 + 高德定位 + 品牌图标统一

- 对话页顶栏状态栏避让；设背景时背景铺满全屏
- 底栏五位导航，中间「+」进入全页发布 /compose
- 发动态接入高德定位（privacy + regeo），后端 posts 增 location 字段
- Web/App 品牌 mark 统一为签名渐变 app_icon
- 首页角色预览 4 张 2×2；favicon 缓存击穿
- 发布 PNG 角色卡工具与部署脚本"

echo "--- log ---"
git log -1 --oneline

echo "--- tag ---"
git tag -f v1.0.6 -m "Virtual v1.0.6+7 — compose page, AMap location, unified brand mark"

echo "--- push ---"
# origin 为 SSH，沙箱无密钥时用 HTTPS（见项目 memory）
env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
  git push https://github.com/literature95/Virtual.git main:main
env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
  git push https://github.com/literature95/Virtual.git refs/tags/v1.0.6:refs/tags/v1.0.6

echo "PUSH_OK"

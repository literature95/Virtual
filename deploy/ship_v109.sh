#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
SERVER=root@120.55.194.238

# version.json → 1.0.9+10
cat > Virtual_web/public/version.json <<'EOF'
{
  "version": "1.0.9+10",
  "downloadUrl": "https://virtual.literature95.com/app-release.apk",
  "notes": "发现页新增角色卡竖滑流；底栏保留",
  "changes": [
    "发现 Tab：竖向角色卡流（点赞/收藏/转发）",
    "点角色卡进入在线详情",
    "底栏菜单始终保留",
    "发动态高德定位、全页发布"
  ]
}
EOF

# backend app_info
ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER" "
export PGPASSWORD=1234
/usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual -c \"UPDATE app_info SET version='1.0.9+10', download_url='https://virtual.literature95.com/app-release.apk' WHERE id='app-001';\"
"

echo "=== APK ==="
bash deploy/deploy_apk.sh
bash deploy/push_web_dist.sh
scp -o BatchMode=yes -o StrictHostKeyChecking=no \
  Virtual_web/public/version.json "$SERVER:/var/www/virtual/dist/version.json"

echo "=== git + release ==="
# sync README version
sed -i 's/1\.0\.8+9/1.0.9+10/g; s/tag\/v1\.0\.8/tag\/v1.0.9/g; s/Release v1\.0\.8/Release v1.0.9/g' README.md || true
git add -A
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "release: v1.0.9 发现页角色卡流

- 发现 Tab 推荐|发现|关注，中间为竖滑角色卡
- 点赞/收藏/转发 + 点卡进详情
- 底栏 HomeShell 菜单保留
- App 1.0.9+10" || true
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git main:main && break
  sleep 4
done
git tag -f v1.0.9 -m "Virtual v1.0.9 discover character feed"
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.9:refs/tags/v1.0.9 && break
  sleep 4
done
export TAG=v1.0.9 TITLE="Virtual v1.0.9"
bash deploy/create_github_release.sh

curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo
echo ALL_OK

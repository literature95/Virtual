#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
SERVER=root@120.55.194.238

bash deploy/deploy_apk.sh
bash deploy/push_web_dist.sh

# APK 本体是 1.0.15+16；version.json 故意写 1.0.16+17，
# 便于用户装完 1.0.15 后启动弹窗，测试「立即下载」是否能拉起浏览器。
cat > Virtual_web/public/version.json <<'EOF'
{
  "version": "1.0.16+17",
  "downloadUrl": "https://virtual.literature95.com/app-release.apk",
  "notes": "测试更新按钮：修复 canLaunchUrl 导致立即更新无响应",
  "changes": [
    "修复「立即更新/立即下载」无反应",
    "更多页返回与标题合并为一行",
    "请点立即下载验证能否打开浏览器"
  ]
}
EOF
scp -o BatchMode=yes Virtual_web/public/version.json "$SERVER:/var/www/virtual/dist/version.json"
ssh -o BatchMode=yes "$SERVER" "export PGPASSWORD=1234; /usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual -c \"UPDATE app_info SET version='1.0.16+17' WHERE id='app-001';\""

sed -i 's/1\.0\.14+15/1.0.15+16/g; s/tag\/v1\.0\.14/tag\/v1.0.15/g; s/Release v1\.0\.14/Release v1.0.15/g' README.md || true
git add -A
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "fix(update): 立即下载不再依赖 canLaunchUrl；更多页单行顶栏" || true
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git main:main && break
  sleep 4
done
git tag -f v1.0.15 -m "Virtual v1.0.15 update button + more appbar"
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.15:refs/tags/v1.0.15 && break
  sleep 4
done
export TAG=v1.0.15 TITLE="Virtual v1.0.15"
bash deploy/create_github_release.sh

curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo
ssh -o BatchMode=yes "$SERVER" "sha1sum /var/www/virtual/dist/app-release.apk"
echo ALL_OK

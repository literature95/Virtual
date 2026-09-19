#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
SERVER=root@120.55.194.238

cat > Virtual_web/public/version.json <<'EOF'
{
  "version": "1.0.11+12",
  "downloadUrl": "https://virtual.literature95.com/app-release.apk",
  "notes": "底栏进入发现页时默认停在「发现」角色卡流",
  "changes": [
    "底栏「发现」默认选中中间「发现」Tab",
    "设置/关于统一 Virtual 品牌",
    "发现页角色卡竖滑流"
  ]
}
EOF

bash deploy/deploy_apk.sh
bash deploy/push_web_dist.sh
scp -o BatchMode=yes Virtual_web/public/version.json "$SERVER:/var/www/virtual/dist/version.json"
ssh -o BatchMode=yes "$SERVER" "export PGPASSWORD=1234; /usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual -c \"UPDATE app_info SET version='1.0.11+12' WHERE id='app-001';\""

sed -i 's/1\.0\.10+11/1.0.11+12/g; s/tag\/v1\.0\.10/tag\/v1.0.11/g; s/Release v1\.0\.10/Release v1.0.11/g' README.md || true
git add -A
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "fix(discover): 底栏进入发现页默认选中「发现」角色卡流" || true
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git main:main && break
  sleep 4
done
git tag -f v1.0.11 -m "Virtual v1.0.11 default discover tab"
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.11:refs/tags/v1.0.11 && break
  sleep 4
done
export TAG=v1.0.11 TITLE="Virtual v1.0.11"
bash deploy/create_github_release.sh
curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo
echo ALL_OK

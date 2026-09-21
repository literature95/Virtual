#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
SERVER=root@120.55.194.238
SHA=$(tr -d '[:space:]' < Virtual_app/build/app/outputs/flutter-apk/app-release.apk.sha1)
echo "SHA=$SHA"

cat > Virtual_web/public/version.json <<'EOF'
{
  "version": "1.0.14+15",
  "downloadUrl": "https://virtual.literature95.com/app-release.apk",
  "notes": "注册页协议勾选：用户协议 / 隐私政策 / 产品服务协议",
  "changes": [
    "注册需勾选同意三项协议",
    "协议全文可在应用内打开",
    "每次启动版本校验"
  ]
}
EOF

bash deploy/deploy_apk.sh
bash deploy/push_web_dist.sh
scp -o BatchMode=yes Virtual_web/public/version.json "$SERVER:/var/www/virtual/dist/version.json"
ssh -o BatchMode=yes "$SERVER" "export PGPASSWORD=1234; /usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual -c \"UPDATE app_info SET version='1.0.14+15' WHERE id='app-001';\""

sed -i 's/1\.0\.13+14/1.0.14+15/g; s/tag\/v1\.0\.13/tag\/v1.0.14/g; s/Release v1\.0\.13/Release v1.0.14/g' README.md || true
git add -A
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "feat(auth): 注册页协议勾选与用户协议/隐私/产品服务条款" || true
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git main:main && break
  sleep 4
done
git tag -f v1.0.14 -m "Virtual v1.0.14 register legal consent"
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.14:refs/tags/v1.0.14 && break
  sleep 4
done
export TAG=v1.0.14 TITLE="Virtual v1.0.14"
bash deploy/create_github_release.sh
curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo
echo ALL_OK

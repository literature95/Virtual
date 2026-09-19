#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
SERVER=root@120.55.194.238

cat > Virtual_web/public/version.json <<'EOF'
{
  "version": "1.0.12+13",
  "downloadUrl": "https://virtual.literature95.com/app-release.apk",
  "notes": "完善应用内更新检查；设置可手动检查",
  "changes": [
    "启动更新检查使用完整 version+build",
    "设置-关于「检查更新」真正对比远端版本",
    "本地=线上时不弹窗（正确行为）"
  ]
}
EOF

bash deploy/deploy_apk.sh
bash deploy/push_web_dist.sh
scp -o BatchMode=yes Virtual_web/public/version.json "$SERVER:/var/www/virtual/dist/version.json"
ssh -o BatchMode=yes "$SERVER" "export PGPASSWORD=1234; /usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual -c \"UPDATE app_info SET version='1.0.12+13' WHERE id='app-001';\""

sed -i 's/1\.0\.11+12/1.0.12+13/g; s/tag\/v1\.0\.11/tag\/v1.0.12/g; s/Release v1\.0\.11/Release v1.0.12/g' README.md || true
git add -A
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "fix(update): 更新检查用 version+build；设置可手动检查更新" || true
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git main:main && break
  sleep 4
done
git tag -f v1.0.12 -m "Virtual v1.0.12 update check"
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.12:refs/tags/v1.0.12 && break
  sleep 4
done
export TAG=v1.0.12 TITLE="Virtual v1.0.12"
bash deploy/create_github_release.sh
echo "--- live version ---"
curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo
echo ALL_OK

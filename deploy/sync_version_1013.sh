#!/usr/bin/env bash
set -euo pipefail
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cat > /d/Documents/Desktop/Virtual/Virtual_web/public/version.json <<'EOF'
{
  "version": "1.0.13+14",
  "downloadUrl": "https://virtual.literature95.com/app-release.apk",
  "notes": "每次启动都做版本校验；落后则弹窗下载",
  "changes": [
    "每次冷启动检查 version.json",
    "本机落后线上时弹「发现新版本」",
    "设置-关于可手动检查更新",
    "手机 1.0.10+11 打开应用应提示升级"
  ]
}
EOF
scp -o BatchMode=yes \
  /d/Documents/Desktop/Virtual/Virtual_web/public/version.json \
  root@120.55.194.238:/var/www/virtual/dist/version.json
ssh -o BatchMode=yes root@120.55.194.238 \
  "export PGPASSWORD=1234; /usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual -c \"UPDATE app_info SET version='1.0.13+14' WHERE id='app-001'; SELECT version FROM app_info WHERE id='app-001';\""
echo "=== online version.json ==="
curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo
echo "=== online app-info ==="
curl -fsS --noproxy '*' https://virtual.literature95.com/api/app-info
echo
echo VERSION_SYNC_OK

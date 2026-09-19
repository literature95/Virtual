#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/bin:/d/Git/Git/usr/bin:$PATH
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
bash deploy/deploy_apk.sh
echo "APK_DEPLOY_OK"

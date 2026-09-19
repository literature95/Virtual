#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
SHA=$(tr -d '[:space:]' < Virtual_app/build/app/outputs/flutter-apk/app-release.apk.sha1)
echo "local_sha=$SHA"
bash deploy/deploy_apk.sh
CRED=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill || true)
export GH_TOKEN=$(echo "$CRED" | sed -n 's/^password=//p' | tr -d '\r')
gh release upload v1.0.10 \
  "Virtual_app/build/app/outputs/flutter-apk/app-release.apk#app-release.apk" \
  --clobber
echo "--- verify online apk sha ---"
# range download first bytes won't give full hash; use server file
ssh -o BatchMode=yes root@120.55.194.238 "sha1sum /var/www/virtual/dist/app-release.apk"
echo "--- metadata ---"
curl -fsS --noproxy '*' https://virtual.literature95.com/api/metadata | head -c 500
echo
curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo
gh release view v1.0.10 --repo literature95/Virtual | head -25
echo DEPLOY_1010_OK

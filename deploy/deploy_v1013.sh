#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
echo "SHA=$(tr -d '[:space:]' < Virtual_app/build/app/outputs/flutter-apk/app-release.apk.sha1)"
bash deploy/deploy_apk.sh
CRED=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill || true)
export GH_TOKEN=$(echo "$CRED" | sed -n 's/^password=//p' | tr -d '\r')
if ! gh release view v1.0.13 --repo literature95/Virtual >/dev/null 2>&1; then
  git tag -f v1.0.13 -m "Virtual v1.0.13"
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.13:refs/tags/v1.0.13 || true
  export TAG=v1.0.13 TITLE="Virtual v1.0.13"
  bash deploy/create_github_release.sh
fi
gh release upload v1.0.13 \
  "Virtual_app/build/app/outputs/flutter-apk/app-release.apk#app-release.apk" \
  --clobber
ssh -o BatchMode=yes root@120.55.194.238 "sha1sum /var/www/virtual/dist/app-release.apk"
curl -fsS --noproxy '*' https://virtual.literature95.com/version.json
echo
echo DEPLOY_OK

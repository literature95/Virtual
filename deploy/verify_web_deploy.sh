#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/bin:$PATH
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
LOCAL=/d/Documents/Desktop/Virtual/Virtual_web/dist
echo "=== LOCAL dist ==="
ls -la "$LOCAL" | head -25
sha1sum "$LOCAL/favicon-32.png" "$LOCAL/index.html"
echo "=== REMOTE dist ==="
ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@120.55.194.238 'ls -la /var/www/virtual/dist | head -30; echo ---; sha1sum /var/www/virtual/dist/favicon-32.png /var/www/virtual/dist/index.html; ls -lh /var/www/virtual/dist/app-release.apk'
echo "=== ONLINE index head ==="
curl -fsS --noproxy '*' -o /tmp/virtual-index.html https://virtual.literature95.com/
head -20 /tmp/virtual-index.html
echo "=== ONLINE favicon hash ==="
curl -fsS --noproxy '*' -o /tmp/v-fav.png https://virtual.literature95.com/favicon-32.png
sha1sum /tmp/v-fav.png
curl -fsSI --noproxy '*' https://virtual.literature95.com/assets/app_icon-MhdA3jJ5.png | head -12
echo "DONE"

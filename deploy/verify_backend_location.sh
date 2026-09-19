#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/bin:$PATH
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@120.55.194.238 '
  ls -la /opt/virtual/Virtual_background/build/lib/database/db.dart
  grep -n location /opt/virtual/Virtual_background/build/lib/community_mapper.dart | head
  grep -n location /opt/virtual/Virtual_background/build/routes/api/posts/index.dart | head
  curl -fsS --noproxy "*" http://127.0.0.1:8080/api/health
  echo
  curl -fsS --noproxy "*" http://127.0.0.1:8080/api/posts | head -c 500
  echo
'
curl -fsS --noproxy '*' https://virtual.literature95.com/api/health
echo
curl -fsS --noproxy '*' https://virtual.literature95.com/app-release.apk -o /dev/null -w "apk_http=%{http_code} size=%{size_download}\n" --max-time 15 -r 0-1023
echo VERIFY_OK

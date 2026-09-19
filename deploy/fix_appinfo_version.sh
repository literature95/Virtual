#!/usr/bin/env bash
set -euo pipefail
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@120.55.194.238 '
export PGPASSWORD=1234
/usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual <<SQL
UPDATE app_info
SET version = '"'"'1.0.8+9'"'"',
    download_url = '"'"'https://virtual.literature95.com/app-release.apk'"'"'
WHERE id = '"'"'app-001'"'"';
SELECT id, version, download_url FROM app_info;
SQL
'
echo "--- public ---"
curl -fsS --noproxy '*' https://virtual.literature95.com/api/app-info
echo

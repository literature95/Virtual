#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/GitHub CLI:/d/Git/Git/cmd:/usr/bin:/bin:$PATH"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
cd /d/Documents/Desktop/Virtual
SERVER=root@120.55.194.238

echo "=== backend seed + db metadata ==="
df="/c/Users/Administrator/AppData/Local/Pub/Cache/bin/dart_frog.bat"
cd Virtual_background && "$df" build && cd ..
tar -C Virtual_background -cf - lib/database/seed.dart | ssh -o BatchMode=yes "$SERVER" "
  set -e
  cd /opt/virtual/Virtual_background
  tar -xf -
  mkdir -p build/lib/database
  cp -f lib/database/seed.dart build/lib/database/seed.dart
  systemctl restart virtual-backend
"
# 服务器上直接改 metadata uris
cat > /tmp/fix_uris.sql <<'SQL'
UPDATE metadata
SET payload = jsonb_set(
  COALESCE(payload, '[]'::jsonb),
  '{0}',
  jsonb_build_object(
    'desc', '客服邮箱、官网等',
    'id', 'uris',
    'name', '网络资源',
    'obj', jsonb_build_object(
      'customer_service_email', 'virtual_service@outlook.com',
      'discord', '',
      'help', 'https://virtual.literature95.com/',
      'homepage', 'https://virtual.literature95.com',
      'privacy_policy', 'https://virtual.literature95.com/#privacy',
      'terms_of_service', 'https://virtual.literature95.com/#terms'
    ),
    'tag', null
  ),
  true
)
WHERE id = 'uris';
-- 兜底：整行替换
UPDATE metadata SET payload = '[
  {"desc":"客服邮箱、官网等","id":"uris","name":"网络资源","obj":{"customer_service_email":"virtual_service@outlook.com","discord":"","help":"https://virtual.literature95.com/","homepage":"https://virtual.literature95.com","privacy_policy":"https://virtual.literature95.com/#privacy","terms_of_service":"https://virtual.literature95.com/#terms"},"tag":null},
  {"desc":"快速开始一键配置开关","id":"quick-setup","name":"quick setup","obj":true,"tag":null}
]'::jsonb WHERE id = 'uris';
SELECT id, left(payload::text, 200) FROM metadata WHERE id='uris';
SQL
scp -o BatchMode=yes /tmp/fix_uris.sql "$SERVER:/tmp/fix_uris.sql"
ssh -o BatchMode=yes "$SERVER" "export PGPASSWORD=1234; /usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual -f /tmp/fix_uris.sql"

echo "=== APK + version.json ==="
bash deploy/deploy_apk.sh
bash deploy/push_web_dist.sh
scp -o BatchMode=yes Virtual_web/public/version.json "$SERVER:/var/www/virtual/dist/version.json"

echo "=== git + GH ==="
sed -i 's/1\.0\.9+10/1.0.10+11/g; s/tag\/v1\.0\.9/tag\/v1.0.10/g; s/Release v1\.0\.9/Release v1.0.10/g' README.md || true
git add -A
git -c user.name=literature95 -c user.email=literature95@users.noreply.github.com \
  commit -m "release: v1.0.10 品牌清理 Virtual

- 设置/关于：应用名 Virtual、真实版本号、官网/隐私/条款指向 literature95
- metadata 默认与后端 seed 去掉 Tavo/Volink 链接
- MetadataProvider sanitizeUris 强制 Virtual
- App 1.0.10+11" || true
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git main:main && break
  sleep 4
done
git tag -f v1.0.10 -m "Virtual v1.0.10 brand cleanup"
for i in 1 2 3 4 5; do
  env GIT_TERMINAL_PROMPT=0 GIT_CONFIG_SYSTEM=/dev/null \
    git push https://github.com/literature95/Virtual.git refs/tags/v1.0.10:refs/tags/v1.0.10 && break
  sleep 4
done
export TAG=v1.0.10 TITLE="Virtual v1.0.10"
bash deploy/create_github_release.sh
echo ALL_OK

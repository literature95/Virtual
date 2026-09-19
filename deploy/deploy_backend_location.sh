#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/bin:$PATH
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
SERVER=root@120.55.194.238
SRC=/d/Documents/Desktop/Virtual/Virtual_background
REMOTE=/opt/virtual/Virtual_background

echo "=== 1) deploy APK ==="
cd /d/Documents/Desktop/Virtual
bash deploy/deploy_apk.sh

echo "=== 2) deploy backend sources + build copies ==="
# 同步 routes/lib/pubspec 到服务器项目根与 build/ 两份
ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER" "mkdir -p $REMOTE/build/bin $REMOTE/build/routes $REMOTE/build/lib $REMOTE/build/pubspec_overrides 2>/dev/null || mkdir -p $REMOTE/build/bin $REMOTE/build/routes $REMOTE/build/lib"

tar -C "$SRC" -cf - \
  routes lib pubspec.yaml pubspec.lock \
  | ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER" "
      set -e
      cd $REMOTE
      tar -xf -
      # dart_frog build 产物：运行时加载 build/routes 与 build/lib
      rm -rf build/routes build/lib
      cp -a routes build/routes
      cp -a lib build/lib
      cp -f pubspec.yaml pubspec.lock build/ 2>/dev/null || true
      # server.dart 单独传
      echo 'routes/lib synced'
      ls -la build/lib/db.dart build/lib/community_mapper.dart build/routes/api/posts/index.dart | head
    "

# 上传 server.dart（体积小）
scp -o BatchMode=yes -o StrictHostKeyChecking=no \
  "$SRC/build/bin/server.dart" \
  "$SERVER:$REMOTE/build/bin/server.dart"

# build/pubspec 可能需要
if [ -f "$SRC/build/pubspec.yaml" ]; then
  scp -o BatchMode=yes -o StrictHostKeyChecking=no \
    "$SRC/build/pubspec.yaml" "$SRC/build/pubspec.lock" \
    "$SERVER:$REMOTE/build/" || true
fi

echo "=== 3) restart backend ==="
ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER" "
  set -e
  systemctl restart virtual-backend
  sleep 2
  systemctl is-active virtual-backend || true
"

echo "=== 4) wait for JIT + health ==="
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER" "curl -fsS --noproxy '*' http://127.0.0.1:8080/api/health" 2>/dev/null; then
    echo
    echo "HEALTH_OK"
    break
  fi
  echo "wait $i ..."
  sleep 3
done

echo "=== 5) verify posts API schema (location key) ==="
ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER" "
  curl -fsS --noproxy '*' 'http://127.0.0.1:8080/api/posts?community=__none__' | head -c 200 || true
  echo
  # 空库/无匹配也可能返回 []；检查 db 列是否存在
  export PGPASSWORD=1234
  /usr/bin/psql -h 127.0.0.1 -p 5433 -U postgres -d virtual -c \"\\d community_posts\" 2>/dev/null | grep -i location || echo 'psql check skipped/failed'
  systemctl status virtual-backend --no-pager | head -8
"
echo "BACKEND_DEPLOY_DONE"

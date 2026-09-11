# Virtual 本地预览启动器（单端口 8080：后端 API + 立绘 + Flutter Web App）
#
# 前置：先在前端编译
#   cd Virtual_app && flutter build web --wasm --no-tree-shake-icons
#   （输出 Virtual_app/build/web；wasm+JS 双渲染器，不支持 WasmGC 的环境自动回落 CanvasKit）
#
# 用法（PowerShell）：
#   pwsh serve.ps1
#
# 行为：
#   1) 若 8080 已被占用，强杀该监听进程（“占用就终止重启”）
#   2) 把 Virtual_app/build/web 同步进 public/（实现单端口）
#   3) 启动后端（阻塞，Ctrl+C 退出）；浏览器打开 http://localhost:8080/

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:MASON_CACHE = "$root\.mason_cache"

# 1) 占用 8080 则强杀
$occ = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($occ) {
  Stop-Process -Id $occ.OwningProcess -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
  Write-Host '[serve] 已终止占用 8080 的旧进程'
}

# 2) 同步前端构建到 public/
$web = Resolve-Path "$root\..\Virtual_app\build\web" -ErrorAction SilentlyContinue
if ($web) {
  Copy-Item "$web\*" "$root\public" -Recurse -Force
  Write-Host '[serve] 已同步前端构建 -> public/'
} else {
  Write-Host '[serve] 未找到 Virtual_app/build/web，跳过同步（请先 flutter build web）'
}

# 2.5) App 壳文件禁缓存补丁：dart_frog 内置静态服务只发 Last-Modified，
#      浏览器在启发式新鲜窗口内不回源，重建同步后会供旧 main.dart.js。
#      dart_frog build 每次重新生成 server.dart，因此每次构建后都要重打。
$server = "$root\build\bin\server.dart"
if ((Test-Path $server) -and -not (Select-String -Path $server -Pattern 'cache-control' -Quiet)) {
  (Get-Content $server -Raw) `
    -replace [regex]::Escape('  final handler = Cascade().add(createStaticFileHandler()).add(buildRootHandler()).handler;'),
             @'
  final handler = (RequestContext context) async { final rsp = await Cascade().add(createStaticFileHandler()).add(buildRootHandler()).handler(context); final p = context.request.uri.path; final isShell = p.isEmpty || p.endsWith(".js") || p.endsWith(".html") || p.endsWith(".json"); if (isShell) { final h = Map<String, Object>.from(rsp.headers); h["cache-control"] = "no-cache"; return rsp.copyWith(headers: h); } return rsp; };
'@ | Set-Content $server -Encoding UTF8
  Write-Host '[serve] 已打 App 壳禁缓存补丁'
}

# 3) 启动后端
Set-Location $root
Write-Host '[serve] 预览地址: http://localhost:8080/'
dart build/bin/server.dart

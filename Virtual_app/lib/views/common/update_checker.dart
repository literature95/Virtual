import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/app_update_service.dart';
import 'app_dialogs.dart';

/// 启动后检测更新并弹窗。
///
/// 1. **发现新版本**（远端 > 本地）：询问是否下载 APK —— 这是用户要的「软件里弹更新提示」。
/// 2. **升级后首启**（本地 version ≠ lastSeenVersion）：展示本版更新日志。
///
/// 远端版本来源：`/version.json` → 回退 `/api/app-info`。
class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({super.key, required this.child});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  bool _checked = false;
  final _service = AppUpdateService();

  @override
  void initState() {
    super.initState();
    // 稍延迟，避免抢首帧/登录弹窗
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), _check);
    });
  }

  Future<void> _check() async {
    if (_checked || !mounted) return;
    _checked = true;

    final settings = context.read<SettingsProvider>();
    final info = await PackageInfo.fromPlatform();
    final current = info.version;
    final last = settings.lastSeenVersion;

    RemoteAppInfo? remote;
    try {
      remote = await _service.fetchLatest(settings.backendBaseUrl);
    } catch (_) {
      remote = null;
    }

    // ── 1. 远端有更新包 → 弹「发现新版本」 ──
    if (remote != null &&
        AppUpdateService.isNewerVersion(remote.version, current) &&
        mounted) {
      await showUpdateDialog(
        context,
        version: remote.version,
        currentVersion: current,
        changes: remote.changes.isEmpty
            ? const [
                '修复发动态定位（高德 Web服务 Key）',
                '全页发布动态',
                '品牌图标与 Web 端统一',
                '对话页状态栏避让',
              ]
            : remote.changes,
        downloadUrl: remote.downloadUrl ?? AppUpdateService.fallbackDownloadUrl,
        mode: UpdateDialogMode.available,
      );
      // 用户点了下载/知道了：仍记下「已看过此提示」用远端版本，避免每次启动都弹
      // （真正装上新包后 lastSeen 会被刷成安装版本）
      settings.setLastSeenVersion('seen-remote:${remote.version}');
      return;
    }

    // ── 2. 本机刚升级：展示更新日志 ──
    if (last != null &&
        last != current &&
        !last.startsWith('seen-remote:') &&
        mounted) {
      await showUpdateDialog(
        context,
        version: current,
        currentVersion: current,
        changes: const [
          '发动态支持定位（高德）',
          '底栏「+」全页发布',
          '品牌图标统一',
          '问题修复与稳定性提升',
        ],
        downloadUrl: AppUpdateService.fallbackDownloadUrl,
        mode: UpdateDialogMode.changelog,
      );
    }

    if (mounted) settings.setLastSeenVersion(current);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

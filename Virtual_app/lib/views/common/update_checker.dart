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
    // 必须带上 buildNumber：pubspec 的 x.y.z+build，version 字段只是 x.y.z
    final current = '${info.version}+${info.buildNumber}';
    final last = settings.lastSeenVersion;

    RemoteAppInfo? remote;
    try {
      remote = await _service.fetchLatest(settings.backendBaseUrl);
    } catch (_) {
      remote = null;
    }

    // ── 1. 远端**严格更新** → 弹「发现新版本」 ──
    // 本地已等于线上时（例如均为 1.0.11+12）**不弹**，这是预期行为。
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
      settings.setLastSeenVersion('seen-remote:${remote.version}');
      return;
    }

    // ── 2. 本机刚升级：展示更新日志 ──
    // last 存的可能是 x.y.z（旧逻辑）或 x.y.z+build，比较时只看主版本号变化
    final lastCore = last?.split('+').first;
    final curCore = current.split('+').first;
    if (last != null &&
        last != current &&
        lastCore != curCore &&
        !last.startsWith('seen-remote:') &&
        mounted) {
      await showUpdateDialog(
        context,
        version: info.version,
        currentVersion: current,
        changes: const [
          '底栏「发现」默认进入角色卡流',
          '设置/关于统一 Virtual 品牌',
          '发动态定位与全页发布',
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

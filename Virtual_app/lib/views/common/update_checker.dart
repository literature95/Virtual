import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/app_update_service.dart';
import 'app_dialogs.dart';

/// **每次冷启动**都做版本校验（用户要求）。
///
/// 行为：
/// 1. 启动约 1.5s 后请求 `{backend}/version.json`（失败则 `/api/app-info`）
/// 2. 若远端 **严格高于** 本机 `version+build` → 弹「发现新版本」可下载
/// 3. 远端 ≤ 本机 → 静默（不打断）；升级后首启可看本版日志
/// 4. **不再永久屏蔽**同一远端版本：每次启动都会重新校验，过期未升级会再提示
///
/// 注意：≤1.0.7 的安装包没有本逻辑，需先手动装一次 ≥1.0.8。
class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({super.key, required this.child});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  bool _checking = false;
  final _service = AppUpdateService();

  @override
  void initState() {
    super.initState();
    // 每次启动（State 创建即冷启动）都校验
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 1500), _check);
    });
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;

    final settings = context.read<SettingsProvider>();
    final info = await PackageInfo.fromPlatform();
    final current = '${info.version}+${info.buildNumber}';
    final last = settings.lastSeenVersion;

    RemoteAppInfo? remote;
    try {
      remote = await _service.fetchLatest(settings.backendBaseUrl);
    } catch (_) {
      remote = null;
    }

    // ── 远端更新：每次启动校验，只要仍落后就提示 ──
    if (remote != null &&
        AppUpdateService.isNewerVersion(remote.version, current) &&
        mounted) {
      await showUpdateDialog(
        context,
        version: remote.version,
        currentVersion: current,
        changes: remote.changes.isEmpty
            ? const [
                '请升级到最新版 Virtual',
                '可前往官网或 GitHub Releases 下载',
              ]
            : remote.changes,
        downloadUrl: remote.downloadUrl ?? AppUpdateService.fallbackDownloadUrl,
        mode: UpdateDialogMode.available,
      );
      // 记录「见过该远端版本」仅用于升级日志；**不阻止**下次启动再校验/再提示
      settings.setLastSeenVersion('seen-remote:${remote.version}');
      if (mounted) setState(() => _checking = false);
      return;
    }

    // ── 本机主版本号变化：展示升级日志（仅一次）──
    final lastCore = last?.split('+').first;
    final curCore = current.split('+').first;
    if (last != null &&
        last != current &&
        lastCore != curCore &&
        !(last.startsWith('seen-remote:') &&
            last.contains(curCore)) &&
        mounted) {
      await showUpdateDialog(
        context,
        version: info.version,
        currentVersion: current,
        changes: const [
          '发现页角色卡流与 Virtual 品牌统一',
          '发动态定位 / 全页发布',
          '应用内每次启动检查更新',
        ],
        downloadUrl: AppUpdateService.fallbackDownloadUrl,
        mode: UpdateDialogMode.changelog,
      );
    }

    if (mounted) {
      settings.setLastSeenVersion(current);
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

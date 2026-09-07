import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import 'app_dialogs.dart';

/// 启动后检测版本变化，弹出版本更新日志
///
/// - 首次启动（lastSeenVersion 为空）不弹
/// - 之后每次启动若版本号变化则弹窗，并记录新版本
class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({super.key, required this.child});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked || !mounted) return;
    _checked = true;

    final settings = context.read<SettingsProvider>();
    final info = await PackageInfo.fromPlatform();
    final current = info.version;
    final last = settings.lastSeenVersion;

    if (last != null && last != current && mounted) {
      await showUpdateDialog(
        context,
        version: current,
        changes: const [
          '全新的引导体验与品牌视觉',
          'Web 端响应式布局优化',
          '角色 / 接口空状态插画',
          '问题修复与稳定性提升',
        ],
      );
    }
    settings.setLastSeenVersion(current);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/tavo_brand.dart';

/// 用系统浏览器/下载管理器打开链接。
///
/// Android 上 `canLaunchUrl` 常因 package visibility 返回 false，
/// 导致「立即更新」点了没反应 —— 这里**不再用 canLaunchUrl 作前置门槛**，
/// 直接 launchUrl，并在失败时回退其它 mode。
Future<bool> openExternalUrl(String raw) async {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return false;

  const modes = <LaunchMode>[
    LaunchMode.externalApplication,
    LaunchMode.platformDefault,
    LaunchMode.inAppBrowserView,
  ];
  for (final mode in modes) {
    try {
      final ok = await launchUrl(uri, mode: mode);
      if (ok) return true;
    } catch (_) {
      // 尝试下一 mode
    }
  }
  return false;
}

// ════════════════════════════════════════════════════════════════════
// 隐私弹窗 — 对应截图 #4（盾牌图标 + 数据隐私说明）
// ════════════════════════════════════════════════════════════════════

Future<bool> showPrivacyDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (ctx) => _PrivacyDialog(),
  );
  return result ?? false;
}

class _PrivacyDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 顶部盾牌插图区 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 28, bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE8ECFF).withValues(alpha: 0.9),
                    const Color(0xFFD4E0FF).withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // 盾牌图标
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      size: 44,
                      color: const Color(0xFF5B8DEF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 标题
                  const Text(
                    '数据与隐私说明',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),

            // ── 正文内容 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '当你发送消息或图片时，以下数据会从当前设备直接发送到你配置的 AI 服务商（如 OpenAI、Google、OpenRouter 等）：',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.65,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• 你输入的消息及附带的图片\n'
                    '• 对话历史、角色设定、世界书、预设及长记忆',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Virtual 不会在其服务器上存储或中转上述内容',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 了解更多链接
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(
                            'https://virtual.literature95.com/#privacy');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        '了解更多',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: TavoColors.brandPurple,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── 按钮行 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  // 退出应用
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        '退出应用',
                        style:
                            TextStyle(color: Color(0xFF666666), fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 同意并继续（渐变按钮）
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7F77DD), Color(0xFFD85A30)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          '同意并继续',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 版本更新弹窗 — 对应截图 #5（火箭图 + 更新日志列表）
// ════════════════════════════════════════════════════════════════════

/// 版本弹窗：changelog=升级后日志；available=发现远端新包可下载
enum UpdateDialogMode { changelog, available }

Future<void> showUpdateDialog(
  BuildContext context, {
  required String version,
  List<String> changes = const [],
  String? currentVersion,
  String? downloadUrl,
  UpdateDialogMode mode = UpdateDialogMode.changelog,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _UpdateDialog(
      version: version,
      changes: changes,
      currentVersion: currentVersion,
      downloadUrl: downloadUrl,
      mode: mode,
    ),
  );
}

class _UpdateDialog extends StatelessWidget {
  final String version;
  final List<String> changes;
  final String? currentVersion;
  final String? downloadUrl;
  final UpdateDialogMode mode;

  const _UpdateDialog({
    required this.version,
    this.changes = const [],
    this.currentVersion,
    this.downloadUrl,
    this.mode = UpdateDialogMode.changelog,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = mode == UpdateDialogMode.available;
    final url = downloadUrl?.trim().isNotEmpty == true
        ? downloadUrl!.trim()
        : 'https://virtual.literature95.com/app-release.apk';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 顶部火箭插图 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 30, bottom: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFE3F0FD),
                    const Color(0xFFF0E8FF).withValues(alpha: 0.6),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.rocket_launch_outlined,
                      size: 42,
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isAvailable ? '发现新版本' : '新版本升级',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),

            // ── 版本号 ──
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                isAvailable && currentVersion != null
                    ? 'v$currentVersion  →  v$version'
                    : 'v$version',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),

            // ── 更新日志列表 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (changes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        isAvailable
                            ? '检测到服务器上有更新的安装包，建议尽快升级。'
                            : '- 问题修复与稳定性提升',
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.65,
                            color: Colors.grey[650]),
                      ),
                    )
                  else
                    ...changes.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('- ', style: TextStyle(height: 1.6)),
                              Expanded(
                                  child: Text(c,
                                      style: TextStyle(
                                          fontSize: 13,
                                          height: 1.6,
                                          color: Colors.grey[650]))),
                            ],
                          ),
                        )),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 跳过此版本
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  isAvailable ? '稍后再说' : '跳过此版本',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── 按钮行 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('关闭',
                          style: TextStyle(
                              color: Colors.grey[600]!, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.maybeOf(context);
                        final nav = Navigator.of(context, rootNavigator: true);
                        nav.pop();
                        final ok = await openExternalUrl(url);
                        if (!ok && messenger != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('无法打开下载页：$url')),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7F77DD),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                      child: Text(
                        isAvailable ? '立即下载' : '查看下载',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

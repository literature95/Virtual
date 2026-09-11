import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/endpoint_provider.dart';
import '../../theme/tavo_brand.dart';

/// 我的 —— 用户区块 + 本地资产概览 + 导航入口
/// （API接入 / 更多 在此页面内点击进入）
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final characterCount =
        context.watch<CharacterProvider>().characters.length;
    final endpointCount =
        context.watch<EndpointProvider>().llmEndpoints.length;
    final auth = context.watch<AuthProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── 第一区块：头像 / 昵称 / 账号（未登录点按去登录，已登录长按退出）──
        _section(
          scheme: scheme,
          child: GestureDetector(
            onTap: () =>
                auth.isLoggedIn ? null : context.push('/login'),
            onLongPress: auth.isLoggedIn ? () => _confirmLogout(context) : null,
            child: Row(
              children: [
              // 品牌渐变气泡头像（对话气泡形，与 Web 端 mark 统一）
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: TavoColors.signGradientDiagonal,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(999),
                    topRight: Radius.circular(999),
                    bottomLeft: Radius.circular(999),
                    bottomRight: Radius.circular(14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TavoColors.violet.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  auth.isLoggedIn
                      ? (auth.user!.nickname?.isNotEmpty == true
                          ? auth.user!.nickname!.characters.first
                          : auth.user!.email.characters.first)
                      : 'V',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141414),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          auth.isLoggedIn ? null : context.push('/login'),
                      child: Text(
                        auth.isLoggedIn
                            ? (auth.user!.nickname?.isNotEmpty == true
                                ? auth.user!.nickname!
                                : 'Virtual 用户')
                            : '点击登录 / 注册',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () =>
                          auth.isLoggedIn ? null : context.push('/register'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Text(
                          auth.isLoggedIn
                              ? auth.user!.email
                              : 'ID · LOCAL-0001 · 本地模式',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (auth.isLoggedIn)
                IconButton(
                  icon: Icon(Icons.logout,
                      size: 20, color: scheme.onSurfaceVariant),
                  tooltip: '退出登录',
                  onPressed: () => _confirmLogout(context),
                ),
            ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── 第二区块：我的角色卡 ──
        _section(
          scheme: scheme,
          child: _assetRow(
            scheme: scheme,
            icon: Icons.face_3,
            iconColor: TavoColors.violet,
            title: '我的角色卡',
            subtitle: '本地创建与导入的角色',
            count: characterCount,
            onTap: () => context.go('/characters'),
          ),
        ),
        const SizedBox(height: 14),

        // ── 第三区块：我的 API / 主题 等 ──
        _section(
          scheme: scheme,
          child: Column(
            children: [
              _navRow(
                scheme: scheme,
                icon: Icons.api,
                iconColor: TavoColors.coral,
                title: '我的 API',
                desc: '$endpointCount 个接入端点',
                onTap: () => context.go('/endpoints'),
              ),
              Divider(
                  height: 1,
                  indent: 46,
                  color: scheme.outlineVariant),
              _navRow(
                scheme: scheme,
                icon: Icons.palette_outlined,
                iconColor: TavoColors.amber,
                title: '主题外观',
                desc: '深空 / 亮色主题',
                onTap: () => context.go('/theme'),
              ),
              Divider(
                  height: 1,
                  indent: 46,
                  color: scheme.outlineVariant),
              _navRow(
                scheme: scheme,
                icon: Icons.extension_outlined,
                iconColor: TavoColors.cosmosGreen,
                title: '插件',
                desc: '扩展能力中心',
                onTap: () => context.go('/plugins'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 第四区块：更多 ──
        _section(
          scheme: scheme,
          child: _navRow(
            scheme: scheme,
            icon: Icons.more_horiz,
            iconColor: scheme.onSurfaceVariant,
            title: '更多',
            desc: '设置 · 备份 · 帮助',
            onTap: () => context.go('/more'),
          ),
        ),
      ],
    );
  }

  /// 退出登录确认（长按用户区块或点右上角退出图标）
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('本地数据不受影响，仅清除登录状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  Widget _section({required ColorScheme scheme, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _assetRow({
    required ColorScheme scheme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int count,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          _iconBox(icon, iconColor),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _navRow({
    required ColorScheme scheme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            _iconBox(icon, iconColor),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                  const SizedBox(height: 1),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

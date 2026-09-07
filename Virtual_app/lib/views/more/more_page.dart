import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 「更多」设置中心页 — 对应官方截图 #10 的完整分组列表
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更多'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── 第一组：核心功能 ──
          _MoreTile(
              label: 'API连接',
              icon: Icons.api_outlined,
              onTap: () => context.go('/endpoints')),
          _MoreTile(
              label: '角色',
              icon: Icons.person_outline,
              onTap: () => context.go('/characters')),
          _MoreTile(
            label: '用户身份',
            trailing: const Text('User',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            onTap: () {},
          ),

          const SizedBox(height: 8),

          // ── 第二组：外观与语音 ──
          _MoreTile(
            label: '主题',
            trailing: const Text('渊海',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            onTap: () => context.go('/theme'),
          ),
          _MoreTile(
              label: '语音与生圈',
              icon: Icons.record_voice_over_outlined,
              onTap: () => context.go('/settings/tts')),

          const SizedBox(height: 8),

          // ── 第三组：高级配置 ──
          _MoreTile(
              label: '模型设置', icon: Icons.model_training_outlined, onTap: () {}),
          _MoreTile(
            label: '预设',
            trailing: const Text('默认',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            onTap: () => context.go('/presets'),
          ),
          _MoreTile(
              label: '世界书',
              icon: Icons.menu_book_outlined,
              onTap: () => context.go('/lorebooks')),
          _MoreTile(
              label: '正则',
              icon: Icons.text_fields_outlined,
              onTap: () => context.go('/regex')),
          _MoreTile(
              label: '长记忆', icon: Icons.psychology_outlined, onTap: () {}),

          const SizedBox(height: 8),

          // ── 第四组：插件 ──
          _MoreTile(
            label: '插件',
            badge: 'BETA',
            badgeColor: const Color(0xFF7F77DD),
            icon: Icons.extension_outlined,
            onTap: () => context.go('/plugins'),
          ),

          const SizedBox(height: 8),

          // ── 第五组：系统 ──
          _MoreTile(
              label: '设置',
              icon: Icons.settings_outlined,
              onTap: () => context.go('/settings')),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// 通用列表项组件
class _MoreTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? trailing;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const _MoreTile({
    required this.label,
    this.icon,
    this.trailing,
    this.badge,
    this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: Colors.grey[700]),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 15.5, color: Color(0xFF1A1A2E)),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? const Color(0xFFFF6F00))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: badgeColor ?? const Color(0xFFFF6F00),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null)
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

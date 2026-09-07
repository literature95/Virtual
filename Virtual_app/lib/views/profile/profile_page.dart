import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/character_provider.dart';
import '../../providers/endpoint_provider.dart';
import '../../theme/tavo_brand.dart';

/// 我的 —— 用户区块 + 本地资产概览 + 导航入口
/// （API接入 / 更多 在此页面内点击进入）
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final characterCount =
        context.watch<CharacterProvider>().characters.length;
    final endpointCount =
        context.watch<EndpointProvider>().llmEndpoints.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── 第一区块：头像 / 昵称 / 账号 ID ──
        _section(
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
                child: const Text(
                  'V',
                  style: TextStyle(
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
                    const Text(
                      'Virtual 用户',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: TavoColors.cosmosText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 2.5),
                      decoration: TavoColors.glassCapsule(),
                      child: const Text(
                        'ID · LOCAL-0001',
                        style: TextStyle(
                          fontSize: 11,
                          color: TavoColors.cosmosTextDim,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 第二区块：我的角色卡 ──
        _section(
          child: _assetRow(
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
          child: Column(
            children: [
              _navRow(
                icon: Icons.api,
                iconColor: TavoColors.coral,
                title: '我的 API',
                desc: '$endpointCount 个接入端点',
                onTap: () => context.go('/endpoints'),
              ),
              Divider(
                  height: 1,
                  indent: 46,
                  color: Colors.white.withValues(alpha: 0.06)),
              _navRow(
                icon: Icons.palette_outlined,
                iconColor: TavoColors.amber,
                title: '主题外观',
                desc: '深空 / 亮色主题',
                onTap: () => context.go('/theme'),
              ),
              Divider(
                  height: 1,
                  indent: 46,
                  color: Colors.white.withValues(alpha: 0.06)),
              _navRow(
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
          child: _navRow(
            icon: Icons.more_horiz,
            iconColor: TavoColors.cosmosTextDim,
            title: '更多',
            desc: '设置 · 备份 · 帮助',
            onTap: () => context.go('/more'),
          ),
        ),
      ],
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TavoColors.cosmosElev.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TavoColors.cosmosLine),
      ),
      child: child,
    );
  }

  Widget _assetRow({
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
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: TavoColors.cosmosText)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: TavoColors.cosmosTextFaint)),
              ],
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: TavoColors.cosmosTextDim,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              size: 20, color: TavoColors.cosmosTextFaint),
        ],
      ),
    );
  }

  Widget _navRow({
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
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: TavoColors.cosmosText)),
                  const SizedBox(height: 1),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: TavoColors.cosmosTextFaint)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: TavoColors.cosmosTextFaint),
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

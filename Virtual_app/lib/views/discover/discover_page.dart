import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tavo_brand.dart';

/// 发现页 —— 扩展内容聚合入口：世界书 / 预设 / 正则 / 插件 / 主题
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.35,
      children: [
        _entryCard(
          context,
          icon: Icons.menu_book_outlined,
          title: '世界书',
          desc: 'Lorebook 设定集',
          route: '/lorebooks',
          accent: TavoColors.violet,
        ),
        _entryCard(
          context,
          icon: Icons.tune,
          title: '预设',
          desc: 'Prompt 组合方案',
          route: '/presets',
          accent: TavoColors.coral,
        ),
        _entryCard(
          context,
          icon: Icons.manage_history_outlined,
          title: '正则',
          desc: '输出文本处理规则',
          route: '/regex',
          accent: TavoColors.amber,
        ),
        _entryCard(
          context,
          icon: Icons.extension_outlined,
          title: '插件',
          desc: '扩展能力中心',
          route: '/plugins',
          accent: TavoColors.cosmosGreen,
        ),
        _entryCard(
          context,
          icon: Icons.palette_outlined,
          title: '主题',
          desc: '外观与配色',
          route: '/theme',
          accent: TavoColors.brandPurpleLight,
        ),
        _entryCard(
          context,
          icon: Icons.bug_report_outlined,
          title: '调试',
          desc: '开发者工具',
          route: '/debug',
          accent: TavoColors.cosmosTextFaint,
        ),
      ],
    );
  }

  Widget _entryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required String route,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: TavoColors.cosmosElev,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TavoColors.cosmosLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: 21, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: TavoColors.cosmosText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 12,
                color: TavoColors.cosmosTextFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

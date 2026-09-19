import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';

/// 底栏 / 导航栏中间的「发动态」按钮：黑底圆角方框 + 白色加号
class ComposeNavIcon extends StatelessWidget {
  final double size;

  const ComposeNavIcon({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
      ),
      child: Icon(Icons.add, color: Colors.white, size: size * 0.62),
    );
  }
}

/// 打开全页发布（不再使用 AlertDialog）。
///
/// 未登录跳登录；发布成功返回 [CommunityPost]，取消返回 null。
Future<CommunityPost?> openComposePage(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  if (!auth.isLoggedIn) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再发动态')),
      );
      context.go('/login');
    }
    return null;
  }
  return context.push<CommunityPost>('/compose');
}

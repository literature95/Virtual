import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tavo_brand.dart';
import '../common/cosmos_background.dart';
import 'home_page.dart';

/// 主框架 — 5 Tab 导航：
///
/// - 底部导航：首页 | 发现 | 对话 | 角色 | 我的
/// - AppBar 按路由条件渲染：
///   - 首页：右上角搜索图标
///   - 角色：右上角 "+"（新建角色）
///   - API接入（/endpoints）：右上角 "+"（新增端点）
///   - 其余页面不显示 "+"
/// - 左上角 ☰ 抽屉：复用「我的」的导航内容
/// - 宽屏：左侧 NavigationRail（同样 5 项）
class HomeShell extends StatelessWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  static const _tabs = [
    (
      path: '/home',
      label: '首页',
      icon: Icons.home_outlined,
      activeIcon: Icons.home
    ),
    (
      path: '/discover',
      label: '发现',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore
    ),
    (
      path: '/chat',
      label: '对话',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble
    ),
    (
      path: '/characters',
      label: '角色',
      icon: Icons.face_3_outlined,
      activeIcon: Icons.face_3
    ),
    (
      path: '/profile',
      label: '我的',
      icon: Icons.person_outline,
      activeIcon: Icons.person
    ),
  ];

  /// 当前选中的 Tab（子页面归到其所属 Tab：endpoints/settings→我的，lorebooks 等→发现）
  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/home')) return 0;
    if (loc.startsWith('/discover') ||
        loc.startsWith('/lorebook') ||
        loc.startsWith('/preset') ||
        loc.startsWith('/regex') ||
        loc.startsWith('/plugin') ||
        loc.startsWith('/theme') ||
        loc.startsWith('/debug')) {
      return 1;
    }
    if (loc.startsWith('/chat')) return 2;
    if (loc.startsWith('/character')) return 3;
    return 4; // /profile、/endpoints、/more、/settings 等归入我的
  }

  void _onTap(BuildContext context, int index) => context.go(_tabs[index].path);

  /// 是否一级 Tab 页面（精确匹配根路径，详情/编辑页不算）
  bool _isRootTab(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    return _tabs.any((t) => loc == t.path);
  }

  /// 是否显示右上角 "+"
  bool _showPlus(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    return loc.startsWith('/character') || loc.startsWith('/endpoint');
  }

  /// 内容居中限宽
  Widget _centered(Widget child, double screenWidth) {
    final isWide = screenWidth >= 720;
    final maxW = isWide ? 560.0 : double.infinity;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 720;
    final index = _currentIndex(context);

    // ── 宽屏模式：左侧导航栏 ──
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _onTap(context, i),
              labelType: NavigationRailLabelType.all,
              leading: Column(
                children: [
                  const SizedBox(height: 16),
                  _brandAvatar(size: 40),
                  const SizedBox(height: 6),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        TavoColors.signGradient.createShader(bounds),
                    child: const Text(
                      'Virtual',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.activeIcon),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(thickness: 1),
            Expanded(
              child: Scaffold(
                appBar: _buildAppBar(context),
                body: _centered(child, screenWidth),
                drawer: _buildDrawer(context),
              ),
            ),
          ],
        ),
      );
    }

    // ── 窄屏模式：底部导航 + AppBar + 抽屉 ──
    return Scaffold(
      appBar: _buildAppBar(context),
      drawer: _buildDrawer(context),
      body: CosmosBackground(child: _centered(child, screenWidth)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }

  /// 品牌气泡头像（对话气泡形 + 签名渐变，与 Web 端 mark 统一）
  Widget _brandAvatar({double size = 62}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: TavoColors.signGradientDiagonal,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size),
          topRight: Radius.circular(size),
          bottomLeft: Radius.circular(size),
          bottomRight: Radius.circular(size * 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: TavoColors.violet.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'V',
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF141414),
        ),
      ),
    );
  }

  // ── AppBar：条件渲染 ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isRoot = _isRootTab(context);
    final loc = GoRouterState.of(context).uri.path;

    return AppBar(
      // ── 左侧：菜单 ☰ + 紧随其后的品牌 logo（左对齐）──
      leading: isRoot
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, size: 24),
                    onPressed: Scaffold.of(ctx).openDrawer,
                    tooltip: '菜单',
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      TavoColors.signGradient.createShader(bounds),
                  child: const Text(
                    'Virtual',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          : BackButton(onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            }),
      leadingWidth: isRoot ? 130 : null,
      actions: [
        // 首页 → 搜索图标
        if (loc.startsWith('/home'))
          IconButton(
            icon: const Icon(Icons.search, size: 23),
            tooltip: '搜索',
            onPressed: () => HomePage.searchVisible.value = true,
          ),
        // 角色 / API接入 → "+" 新建
        if (_showPlus(context))
          IconButton(
            icon: const Icon(Icons.add, size: 24),
            tooltip: '新建',
            onPressed: () {
              if (loc.startsWith('/endpoint')) {
                context.go('/endpoint/new');
              } else {
                context.push('/character/new');
              }
            },
          ),
        const SizedBox(width: 4),
      ],
      elevation: 0,
    );
  }

  // ── 侧边抽屉：复用「我的」的导航内容 ─────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    return Drawer(
      width: 288,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: CosmosDrawerBody(
        currentPath: loc,
        brandAvatar: _brandAvatar(size: 56),
      ),
    );
  }
}

/// 抽屉主体：深空背景 + 用户区块 + 与「我的」一致的导航项
class CosmosDrawerBody extends StatelessWidget {
  final String currentPath;
  final Widget brandAvatar;

  const CosmosDrawerBody({
    super.key,
    required this.currentPath,
    required this.brandAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: [
            // ── 头部：头像 / 昵称 / ID ──
            Row(
              children: [
                brandAvatar,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Virtual 用户',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID · LOCAL-0001',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 20, color: scheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── 签名渐变分隔线 ──
            Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: TavoColors.signGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── 一级 Tab 导航（与底部导航一致）──
            ..._navItems(context, [
              (Icons.home_outlined, '首页', '/home'),
              (Icons.explore_outlined, '发现', '/discover'),
              (Icons.chat_bubble_outline, '对话', '/chat'),
              (Icons.face_3_outlined, '角色', '/characters'),
            ]),

            _sectionLabel(context, '我的'),
            ..._navItems(context, [
              (Icons.person_outline, '我的', '/profile'),
              (Icons.api, 'API接入', '/endpoints'),
              (Icons.more_horiz, '更多', '/more'),
            ]),

            _sectionLabel(context, '扩展'),
            ..._navItems(context, [
              (Icons.menu_book_outlined, '世界书', '/lorebooks'),
              (Icons.tune, '预设', '/presets'),
              (Icons.manage_history_outlined, '正则', '/regex'),
              (Icons.extension_outlined, '插件', '/plugins'),
              (Icons.palette_outlined, '主题', '/theme'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 0, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<Widget> _navItems(
      BuildContext context, List<(IconData, String, String)> items) {
    final scheme = Theme.of(context).colorScheme;
    return items.map((item) {
      final (icon, label, route) = item;
      final selected =
          currentPath == route || currentPath.startsWith('$route/');
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.pop(context);
              context.go(route);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: selected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: scheme.primary.withValues(alpha: 0.12),
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.4)),
                    )
                  : null,
              child: Row(
                children: [
                  Icon(icon,
                      size: 20,
                      color:
                          selected ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: 13),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color:
                          selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

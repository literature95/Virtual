import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tavo_brand.dart';
import '../common/cosmos_background.dart';
import '../discover/compose_post_dialog.dart';

/// 主框架 — 底栏 5 位：首页 | 发现 | 发布(＋) | 角色 | 我的
///
/// - 中间「＋」是**动作**不是 Tab：点按进入全页 `/compose` 发布，不切换选中态
/// - （「对话」已并入「角色」Tab：角色 Tab 内分「角色 / 历史 / 收藏」三段，
///    历史段承载会话列表，故底部不再单列对话）
/// - AppBar 按路由条件渲染：
///   - 首页：右上角搜索图标
///   - 接口页（/endpoint*）：页面自带 AppBar（返回+标题+新建），隐藏 shell 的
///   - 其余页面不显示 "+"（角色 Tab 的 "+" 由其内部 AppBar 自绘）
/// - 左上角 ☰ 抽屉：复用「我的」的导航内容
/// - 宽屏：左侧 NavigationRail（同样含中间发布按钮）
class HomeShell extends StatelessWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  /// 一级 Tab（不含中间发布动作位）
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

  /// 底栏 5 个槽位索引：0 首页 · 1 发现 · 2 发布 · 3 角色 · 4 我的
  static const int _composeNavIndex = 2;

  /// 当前选中的底栏槽位（发布位永不选中）
  ///
  /// 注意：`/chat` 与 `/chat/:id` 仍保留为独立路由（会话详情从多处入口跳入），
  /// 但导航高亮归属「角色」Tab —— 历史会话就在角色 Tab 的「历史」段里。
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
    if (loc.startsWith('/chat') || loc.startsWith('/character')) return 3;
    return 4; // /profile、/endpoints、/more、/settings 等归入我的
  }

  /// 底栏槽位 → 路由；发布位打开对话框
  /// 底栏槽位 → 路由；发布位打开**全页**发布（非对话框）
  Future<void> _onNavTap(BuildContext context, int index) async {
    if (index == _composeNavIndex) {
      final created = await openComposePage(context);
      if (created != null && context.mounted) {
        context.go('/discover');
      }
      return;
    }
    // 槽位 → _tabs 下标：2 之后要减 1（跳过发布位）
    final tabIndex = index > _composeNavIndex ? index - 1 : index;
    if (tabIndex >= 0 && tabIndex < _tabs.length) {
      context.go(_tabs[tabIndex].path);
    }
  }

  /// 是否一级 Tab 页面（精确匹配根路径，详情/编辑页不算）
  bool _isRootTab(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    return _tabs.any((t) => loc == t.path);
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

  // ── 顶栏隐藏 / 状态栏避让 ─────────────────────────────────────────

  /// shell 是否隐藏自己的 AppBar（页面自带顶栏，或沉浸式页面自绘浮层）
  ///
  /// 抽成**单一事实来源**：`_buildAppBar` 与 [_withStatusBarInset] 都读它。
  /// 此前只写在 `_buildAppBar` 里，导致新增隐藏条件时极容易漏补状态栏内边距
  /// —— 而这类问题在模拟器上看不出来，只在真机刘海/挖孔屏上才暴露。
  bool _hideShellAppBar(String loc) {
    // 发现页：自带「关注 / 推荐」TabBar
    if (loc == '/discover') return true;
    // 搜索筛选页 / 分类页：自带「返回 + 搜索框 + 搜索」一体化 AppBar
    if (loc == '/home/search' || loc.startsWith('/home/category/')) return true;
    // 对话页：/chat、/chat/:id；角色 Tab：/characters；我的页：/profile
    // **更多 /more**：页面自带顶栏（返回+标题同一行），shell 必须隐藏，否则双层栏
    // 角色卡详情：/home/character/:id（沉浸式立绘，extendBodyBehindAppBar）
    // 接口页：/endpoints、/endpoint/new、/endpoint/:id/edit
    return loc == '/chat' ||
        loc.startsWith('/chat/') ||
        loc.startsWith('/character') ||
        loc.startsWith('/home/character/') ||
        loc.startsWith('/endpoint') ||
        loc.startsWith('/settings') ||
        loc == '/more' ||
        loc.startsWith('/more/') ||
        loc == '/profile';
  }

  /// 沉浸式页面：shell **不**补状态栏内边距，由页面自行处理
  ///
  /// - `/chat*`：页面用 `InsetAppBar` 自避让——顶栏与首页一致下推状态栏；
  ///   设了对话背景时背景仍 `Positioned.fill` 铺到状态栏后面（顶栏避让+背景全屏）。
  ///   若 shell 再补一层 inset，会与页面自避让叠成双倍偏移。
  /// - `/home/character/`：角色卡详情沉浸式立绘，有意铺到状态栏之后。
  bool _isImmersive(String loc) =>
      loc.startsWith('/chat') || loc.startsWith('/home/character/');

  /// 给「隐藏了 shell AppBar」的页面补回状态栏内边距
  ///
  /// 🔴 根因（真机 APK 实测，2026-09-17）：shell 用 `PreferredSize(height: 0)`
  /// 的**零高 AppBar** 隐藏顶栏，而 `Scaffold` 只要 `appBar != null` 就会对
  /// body 执行 `removeTopPadding` —— 于是 body 里的 `MediaQuery.padding.top`
  /// 被清成 0。自带顶部栏的页面既拿不到内边距、又不会自动避让，顶部内容直接
  /// 压进状态栏（状态栏时间与页面标题重叠）；而首页因为有真实 AppBar 反而正常。
  ///
  /// 这里显式补等量内边距，并用 `scaffoldBackgroundColor` 填色，让这条带子与
  /// AppBar 背景同色（与首页观感一致），不出现色差接缝。
  /// 对话页（`/chat*`）不走这里：见 [_isImmersive]，由 `InsetAppBar` 自避让，
  /// 以便背景图仍能铺到状态栏后面。
  ///
  /// 注意：**不要**改成「把 shell AppBar 置为 null」来修 —— 那会恢复 body 的
  /// `padding.top`，使页面内层 Scaffold / SafeArea 再各补一次，变成双倍偏移。
  Widget _withStatusBarInset(BuildContext context, String loc, Widget child) {
    if (!_hideShellAppBar(loc) || _isImmersive(loc)) return child;
    final inset = MediaQuery.of(context).padding.top;
    if (inset <= 0) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.only(top: inset),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 720;
    final index = _currentIndex(context);
    final loc = GoRouterState.of(context).uri.path;
    // 对话窗口（/chat*）不显示底部导航栏 / 左侧导航栏（沉浸阅读区）
    final isChat = loc.startsWith('/chat');

    // ── 宽屏模式：左侧导航栏 ──
    if (isWide) {
      // 对话窗口：全屏，无左侧导航栏
      if (isChat) {
        return Scaffold(
          appBar: _buildAppBar(context),
          body: CosmosBackground(
            child: _withStatusBarInset(
              context,
              loc,
              _centered(child, screenWidth),
            ),
          ),
        );
      }
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _onNavTap(context, i),
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
                NavigationRailDestination(
                  icon: Icon(_tabs[0].icon),
                  selectedIcon: Icon(_tabs[0].activeIcon),
                  label: Text(_tabs[0].label),
                ),
                NavigationRailDestination(
                  icon: Icon(_tabs[1].icon),
                  selectedIcon: Icon(_tabs[1].activeIcon),
                  label: Text(_tabs[1].label),
                ),
                // 中间：发动态（动作位，不参与选中高亮）
                const NavigationRailDestination(
                  icon: ComposeNavIcon(size: 34),
                  selectedIcon: ComposeNavIcon(size: 34),
                  label: Text('发布'),
                ),
                NavigationRailDestination(
                  icon: Icon(_tabs[2].icon),
                  selectedIcon: Icon(_tabs[2].activeIcon),
                  label: Text(_tabs[2].label),
                ),
                NavigationRailDestination(
                  icon: Icon(_tabs[3].icon),
                  selectedIcon: Icon(_tabs[3].activeIcon),
                  label: Text(_tabs[3].label),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1),
            Expanded(
              child: Scaffold(
                appBar: _buildAppBar(context),
                body: _withStatusBarInset(
                  context,
                  loc,
                  _centered(child, screenWidth),
                ),
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
      body: CosmosBackground(
        child: _withStatusBarInset(
          context,
          loc,
          _centered(child, screenWidth),
        ),
      ),
      // 对话窗口：不显示底部导航栏
      bottomNavigationBar: isChat
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => _onNavTap(context, i),
              destinations: [
                NavigationDestination(
                  icon: Icon(_tabs[0].icon),
                  selectedIcon: Icon(_tabs[0].activeIcon),
                  label: _tabs[0].label,
                ),
                NavigationDestination(
                  icon: Icon(_tabs[1].icon),
                  selectedIcon: Icon(_tabs[1].activeIcon),
                  label: _tabs[1].label,
                ),
                // 中间：发动态 —— 黑框白加号，点按弹发布框
                const NavigationDestination(
                  icon: ComposeNavIcon(),
                  selectedIcon: ComposeNavIcon(),
                  label: '发布',
                ),
                NavigationDestination(
                  icon: Icon(_tabs[2].icon),
                  selectedIcon: Icon(_tabs[2].activeIcon),
                  label: _tabs[2].label,
                ),
                NavigationDestination(
                  icon: Icon(_tabs[3].icon),
                  selectedIcon: Icon(_tabs[3].activeIcon),
                  label: _tabs[3].label,
                ),
              ],
            ),
    );
  }

  /// 品牌 mark：与 Web / 启动图标统一的渐变几何图（透明底）
  Widget _brandAvatar({double size = 62}) {
    return Image.asset(
      'assets/images/app_icon_grad.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: TavoColors.signGradientDiagonal,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        alignment: Alignment.center,
        child: Text(
          'V',
          style: TextStyle(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── AppBar：条件渲染 ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isRoot = _isRootTab(context);
    final loc = GoRouterState.of(context).uri.path;

    // 这些页面自带顶栏 / 沉浸式浮层，隐藏 shell AppBar 避免双层。
    // 条件见 [_hideShellAppBar]（同时驱动状态栏内边距补偿，勿在此处另写一份）。
    if (_hideShellAppBar(loc)) {
      return const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      );
    }

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
      // 菜单图标 + "Virtual" 字标实际宽度约 190px；写死 130 会在窄屏触发
      // RenderFlex overflow（右侧溢出 ~60px）。这里给足 210px 余量避免溢出。
      leadingWidth: isRoot ? 210 : null,
      actions: [
        // 首页 → 搜索图标（跳转到搜索筛选页）
        if (loc.startsWith('/home'))
          IconButton(
            icon: const Icon(Icons.search, size: 23),
            tooltip: '搜索',
            onPressed: () => context.go('/home/search'),
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

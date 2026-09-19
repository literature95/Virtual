import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/main.dart';
import 'package:virtual/route/app_router.dart';

/// 「顶部栏压进状态栏」的回归防线（真机 APK 反馈，2026-09-17）
///
/// 现象：APK 里首页正常，但「发现 / 角色 / 我的」顶部内容顶到状态栏下面
/// （状态栏时间与页面标题重叠）。
///
/// 根因：`HomeShell` 用 `PreferredSize(height: 0)` 的**零高 AppBar** 隐藏顶栏，
/// 而 `Scaffold` 只要 `appBar != null` 就会对 body 执行 `removeTopPadding`，
/// body 里的 `MediaQuery.padding.top` 被清成 0；自带顶部栏的页面于是既不自动
/// 避让、又拿不到内边距。首页因为有真实 AppBar 反而不受影响。
///
/// 这组用例把每个「隐藏 shell AppBar」的路由的顶部坐标钉死：
///   - 非沉浸式页面：shell `_withStatusBarInset` 补偿后，顶部栏落在 `状态栏高度 (44)`；
///   - 对话页（`/chat*`）：shell 不补（沉浸式名单），页面 `InsetAppBar` 自避让，
///     AppBar 仍须在 44；设背景时背景层可铺到 0（顶栏避让 + 背景全屏）；
///   - 角色卡详情：有意铺到状态栏之后（0）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 模拟状态栏：1080×2340 @3x，状态栏 132 物理像素 = 44 逻辑像素
  const statusBar = 44.0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('隐藏 shell AppBar 的页面必须避开状态栏；沉浸式页面保持不变', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final db = await AppDatabase.init();

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 132);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildAppProviders(
      prefs: prefs,
      database: db,
      child: MaterialApp.router(routerConfig: AppRouter.router),
    ));
    // pumpAndSettle：让初始构建 + 入场动画彻底稳定。
    // 整个用例泵起的时钟约 3s，短于首页 Banner 轮播的 5s Timer 间隔，
    // 因此轮播动画不会在测量期间触发、不会拖住 settle。
    await tester.pumpAndSettle();

    double topOf(Finder f, String label) {
      expect(f, findsWidgets, reason: '$label 未渲染，用例失去意义');
      return tester.getTopLeft(f.first).dy;
    }

    Future<void> go(String loc) async {
      AppRouter.router.go(loc);
      // 等路由过渡完全结束、退场页被移出树后再测量，
      // 避免 find.byType 命中退场页已 deactivate 的元素而抛异常。
      await tester.pumpAndSettle();
    }

    // ── 1. 首页：shell AppBar 正常显示，内容在「状态栏 + 工具栏」之下 ──
    await go('/home');
    expect(
      topOf(find.byType(AppBar), '/home AppBar'),
      0.0,
      reason: '首页 AppBar 应从屏幕顶端起、自身包含状态栏内边距',
    );
    expect(
      topOf(find.byType(AppBar), '/home AppBar') +
          tester.getSize(find.byType(AppBar)).height,
      statusBar + kToolbarHeight,
      reason: '首页 AppBar 高度应为 状态栏 44 + 工具栏 56',
    );

    // ── 2. 三个被反馈的 Tab 页 ──
    await go('/discover');
    expect(
      topOf(find.byType(TabBar), '/discover TabBar'),
      statusBar,
      reason: '发现页 TabBar 必须避让状态栏（此前为 0，与状态栏时间重叠）',
    );

    await go('/characters');
    expect(
      topOf(find.byType(AppBar), '/characters AppBar'),
      statusBar,
      reason: '角色页自带 AppBar 必须避让状态栏（此前为 0）',
    );

    await go('/profile');
    expect(
      topOf(find.byType(ListView), '/profile 内容'),
      statusBar,
      reason: '我的页内容必须避让状态栏（此前为 0）',
    );

    // ── 3. 同类页面（同样隐藏 shell AppBar）一并覆盖 ──
    await go('/endpoints');
    expect(
      topOf(find.byType(AppBar), '/endpoints AppBar'),
      statusBar,
      reason: 'API 接入页自带 AppBar 必须避让状态栏',
    );

    await go('/character/new');
    expect(
      topOf(find.byType(AppBar), '/character/new AppBar'),
      statusBar,
      reason: '角色编辑页自带 AppBar 必须避让状态栏',
    );

    // ── 4. 对话页：页面 InsetAppBar 自避让（shell 不再补），AppBar 仍在状态栏下 ──
    await go('/chat');
    expect(
      topOf(find.byType(AppBar), '/chat AppBar'),
      statusBar,
      reason: '对话页 AppBar 必须避让状态栏（InsetAppBar 自避让，与首页一致）',
    );

    // 角色卡详情仍为沉浸式立绘：有意铺到状态栏之后
    // （无角色数据时详情页仍会渲染 Scaffold/AppBar 结构，这里用路径探测）
    await go('/home/character/immersive-probe');
    final immersiveTop = tester.getTopLeft(find.byType(Scaffold).first).dy;
    expect(
      immersiveTop,
      0.0,
      reason: '角色卡详情页保持沉浸式，内容有意铺到状态栏之后',
    );

    // ── 5. 设置页：自带 AppBar 且已加入隐藏列表 → 避让状态栏，无双层 AppBar ──
    await go('/settings');
    // 用稳定 Key 直接命中「设置页自己的」AppBar，避开退场页/抽屉里的同名 widget。
    expect(
      tester.getTopLeft(find.byKey(const Key('settingsAppBar'))).dy,
      statusBar,
      reason: '设置页自带 AppBar（已加入隐藏列表）须避让状态栏，且不应出现双层 AppBar',
    );
  });
}

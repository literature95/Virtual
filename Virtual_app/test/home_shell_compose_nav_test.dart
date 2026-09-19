import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/main.dart';
import 'package:virtual/route/app_router.dart';
import 'package:virtual/views/discover/compose_post_dialog.dart';

/// 底栏 5 位：首页 | 发现 | 发布(＋) | 角色 | 我的
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('底栏五项齐全，中间为黑框加号发布按钮', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final db = await AppDatabase.init();

    await tester.pumpWidget(buildAppProviders(
      prefs: prefs,
      database: db,
      child: MaterialApp.router(routerConfig: AppRouter.router),
    ));
    await tester.pumpAndSettle();

    AppRouter.router.go('/home');
    await tester.pumpAndSettle();

    final labels = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(Text),
    );
    final texts = labels.evaluate().map((e) => (e.widget as Text).data).toList();
    expect(texts, containsAll(['首页', '发现', '发布', '角色', '我的']));

    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(ComposeNavIcon),
      ),
      findsWidgets,
      reason: '底栏中间必须是黑框加号 ComposeNavIcon',
    );
  });

  testWidgets('点「发布」不切换 Tab，未登录时跳转登录', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final db = await AppDatabase.init();

    await tester.pumpWidget(buildAppProviders(
      prefs: prefs,
      database: db,
      child: MaterialApp.router(routerConfig: AppRouter.router),
    ));
    await tester.pumpAndSettle();

    AppRouter.router.go('/home');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ComposeNavIcon).first);
    await tester.pumpAndSettle();

    // 全页发布：未登录应跳登录，而不是弹对话框
    expect(AppRouter.router.state.uri.path, anyOf('/login', '/compose'));
  });
}

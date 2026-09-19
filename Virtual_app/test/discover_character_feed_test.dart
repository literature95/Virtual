import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/providers/auth_provider.dart';
import 'package:virtual/providers/settings_provider.dart';
import 'package:virtual/views/discover/character_discover_feed.dart';
import 'package:virtual/views/discover/discover_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('发现页含推荐 / 发现 / 关注 三个 Tab', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    final auth = AuthProvider(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(home: Scaffold(body: DiscoverPage())),
      ),
    );
    // 让 Dio/网络假定时器跑完，避免 pending timer 断言
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('推荐'), findsWidgets);
    expect(find.text('发现'), findsWidgets);
    expect(find.text('关注'), findsWidgets);
    // 默认选中中间「发现」Tab（角色卡流），而不是「推荐」
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller?.index, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('角色卡流可构建且不抛异常', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CharacterDiscoverFeed()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}

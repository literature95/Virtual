import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/main.dart';
import 'package:virtual/providers/auth_provider.dart';
import 'package:virtual/providers/character_provider.dart';
import 'package:virtual/providers/chat_provider.dart';
import 'package:virtual/providers/endpoint_provider.dart';
import 'package:virtual/providers/metadata_provider.dart';
import 'package:virtual/providers/settings_provider.dart';
import 'package:virtual/views/character/character_edit_page.dart';

/// 应用级 Provider 注册的回归防线
///
/// **真实事故**：`AppDatabase` 在 `main()` 里被创建后，只作为构造参数传给了
/// Endpoint / Character / Chat 三个 Provider，**自身没有注册进 Provider 树**。
/// 而角色编辑、角色管理、Lorebook 增改查、预设、正则、备份共 9 个页面、
/// 21 处都写的是 `context.read<AppDatabase>()`。
///
/// 这个缺陷的迷惑性极强：
///  - 编译通过，`flutter analyze` 0 issue，没有任何 lint 或静态检查能发现；
///  - 只在运行期抛 `ProviderNotFoundException`；
///  - 角色编辑页又是在 `addPostFrameCallback` 里读的，异常发生在
///    `setState(_isLoading = false)` **之前** → 页面永久停在转圈上，
///    用户看到的就是「点创建角色没反应」。
///
/// 所以这里用两道防线把它钉死：
///  1. 逐类型断言 Provider 树里都取得到（防止再有人漏注册）；
///  2. 真正 pump 一次「新建角色」页，断言它渲染出表单而不是一直转圈。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(SharedPreferences, AppDatabase)> setup() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await AppDatabase.init();
    return (prefs, db);
  }

  testWidgets('Provider 树覆盖所有被 context.read<T>() 使用的类型', (tester) async {
    final (prefs, db) = await setup();

    late BuildContext ctx;
    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final missing = <String>[];
    void check<T>(String name) {
      try {
        Provider.of<T>(ctx, listen: false);
      } catch (_) {
        missing.add(name);
      }
    }

    check<AppDatabase>('AppDatabase');
    check<SettingsProvider>('SettingsProvider');
    check<AuthProvider>('AuthProvider');
    check<MetadataProvider>('MetadataProvider');
    check<EndpointProvider>('EndpointProvider');
    check<CharacterProvider>('CharacterProvider');
    check<ChatProvider>('ChatProvider');

    expect(
      missing,
      isEmpty,
      reason: '以下类型被 context.read<T>() 使用但未注册到 Provider 树：$missing',
    );

    // MetadataService 在 Provider 初始化时会发远程元数据请求并排下 Dio 超时
    // 定时器；不推进假时钟让它跑完，AutomatedTestWidgetsFlutterBinding 会以
    // `!timersPending` 断言失败，掩盖真正的用例结论。
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('「新建角色」页能正常加载，不会卡在转圈', (tester) async {
    final (prefs, db) = await setup();

    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: const MaterialApp(home: CharacterEditPage()),
      ),
    );

    // 刻意不用 pumpAndSettle：真的卡在转圈时 CircularProgressIndicator 是
    // 无限动画，pumpAndSettle 只会抛「timed out」，定位不到真正原因。
    await tester.pump(); // 触发 initState 里排的 postFrameCallback
    await tester.pump(const Duration(milliseconds: 16)); // 渲染 setState 后的结果

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: '页面停在转圈 = _loadData() 里 context.read<AppDatabase>() 抛了 '
          'ProviderNotFoundException，setState(_isLoading = false) 从未执行',
    );
    expect(find.text('新角色'), findsOneWidget, reason: 'AppBar 标题应为「新角色」');
    expect(find.text('保存'), findsOneWidget, reason: '编辑表单应已渲染');
  });
}

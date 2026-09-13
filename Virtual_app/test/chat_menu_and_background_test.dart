import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/main.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/models/chat_theme.dart';
import 'package:virtual/models/conversation.dart';
import 'package:virtual/providers/chat_provider.dart';
import 'package:virtual/views/chat/chat_background.dart';
import 'package:virtual/views/chat/chat_character_info_page.dart';
import 'package:virtual/views/chat/chat_page.dart';
import 'package:virtual/views/home/home_shell.dart';

/// 对话页右上角「更多」菜单 + 对话背景的回归防线
///
/// 覆盖两件容易被后续改动破坏的事：
///  1. 菜单必须是**从右侧下拉**的 `PopupMenuButton`（不是底部弹层），
///     且五个条目齐全 —— 用户明确要求过交互形态；
///  2. 对话背景的存取必须**按对话隔离**、**不污染全局生效主题**，
///     并且在删除对话时连带清理，不留孤儿条目。
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

  Future<void> seedConversation(AppDatabase db, {String convId = 'conv-1'}) async {
    final now = DateTime.now();
    await db.saveCharacter(Character(
      id: 'char-1',
      name: '希露妲',
      description: '测试用角色',
      firstMessage: '你好呀。',
      createdAt: now,
      updatedAt: now,
    ));
    await db.saveConversation(Conversation(
      id: convId,
      title: '测试对话',
      characterId: 'char-1',
      settings: ChatSettings(),
      createdAt: now,
      updatedAt: now,
    ));
  }

  // ── 1. 菜单形态与条目 ──────────────────────────────────────────────

  testWidgets('右上角三点：从右侧下拉弹出（不是底部弹层），五个条目齐全',
      (tester) async {
    final (prefs, db) = await setup();
    await seedConversation(db);

    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: const MaterialApp(home: ChatPage(conversationId: 'conv-1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 形态：下拉菜单，而非底部弹层
    expect(
      find.byWidgetPredicate((w) => w is PopupMenuItem),
      findsNWidgets(5),
      reason: '应当渲染 5 个 PopupMenuItem（下拉菜单）',
    );
    expect(
      find.byType(BottomSheet),
      findsNothing,
      reason: '不应再使用 showModalBottomSheet（用户要求不从下面出来）',
    );

    // 条目：顺序与文案
    for (final label in const [
      '角色信息',
      '对话背景',
      '导出为 Markdown',
      '模型信息',
      '清空消息',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '菜单应包含「$label」');
    }

    // 收起菜单，让挂起的定时器跑完，避免 !timersPending 断言掩盖结论
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(seconds: 30));
  });

  // ── 1b. 对话页左上角返回图标 ───────────────────────────────────────

  testWidgets('对话页 AppBar 左上角始终显示返回图标', (tester) async {
    final (prefs, db) = await setup();
    await seedConversation(db);

    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: const MaterialApp(home: ChatPage(conversationId: 'conv-1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // 用户报障：从角色库点卡片进对话，左上角没有返回键。
    // 根因：对话页经 ShellRoute 进入，home_shell 的 AppBar 对其隐藏，
    // 而对话页未显式设 leading，且入口用 go 重置了导航栈 → canPop()==false
    // → automaticallyImplyLeading 不画返回箭头。现改为显式 leading，必须始终存在。
    expect(find.byType(BackButton), findsOneWidget,
        reason: '对话页左上角必须有返回图标（无论 go 还是 push 进入）');

    await tester.pump(const Duration(seconds: 30));
  });

  // ── 2. 背景存取 ────────────────────────────────────────────────────

  group('对话背景存取', () {
    test('保存后能读回，id 由对话 id 派生', () async {
      final (_, db) = await setup();
      final chat = ChatProvider(db);
      const convId = 'conv-1';

      expect(chat.conversationBackground(convId), isNull, reason: '初始应无背景');

      await chat.saveConversationBackground(
        convId,
        ChatTheme(
          id: '',
          name: '',
          backgroundImage: 'preset:ocean',
          backgroundOpacity: 0.6,
          backgroundBlur: ChatBackgroundBlur.medium,
        ),
      );

      final bg = chat.conversationBackground(convId);
      expect(bg, isNotNull);
      expect(bg!.id, 'conv-bg-conv-1');
      expect(bg.backgroundImage, 'preset:ocean');
      expect(bg.backgroundOpacity, 0.6);
      expect(bg.backgroundBlur, ChatBackgroundBlur.medium);
    });

    test('不污染全局生效主题（isActive 恒为 false）', () async {
      final (_, db) = await setup();
      final chat = ChatProvider(db);

      await db.saveTheme(ChatTheme(id: 'global', name: '全局主题', isActive: true));
      await chat.saveConversationBackground(
        'conv-1',
        ChatTheme(id: '', name: '', backgroundImage: 'preset:amber_sun'),
      );

      expect(db.getActiveTheme()?.id, 'global',
          reason: '对话背景不能抢走全局生效主题的 isActive 标记');
      expect(chat.conversationBackground('conv-1')!.isActive, isFalse);
    });

    test('按对话隔离：A 的背景不会出现在 B 上', () async {
      final (_, db) = await setup();
      final chat = ChatProvider(db);

      await chat.saveConversationBackground(
        'conv-a',
        ChatTheme(id: '', name: '', backgroundImage: 'preset:forest'),
      );

      expect(chat.conversationBackground('conv-a'), isNotNull);
      expect(chat.conversationBackground('conv-b'), isNull);
    });

    test('清除背景后读回为 null', () async {
      final (_, db) = await setup();
      final chat = ChatProvider(db);

      await chat.saveConversationBackground(
        'conv-1',
        ChatTheme(id: '', name: '', backgroundImage: 'preset:paper'),
      );
      await chat.clearConversationBackground('conv-1');

      expect(chat.conversationBackground('conv-1'), isNull);
    });

    test('删除对话时连带清理背景，不留孤儿条目', () async {
      final (_, db) = await setup();
      await seedConversation(db);
      final chat = ChatProvider(db);

      await chat.saveConversationBackground(
        'conv-1',
        ChatTheme(id: '', name: '', backgroundImage: 'preset:ocean'),
      );
      expect(chat.conversationBackground('conv-1'), isNotNull);

      await chat.deleteConversation('conv-1');

      expect(chat.conversationBackground('conv-1'), isNull);
      expect(db.getConversations().any((c) => c.id == 'conv-1'), isFalse);
    });
  });

  // ── 2b. 接线验证：设置后聊天页真的会渲染背景层 ──────────────────────

  testWidgets('设过背景的对话，聊天页会渲染 ChatBackgroundLayer', (tester) async {
    final (prefs, db) = await setup();
    await seedConversation(db);
    await ChatProvider(db).saveConversationBackground(
      'conv-1',
      ChatTheme(
        id: '',
        name: '',
        backgroundImage: 'preset:ocean',
        backgroundOpacity: 0.8,
        backgroundBlur: ChatBackgroundBlur.light,
      ),
    );

    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: const MaterialApp(home: ChatPage(conversationId: 'conv-1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(ChatBackgroundLayer), findsOneWidget,
        reason: '设过背景的对话，聊天页必须渲染背景层');

    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('没设背景的对话，聊天页不套背景层（保持原样）', (tester) async {
    final (prefs, db) = await setup();
    // 用一条**独立**的对话 id：SharedPreferences 的实例缓存不会因为
    // setUp 里的 setMockInitialValues 而重新读盘，前一个用例写进去的
    // 背景主题会残留，拿 conv-1 断言「没有背景」会假红。
    await seedConversation(db, convId: 'conv-clean');

    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: const MaterialApp(home: ChatPage(conversationId: 'conv-clean')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(ChatBackgroundLayer), findsNothing);

    await tester.pump(const Duration(seconds: 30));
  });

  // ── 2. 对话窗口沉浸式：窄屏不显示底部导航栏 ───────────────────────

  GoRouter _chatShellRouter({required String initial}) => GoRouter(
        // 用 initialLocation 直接加载，避免路由切换过渡导致新旧页短暂共存
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeShell(child: SizedBox()),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) => HomeShell(
              child: ChatPage(conversationId: state.pathParameters['id']!),
            ),
          ),
        ],
      );

  testWidgets('对话窗口（窄屏）不显示底部导航栏，且有返回图标', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    final (prefs, db) = await setup();
    await seedConversation(db);

    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: MaterialApp.router(
          routerConfig: _chatShellRouter(initial: '/chat/conv-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 对话窗口：沉浸式全屏，不应有底部导航栏，但应有返回图标
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsWidgets);
  });

  testWidgets('非对话页（窄屏）仍显示底部导航栏（对照）', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    final (prefs, db) = await setup();
    await seedConversation(db);

    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: MaterialApp.router(
          routerConfig: _chatShellRouter(initial: '/'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  // ── 2c. 接线验证：角色信息页读的是本地卡 ───────────────────────────

  testWidgets('角色信息页展示本地角色档案，找不到时给出明确空态', (tester) async {
    final (prefs, db) = await setup();
    await seedConversation(db);

    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: const MaterialApp(
          home: ChatCharacterInfoPage(characterId: 'char-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('希露妲'), findsWidgets);
    expect(find.text('简介'), findsOneWidget);
    expect(find.text('测试用角色'), findsOneWidget);
    expect(find.text('开场白'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));

    // 找不到本地角色时不能白屏
    await tester.pumpWidget(
      buildAppProviders(
        prefs: prefs,
        database: db,
        child: const MaterialApp(
          home: ChatCharacterInfoPage(characterId: 'not-exist'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('本地库中找不到这个角色'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
  });

  // ── 3. 背景来源解析 ────────────────────────────────────────────────

  group('背景来源解析', () {
    test('预设前缀命中 / 未命中', () {
      expect(ChatBackgroundLayer.presetOf('preset:ocean')?.id, 'ocean');
      expect(ChatBackgroundLayer.presetOf('preset:not-exist'), isNull);
      expect(ChatBackgroundLayer.presetOf('https://a.com/b.jpg'), isNull);
      expect(ChatBackgroundLayer.presetOf(null), isNull);
    });

    test('来源中文名', () {
      expect(ChatBackgroundLayer.describeSource(null), '无背景');
      expect(ChatBackgroundLayer.describeSource(''), '无背景');
      expect(ChatBackgroundLayer.describeSource('preset:ocean'), '深海');
      expect(ChatBackgroundLayer.describeSource('https://a.com/b.jpg'), '网络图片');
      expect(ChatBackgroundLayer.describeSource(r'C:\pic\bg.png'), '本地图片');
    });

    test('模糊档位映射到 sigma', () {
      expect(ChatBackgroundLayer.blurSigma(ChatBackgroundBlur.none), 0);
      expect(ChatBackgroundLayer.blurSigma(ChatBackgroundBlur.light), 4);
      expect(ChatBackgroundLayer.blurSigma(ChatBackgroundBlur.medium), 10);
      expect(ChatBackgroundLayer.blurSigma(ChatBackgroundBlur.heavy), 20);
    });

    test('预设 id 唯一', () {
      final ids = kChatBackgroundPresets.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: '预设 id 不可重复');
      expect(ids, isNotEmpty);
    });
  });
}

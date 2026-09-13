import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_database.dart';
import 'providers/auth_provider.dart';
import 'providers/character_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/endpoint_provider.dart';
import 'providers/metadata_provider.dart';
import 'services/model_registry_service.dart';
import 'services/metadata_service.dart';
import 'services/wuk_trace.dart';
import 'route/app_router.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'views/onboarding/onboarding_page.dart';
import 'views/common/update_checker.dart';

Future<void> main() async {
  const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () async {
        WidgetsFlutterBinding.ensureInitialized();

        final prefs = await SharedPreferences.getInstance();
        final database = await AppDatabase.init();

        // 强制竖屏（移动端）
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);

        runApp(
          MyApp(
            prefs: prefs,
            database: database,
          ),
        );
      },
    );
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final database = await AppDatabase.init();

  // 强制竖屏（移动端）
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MyApp(
      prefs: prefs,
      database: database,
    ),
  );
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final AppDatabase database;

  const MyApp({
    super.key,
    required this.prefs,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    return buildAppProviders(
      prefs: prefs,
      database: database,
      child: AppGate(prefs: prefs),
    );
  }
}

/// 应用级 Provider 树（生产与测试共用同一份，避免测试树与真实树漂移）
///
/// 抽成函数是为了让测试能直接断言「每个被 `context.read<T>()` 用到的类型
/// 都确实注册了」——这类**漏注册**既不报编译错也不报 lint，
/// 只会在运行期某个页面里抛 `ProviderNotFoundException`。
///
/// 返回 `Widget` 而不是 `List<SingleChildWidget>`：后者由 provider 依赖的
/// nested 包定义，当前版本未从 `provider.dart` 导出，写成类型会编译失败。
Widget buildAppProviders({
  required SharedPreferences prefs,
  required AppDatabase database,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      // 🔴 AppDatabase 必须显式注入 Provider 树。
      // 角色编辑 / 角色管理 / Lorebook 增改查 / 预设 / 正则 / 备份 共 9 个页面、
      // 21 处都写的是 `context.read<AppDatabase>()`，而 database 此前只作为
      // 构造函数参数传给了 Endpoint/Character/Chat 三个 Provider，**自身没注册**。
      // 后果：这些页面在 initState 的 postFrameCallback 里抛
      // ProviderNotFoundException，而异常发生在 setState(_isLoading = false)
      // 之前 → 界面永久停在转圈，表现为「新建角色点了没反应」。
      // 注册顺序放在最前：其余 Provider 若将来需要读它也能取到。
      // 用 ChangeNotifierProvider.value 而不是 Provider.value —— AppDatabase
      // 本身 extends ChangeNotifier，普通 Provider 会触发 provider 的
      // debugCheckInvalidValueType 断言（运行期直接抛错）。
      // `.value` 语义是「外部已持有实例，容器不负责 dispose」，正合此处：
      // 实例在 main() 里创建并贯穿整个应用生命周期。
      ChangeNotifierProvider<AppDatabase>.value(value: database),
      ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
      ChangeNotifierProvider(create: (_) => AuthProvider(prefs)),
      ChangeNotifierProvider(
        create: (_) => MetadataProvider(MetadataService(prefs: prefs))..load(),
      ),
      ChangeNotifierProvider(
        create: (_) => EndpointProvider(
          database,
          modelRegistry: ModelRegistryService(),
        ),
      ),
      ChangeNotifierProvider(create: (_) => CharacterProvider(database)),
      // AuthProvider 也喂给 ChatProvider：账号昵称是 {{user}} 宏的兜底值
      //（角色卡里的 {{user}} = 当前用户昵称，见 ChatProvider._resolvePersona）
      ChangeNotifierProxyProvider4<AuthProvider, SettingsProvider,
          CharacterProvider, EndpointProvider, ChatProvider>(
        create: (_) => ChatProvider(database),
        update: (_, auth, settings, character, endpoint, chat) {
          chat?.updateDependencies(
            settings,
            character,
            endpoint,
            auth.user?.nickname,
          );
          return chat!;
        },
      ),
    ],
    child: child,
  );
}

/// 应用入口门控：未引导则显示 Onboarding，否则进入主应用
class AppGate extends StatelessWidget {
  final SharedPreferences prefs;

  const AppGate({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        if (!settings.onboardingCompleted) {
          return MaterialApp(
            title: 'Virtual',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(settings),
            darkTheme: AppTheme.dark(settings),
            themeMode: settings.themeMode,
            locale: settings.locale,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: AppConstants.supportedLocales,
            home: OnboardingPage(
              onFinished: () => settings.setOnboardingCompleted(true),
            ),
          );
        }

        return MaterialApp.router(
          title: 'Virtual',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(settings),
          darkTheme: AppTheme.dark(settings),
          themeMode: settings.themeMode,
          routerConfig: AppRouter.router,
          locale: settings.locale,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppConstants.supportedLocales,
          builder: (context, child) {
            return UpdateChecker(
              child: Consumer<MetadataProvider>(
                builder: (context, meta, _) {
                  if (meta.loaded && meta.metadata != null) {
                    WukTrace.instance.init(
                      prefs: prefs,
                      apiSecret: meta.metadata!.apiSecret,
                    );
                  }
                  return child ?? const SizedBox.shrink();
                },
              ),
            );
          },
        );
      },
    );
  }
}

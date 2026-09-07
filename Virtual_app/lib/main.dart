import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_database.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
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
        ChangeNotifierProxyProvider3<SettingsProvider, CharacterProvider,
            EndpointProvider, ChatProvider>(
          create: (_) => ChatProvider(database),
          update: (_, settings, character, endpoint, chat) {
            chat?.updateDependencies(settings, character, endpoint);
            return chat!;
          },
        ),
      ],
      child: AppGate(prefs: prefs),
    );
  }
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

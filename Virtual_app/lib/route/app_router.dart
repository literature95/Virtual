import 'package:go_router/go_router.dart';

import '../views/chat/chat_list_page.dart';
import '../views/chat/chat_page.dart';
import '../views/character/character_list_page.dart';
import '../views/character/character_edit_page.dart';
import '../views/discover/discover_page.dart';
import '../views/home/home_page.dart';
import '../views/lorebook/lorebook_list_page.dart';
import '../views/lorebook/lorebook_edit_page.dart';
import '../views/profile/profile_page.dart';
import '../views/settings/settings_page.dart';
import '../views/settings/backup_page.dart';
import '../views/settings/tts_settings_page.dart';
import '../views/settings/asr_settings_page.dart';
import '../views/settings/web_search_settings_page.dart';
import '../views/settings/image_gen_settings_page.dart';
import '../views/theme/theme_list_page.dart';
import '../views/endpoint/endpoint_list_page.dart';
import '../views/endpoint/endpoint_edit_page.dart';
import '../views/regex/regex_list_page.dart';
import '../views/regex/regex_edit_page.dart';
import '../views/preset/preset_list_page.dart';
import '../views/preset/preset_edit_page.dart';
import '../views/home/home_shell.dart';
import '../views/more/more_page.dart';
import '../views/plugin/plugin_list_page.dart';
import '../views/debug/debug_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatListPage(),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ChatPage(conversationId: id);
            },
          ),
          GoRoute(
            path: '/characters',
            builder: (context, state) => const CharacterListPage(),
          ),
          GoRoute(
            path: '/character/new',
            builder: (context, state) => const CharacterEditPage(),
          ),
          GoRoute(
            path: '/character/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CharacterEditPage(characterId: id);
            },
          ),
          GoRoute(
            path: '/endpoints',
            builder: (context, state) => const EndpointListPage(),
          ),
          GoRoute(
            path: '/endpoint/new',
            builder: (context, state) => const EndpointEditPage(),
          ),
          GoRoute(
            path: '/endpoint/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return EndpointEditPage(endpointId: id);
            },
          ),
          GoRoute(
            path: '/lorebooks',
            builder: (context, state) => const LorebookListPage(),
          ),
          GoRoute(
            path: '/lorebook/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return LorebookEditPage(lorebookId: id);
            },
          ),
          GoRoute(
            path: '/regex',
            builder: (context, state) => const RegexListPage(),
          ),
          GoRoute(
            path: '/regex/new',
            builder: (context, state) => const RegexEditPage(),
          ),
          GoRoute(
            path: '/regex/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return RegexEditPage(regexId: id);
            },
          ),
          GoRoute(
            path: '/presets',
            builder: (context, state) => const PresetListPage(),
          ),
          GoRoute(
            path: '/preset/new',
            builder: (context, state) => const PresetEditPage(presetId: ''),
          ),
          GoRoute(
            path: '/preset/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return PresetEditPage(presetId: id);
            },
          ),
          GoRoute(
            path: '/theme',
            builder: (context, state) => const ThemeListPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/settings/backup',
            builder: (context, state) => const BackupPage(),
          ),
          GoRoute(
            path: '/settings/tts',
            builder: (context, state) => const TtsSettingsPage(),
          ),
          GoRoute(
            path: '/settings/asr',
            builder: (context, state) => const AsrSettingsPage(),
          ),
          GoRoute(
            path: '/settings/web-search',
            builder: (context, state) => const WebSearchSettingsPage(),
          ),
          GoRoute(
            path: '/settings/image-gen',
            builder: (context, state) => const ImageGenSettingsPage(),
          ),
          GoRoute(
            path: '/plugins',
            builder: (context, state) => const PluginListPage(),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const MorePage(),
          ),
          GoRoute(
            path: '/debug',
            builder: (context, state) => const DebugPage(),
          ),
        ],
      ),
    ],
  );
}

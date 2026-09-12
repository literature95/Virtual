import 'package:go_router/go_router.dart';

import '../views/chat/chat_list_page.dart';
import '../views/chat/chat_page.dart';
import '../views/character/character_list_page.dart';
import '../views/character/character_edit_page.dart';
import '../views/character/character_tab_page.dart';
import '../views/discover/discover_page.dart';
import '../views/discover/user_profile_page.dart';
import '../views/discover/post_detail_page.dart';
import '../views/home/category_characters_page.dart';
import '../views/home/character_detail_page.dart';
import '../views/home/home_page.dart';
import '../views/lorebook/lorebook_list_page.dart';
import '../views/lorebook/lorebook_edit_page.dart';
import '../views/profile/profile_page.dart';
import '../views/profile/profile_edit_page.dart';
import '../views/profile/change_password_page.dart';
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
import '../views/auth/login_page.dart';
import '../views/auth/register_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      // 登录/注册：独立全屏页面，不受 home_shell 包裹
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      // 用户主页（点击头像进入，独立全屏页面）
      GoRoute(
        path: '/user/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return UserProfilePage(userId: id);
        },
      ),
      // 动态详情（点击帖子 / 评论进入，独立全屏页面）
      GoRoute(
        path: '/post/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PostDetailPage(postId: id);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          // 角色卡详情页：放在 ShellRoute 内 → 保留底部导航（用户要求详情页有底部菜单栏）
          GoRoute(
            path: '/home/character/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CharacterDetailPage(characterId: id);
            },
          ),
          GoRoute(
            path: '/home/category/:name',
            builder: (context, state) {
              final raw = state.pathParameters['name'] ?? '';
              // 安全解码：路径参数可能包含非法百分号编码
              String name;
              try {
                name = Uri.decodeComponent(raw);
              } catch (_) {
                name = raw;
              }
              return CategoryCharactersPage(category: name);
            },
          ),
          // 搜索筛选页（无预选分类，从首页搜索按钮进入）
          GoRoute(
            path: '/home/search',
            builder: (context, state) => const CategoryCharactersPage(),
          ),
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          // 个人信息编辑（点击「我的」页头像 / 昵称进入）
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) => const ProfileEditPage(),
          ),
          GoRoute(
            path: '/profile/password',
            builder: (context, state) => const ChangePasswordPage(),
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
            builder: (context, state) => const CharacterTabPage(),
          ),
          // 角色卡管理列表（书架之外的「全部角色」管理入口，由角色 Tab 内入口跳入）
          GoRoute(
            path: '/character/manage',
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

import 'package:go_router/go_router.dart';

import '../views/chat/chat_background_page.dart';
import '../views/chat/chat_character_info_page.dart';
import '../views/chat/chat_list_page.dart';
import '../views/chat/chat_page.dart';
import '../views/character/character_list_page.dart';
import '../views/character/character_edit_page.dart';
import '../views/character/character_tab_page.dart';
import '../views/discover/discover_page.dart';
import '../views/discover/compose_post_page.dart';
import '../views/discover/user_profile_page.dart';
import '../views/discover/post_detail_page.dart';
import '../views/home/category_characters_page.dart';
import '../views/home/character_detail_page.dart';
import '../views/home/home_page.dart';
import '../views/home/tag_filter_page.dart';
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

/// 应用路由表。
///
/// 布局约定（2026-11-04）：
/// - **一级 Tab**（`/home`、`/discover`、`/characters`、`/profile`）与少数
///   需要保留底部导航的页面（角色卡详情 `_home/character/:id`、分类/搜索页、
///   对话列表/对话页）放在 [ShellRoute] 内；
/// - **二级页面**（设置、插件、世界书、正则、预设、端点、主题、角色编辑、
///   账号相关、对话背景/角色信息等）一律注册为**根 Navigator 的独立路由**。
///   进入后不再显示底部导航栏；返回键由 `SecondaryAppBar` 的 leading 与
///   系统返回键共同保证「回到上一级」，只有根页面才允许退出 App。
///   注意：二级页面入口统一使用 `context.push`（而非 `go`），否则会丢失
///   返回栈，系统返回键会直接退出应用。
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
      // 发布动态：全页编辑器（底栏「+」/ 发现页入口），独立于 Shell
      GoRoute(
        path: '/compose',
        builder: (context, state) => const ComposePostPage(),
      ),

      // ─────────────────────────────────────────────────────────────
      // 二级页面：根 Navigator 独立路由（无底部导航栏）
      // ─────────────────────────────────────────────────────────────

      // 账号相关
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditPage(),
      ),
      GoRoute(
        path: '/profile/password',
        builder: (context, state) => const ChangePasswordPage(),
      ),

      // 端点（API 接入）
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

      // 世界书
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

      // 正则
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

      // 预设
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

      // 主题
      GoRoute(
        path: '/theme',
        builder: (context, state) => const ThemeListPage(),
      ),

      // 设置及其子页
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

      // 插件 / 更多 / 调试
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

      // 角色卡管理 / 编辑（角色 Tab 进入的二级页面）
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

      // 对话相关二级页（角色信息 / 对话背景）
      GoRoute(
        path: '/chat/info/:characterId',
        builder: (context, state) {
          final raw = state.pathParameters['characterId'] ?? '';
          // 角色 id 可能含中文（slugify 有意保留 CJK），需安全解码
          String id;
          try {
            id = Uri.decodeComponent(raw);
          } catch (_) {
            id = raw;
          }
          return ChatCharacterInfoPage(characterId: id);
        },
      ),
      GoRoute(
        path: '/chat/background/:conversationId',
        builder: (context, state) {
          final id = state.pathParameters['conversationId']!;
          return ChatBackgroundPage(conversationId: id);
        },
      ),

      // ─────────────────────────────────────────────────────────────
      // 一级 Tab 与需要保留底部导航栏的页面
      // ─────────────────────────────────────────────────────────────
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
          // 标签筛选页（首页顶栏「分类」按钮 push 进入；ShellRoute 内保留底栏，
          // 页面自带返回箭头，系统返回回到首页而不是退出 App）
          GoRoute(
            path: '/home/tags',
            builder: (context, state) => const TagFilterPage(),
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
            builder: (context, state) => const CharacterTabPage(),
          ),
        ],
      ),
    ],
  );
}

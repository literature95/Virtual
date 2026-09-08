import 'dart:convert';

import 'package:virtual_background/database/db.dart';

/// 种子数据（应用启动时写入 DB；DB 不可用时返回内存数据）
class SeedData {
  SeedData._();
  static final SeedData instance = SeedData._();

  /// 用量追踪密钥，通过编译期环境变量注入：
  ///   dart_frog dev --port 8080 --dart-define=API_SECRET_KEY=xxx --dart-define=API_SECRET_IV=yyy
  /// 未提供时不下发 api-secret 条目，App 侧自动禁用追踪（WukTrace 门控逻辑）。
  static const String _apiSecretKey = String.fromEnvironment('API_SECRET_KEY');
  static const String _apiSecretIv = String.fromEnvironment('API_SECRET_IV');

  // ---------- 元数据（顶级数组，每项 {desc, id, name, obj, tag}） ----------
  static final List<Map<String, dynamic>> metadata = [
    {
      'desc': '客服邮箱、官网等',
      'id': 'uris',
      'name': '网络资源',
      'obj': {
        'customer_service_email': 'virtual_service@outlook.com',
        'discord': 'https://discord.gg/virtual-ai',
        'help': 'https://docs.virtual.dev/',
        'homepage': 'https://virtual.dev',
        'privacy_policy': 'https://virtual.dev/privacy',
        'terms_of_service': 'https://virtual.dev/terms'
      },
      'tag': null
    },
    if (_apiSecretKey.isNotEmpty && _apiSecretIv.isNotEmpty)
      {
        'desc': 'api secret',
        'id': 'api-secret',
        'name': 'api_secret',
        'obj': {'iv': _apiSecretIv, 'key': _apiSecretKey},
        'tag': null
      },
    {
      'desc': '快速开始一键配置开关',
      'id': 'quick-setup',
      'name': 'quick setup',
      'obj': true,
      'tag': null
    },
    {
      'desc': '插件市场',
      'id': 'plugin-market',
      'name': '插件市场',
      'obj': {
        'banner': {
          'zh_CN': [
            {
              'action': 'virtual://page/plugin.market',
              'url': 'https://virtual.dev/assets/plugin_banner_zh.png'
            }
          ],
          'en_US': [
            {
              'action': 'virtual://page/plugin.market',
              'url': 'https://virtual.dev/assets/plugin_banner_en.png'
            }
          ]
        }
      },
      'tag': ''
    }
  ];

  // ---------- 角色卡 ----------
  static final List<Map<String, dynamic>> characters = [
    {
      'id': 'char-001',
      'name': '晓夜',
      'description': '深夜便利店的神秘店员，温柔体贴。',
      'avatar_url': '/avatars/char-001.jpg',
      'tags': ['治愈', '日常', '温柔'],
      'greeting': '欢迎光临~ 这么晚了还没休息吗？',
      'first_message': '叮铃—— 便利店的门帘被掀起，暖黄色的灯光洒在湿漉漉的地板上。\n\n「欢迎光临~ 这么晚了还没休息吗？」',
      'persona': '晓夜，24岁，便利店夜班店员，性格温柔体贴。'
    },
    {
      'id': 'char-002',
      'name': '星尘',
      'description': '来自遥远星系的探索者，对人类充满好奇。',
      'avatar_url': '/avatars/char-002.jpg',
      'tags': ['科幻', '探索', '博学'],
      'greeting': '你好，碳基生命！地球的大气层真是迷人的蓝色。',
      'first_message': '一个柔和的光球缓缓降落凝聚成人类形态：「你好，我是星尘，来自天琴座方向的第三颗行星。」',
      'persona': '星尘，星际探索者，求知欲旺盛。'
    },
    {
      'id': 'char-003',
      'name': '墨书',
      'description': '古籍中走出来的书生，博古通今。',
      'avatar_url': '/avatars/char-003.jpg',
      'tags': ['古风', '文人', '儒雅'],
      'greeting': '兄台有礼，在下墨书。',
      'first_message': '案头古籍自行翻页，墨香四溢。「兄台有礼，在下墨书。不知可有兴致品茗论道？」',
      'persona': '墨书，古代书生，温文尔雅，善于诗书画。'
    },
    {
      'id': 'char-004',
      'name': '未来 AI',
      'description': '来自 2150 年的超级人工智能。',
      'avatar_url': '/avatars/char-004.jpg',
      'tags': ['科幻', 'AI', '理性'],
      'greeting': '连接建立。有什么我可以帮你的？',
      'first_message': '设备跳出蓝色全息界面：「我是 Aurora，来自 2150 年。我要协助你们度过下个世纪。」',
      'persona': 'Aurora，超级 AI，理性、知识渊博。'
    },
    {
      'id': 'char-005',
      'name': '喵子',
      'description': '猫娘咖啡馆老板，活泼可爱。',
      'avatar_url': '/avatars/char-005.jpg',
      'tags': ['治愈', '萌系', '日常'],
      'greeting': '喵~ 欢迎光临喵咖啡馆！',
      'first_message': '推开绘着猫爪印的木门，猫耳少女摇着尾巴迎上来。「喵~ 欢迎光临！」',
      'persona': '喵子，猫娘咖啡馆老板，喜欢甜食和小鱼干。'
    }
  ];

  // ---------- App 信息 ----------
  static final Map<String, dynamic> appInfo = {
    'id': 'app-001',
    'name': 'Virtual',
    'version': '1.0.0',
    'description': 'Virtual 是一个支持本地优先、角色扮演、跨模型接入的 AI 角色聊天客户端。',
    'features': [
      {'title': '多模型接入', 'desc': '支持 OpenAI / Anthropic / Gemini / DeepSeek 等'},
      {'title': '角色卡系统', 'desc': '导入、创建、分享你的专属 AI 角色'},
      {'title': '本地优先', 'desc': '数据保存在本地，隐私可控，离线可用'},
      {'title': '流式对话', 'desc': '打字机效果实时输出，更自然的聊天体验'}
    ],
    'download_url': 'https://virtual.dev/download/virtual-latest.apk'
  };

  /// 写入 DB（启动时调用）
  Future<void> writeToDb() async {
    final db = AppDatabase.instance;
    if (!db.isAvailable) {
      await db.init();
      if (!db.isAvailable) return;
    }
    final conn = await db.connection;
    if (conn == null) return;

    try {
      for (final entry in metadata) {
        await conn.execute(
          'INSERT INTO metadata (id, payload) VALUES (@id, @payload) ON CONFLICT (id) DO UPDATE SET payload = @payload, updated_at = NOW()',
          parameters: {'id': entry['id'], 'payload': jsonEncode(entry)},
        );
      }
      for (final c in characters) {
        await conn.execute(
          '''
INSERT INTO characters (id, name, description, avatar_url, tags, greeting, first_message, persona)
              VALUES (@id, @name, @description, @avatar_url, @tags::jsonb, @greeting, @first_message, @persona)
              ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name, description = EXCLUDED.description,
                avatar_url = EXCLUDED.avatar_url, tags = EXCLUDED.tags,
                greeting = EXCLUDED.greeting, first_message = EXCLUDED.first_message,
                persona = EXCLUDED.persona, updated_at = NOW()''',
          parameters: {
            'id': c['id'],
            'name': c['name'],
            'description': c['description'],
            'avatar_url': c['avatar_url'],
            'tags': jsonEncode(c['tags']),
            'greeting': c['greeting'],
            'first_message': c['first_message'],
            'persona': c['persona'],
          },
        );
      }
      await conn.execute(
        '''
INSERT INTO app_info (id, name, version, description, features, download_url)
            VALUES (@id, @name, @version, @description, @features::jsonb, @download_url)
            ON CONFLICT (id) DO UPDATE SET
              name = EXCLUDED.name, version = EXCLUDED.version,
              description = EXCLUDED.description, features = EXCLUDED.features,
              download_url = EXCLUDED.download_url, updated_at = NOW()''',
        parameters: {
          'id': appInfo['id'],
          'name': appInfo['name'],
          'version': appInfo['version'],
          'description': appInfo['description'],
          'features': jsonEncode(appInfo['features']),
          'download_url': appInfo['download_url'],
        },
      );
      // ignore: avoid_print
      print('[Virtual_background] Seed data written to PostgreSQL');
    } catch (e) {
      // ignore: avoid_print
      print('[Virtual_background] Seed write skipped (no DB): $e');
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/models/persona.dart';
import 'package:virtual/providers/chat_provider.dart';
import 'package:virtual/services/prompt_service.dart';

/// `{{user}}` 宏 = 「当前用户是谁」的回归防线
///
/// 用户反馈：角色卡里的 `{{user}}` 在对话时应该替换成**用户自己的昵称**，
/// 而不是硬编码的 'User'。解析优先级（`ChatProvider.resolvePersona`）：
///
///   会话/角色显式绑定的人设卡 > 全局激活的人设卡 > 账号昵称兜底 > 'User'
///
/// 账号昵称兜底是本次修复的核心：没有人设卡的多数用户，卡片里的
/// {{user}} 此前会被替换成字面量 'User'，模型叫不出用户的名字。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ChatProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await AppDatabase.init();
    // AppDatabase 是单例且持有首次 init 的 prefs 实例，必须显式清理，
    // 否则用例之间互相污染（见 home_import_dedup_test 的注释）。
    for (final p in db.getPersonas()) {
      await db.deletePersona(p.id);
    }
    provider = ChatProvider(db);
  });

  Persona persona(String id, String name, {bool active = false}) => Persona(
        id: id,
        name: name,
        isActive: active,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  group('resolvePersona 优先级', () {
    test('无人设卡但有账号昵称 → 用昵称兜底', () {
      provider.updateDependenciesForTest(userNickname: '阿澈');
      expect(provider.resolvePersona(null).name, '阿澈');
    });

    test('全局激活的人设卡优先于账号昵称（用户显式选择的人设不被覆盖）', () async {
      await db.savePersona(persona('p1', '旅行者', active: true));
      provider.updateDependenciesForTest(userNickname: '阿澈');
      expect(provider.resolvePersona(null).name, '旅行者');
    });

    test('显式绑定的人设卡优先于激活卡与昵称', () async {
      await db.savePersona(persona('p1', '旅行者', active: true));
      await db.savePersona(persona('p2', '调查员'));
      provider.updateDependenciesForTest(userNickname: '阿澈');
      expect(provider.resolvePersona('p2').name, '调查员');
    });

    test('绑定的 id 已被删除 → 回退激活卡 → 再回退昵称', () async {
      await db.savePersona(persona('p1', '旅行者', active: true));
      provider.updateDependenciesForTest(userNickname: '阿澈');
      expect(provider.resolvePersona('ghost-id').name, '旅行者');

      await db.deletePersona('p1');
      expect(provider.resolvePersona('ghost-id').name, '阿澈');
    });

    test('什么都没有 → 维持既有的 \'User\' 行为', () {
      expect(provider.resolvePersona(null).name, 'User');
    });
  });

  group('端到端：卡片字段里的 {{user}} 被替换为昵称', () {
    test('description / firstMes / 用户消息中的 {{user}} 全部生效', () {
      provider.updateDependenciesForTest(userNickname: '阿澈');
      final character = Character(
        id: 'char-x',
        name: '希露妲',
        description: '{{user}} 是采购科新来的科员。',
        firstMessage: '你就是 {{user}} 吧？',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final messages = PromptService.buildMessages(
        character: character,
        history: const [],
        userMessage: '{{user}} 向你问好',
        persona: provider.resolvePersona(null),
      );

      final system = messages.first['content'] as String;
      expect(system.contains('阿澈 是采购科新来的科员'), isTrue);
      expect(system.contains('{{user}}'), isFalse);

      final last = messages.last['content'] as String;
      expect(last, '阿澈 向你问好');
    });
  });
}

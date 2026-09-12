import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/providers/character_provider.dart';
import 'package:virtual/services/online_character_service.dart';

/// 「加入角色库」= 把后端角色卡**完整下载到本地库**的契约
///
/// 两个容易退化的前提：
///  1. `GET /api/characters`（列表）只回 9 个精简字段（id/name/description/
///     avatarUrl/tags/greeting/persona/creator/characterVersion），**没有**
///     personality / scenario / exampleMessages —— 少了这些，模型必 OOC。
///     真正完整的数据在 `GET /api/characters/:id`。因此入库前必须判断
///     `isFullCard`，精简条目要再拉一次详情。
///  2. 落库必须是**全字段往返**（toJson → fromJson 语义全等），
///     否则「下载到本地」只是下载了个壳。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await AppDatabase.init();
    for (final c in db.getCharacters()) {
      await db.deleteCharacter(c.id);
    }
    await db.clearCharacterShelf();
  });

  /// 列表接口的真实形态（9 字段，无 personality/scenario/examples）
  Map<String, dynamic> listEntryJson() => {
        'id': 'char-001',
        'name': '晓夜',
        'description': '姓名：晓夜\n年龄：24',
        'avatarUrl': 'http://localhost:8080/api/avatars/char-001.jpg',
        'tags': ['治愈', '日常'],
        'greeting': '叮铃——自动门的提示音响起来。',
        'persona': 'None',
        'creator': 'Virtual',
        'characterVersion': '1.0',
      };

  /// 详情接口的真实形态（完整卡）
  Map<String, dynamic> detailJson() => {
        'id': 'char-001',
        'name': '晓夜',
        'description': '姓名：晓夜\n年龄：24',
        'avatarUrl': 'http://localhost:8080/api/avatars/char-001.jpg',
        'tags': ['治愈', '日常'],
        'greeting': '叮铃——自动门的提示音响起来。',
        'firstMessage': '叮铃——自动门的提示音响起来。',
        'nickname': '小夜',
        'personality': '温柔、克制、细心到有点过度。',
        'scenario': '深夜的城市边缘，「夜灯」便利店亮着刺眼的白光。',
        'creatorNotes': '作者的话（不进 prompt）',
        'creator': 'Virtual',
        'characterVersion': '1.0',
        'source': 'Virtual backend',
        'alternateGreetings': ['备选开场白 A'],
        'groupOnlyGreetings': [],
        'exampleMessages': [
          {'userMessage': '还不下班？', 'assistantMessage': '「还有半小时——」'},
          {'userMessage': '便当多少钱', 'assistantMessage': '「老样子，算你半价。」'},
        ],
        'extensions': {'depth': 40},
        'creatorNotesMultilingual': {'zh': '作者的话'},
      };

  group('isFullCard：区分列表精简条目与完整卡', () {
    test('列表条目（无 personality/scenario/examples）判定为非完整卡', () {
      final c = OnlineCharacter.fromJson(listEntryJson());
      expect(c.isFullCard, isFalse,
          reason: '精简条目若被当成完整卡，就会把没有人设的壳存进本地库');
    });

    test('详情条目（有人设）判定为完整卡', () {
      final c = OnlineCharacter.fromJson(detailJson());
      expect(c.isFullCard, isTrue);
    });

    test('只有 exampleMessages 也算完整卡（examples 是语气核心资产）', () {
      final json = detailJson()
        ..remove('personality')
        ..remove('scenario');
      expect(OnlineCharacter.fromJson(json).isFullCard, isTrue);
    });
  });

  group('完整下载：关键人设字段必须落进本地库', () {
    test('导入完整卡后，本地库里 personality/scenario/examples 一个都不少', () async {
      final db = await AppDatabase.init();
      final chars = CharacterProvider(db);
      await chars.loadCharacters();

      final online = OnlineCharacter.fromJson(detailJson());
      final created = await chars.createCharacter(
        name: online.name,
        description: online.description,
        personality: online.personality,
        scenario: online.scenario,
        firstMessage: online.firstMessage,
        avatarPath: online.avatarUrl,
        exampleMessages: online.exampleMessages,
        alternateGreetings: online.alternateGreetings,
        tags: online.tags,
        extensions: online.importExtensions,
      );

      // 重新从库里读一份（不是复用内存对象），确认真的写盘了
      final reloaded = chars.getCharacter(created.id)!;
      expect(reloaded.personality, contains('温柔、克制'));
      expect(reloaded.scenario, contains('夜灯'));
      expect(reloaded.exampleMessages.length, 2);
      expect(reloaded.exampleMessages.first.userMessage, '还不下班？');
      expect(reloaded.exampleMessages.first.assistantMessage, contains('还有半小时'));
      expect(reloaded.tags, ['治愈', '日常']);
      expect(reloaded.nickname, isNull); // 未传就不该凭空出现
    });

    test('跨 provider 重开后字段仍在（真持久化，不是内存假象）', () async {
      final db = await AppDatabase.init();
      final chars = CharacterProvider(db);
      await chars.loadCharacters();
      final online = OnlineCharacter.fromJson(detailJson());
      final created = await chars.createCharacter(
        name: online.name,
        personality: online.personality,
        scenario: online.scenario,
        exampleMessages: online.exampleMessages,
      );

      // 新 provider 模拟 App 重启
      final reopened = CharacterProvider(db);
      await reopened.loadCharacters();
      final c = reopened.getCharacter(created.id)!;
      expect(c.personality, contains('温柔、克制'));
      expect(c.scenario, contains('夜灯'));
      expect(c.exampleMessages.length, 2);
    });

    test('sourceId 留存，重开后可再次查重（不会重复下载同一张卡）', () async {
      final db = await AppDatabase.init();
      final chars = CharacterProvider(db);
      await chars.loadCharacters();

      final online = OnlineCharacter.fromJson(detailJson());
      await chars.createCharacter(
        name: online.name,
        extensions: online.importExtensions,
      );

      final reopened = CharacterProvider(db);
      await reopened.loadCharacters();
      expect(reopened.findBySourceId('char-001'), isNotNull);
      expect(reopened.characters.length, 1);
    });
  });

  group('往返全等：toJson → fromJson 不丢字段', () {
    test('完整卡序列化再反序列化，关键字段语义全等', () {
      final original = OnlineCharacter.fromJson(detailJson()).toCharacter();
      final roundTripped = Character.fromJson(original.toJson());

      expect(roundTripped.name, original.name);
      expect(roundTripped.nickname, original.nickname);
      expect(roundTripped.description, original.description);
      expect(roundTripped.personality, original.personality);
      expect(roundTripped.scenario, original.scenario);
      expect(roundTripped.firstMessage, original.firstMessage);
      expect(roundTripped.avatarPath, original.avatarPath);
      expect(roundTripped.creatorNotes, original.creatorNotes);
      expect(roundTripped.tags, original.tags);
      expect(roundTripped.alternateGreetings, original.alternateGreetings);
      expect(roundTripped.extensions, original.extensions);
      expect(roundTripped.exampleMessages.length,
          original.exampleMessages.length);
      expect(roundTripped.exampleMessages.first.userMessage,
          original.exampleMessages.first.userMessage);
      expect(roundTripped.exampleMessages.first.assistantMessage,
          original.exampleMessages.first.assistantMessage);
    });

    test('importExtensions 注入 sourceId 且保留卡片自带扩展', () {
      final online = OnlineCharacter.fromJson(detailJson());
      final ext = online.importExtensions;
      expect(ext['sourceId'], 'char-001');
      expect(ext['depth'], 40);
    });
  });
}

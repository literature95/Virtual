import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/providers/character_provider.dart';
import 'package:virtual/providers/chat_provider.dart';
import 'package:virtual/services/online_character_service.dart';

/// 首页一键导入的「去重 + 续聊」契约
///
/// 这两个约定一旦被改坏，症状是**静默的**：用户看不出自己攒了一堆同名
/// 角色和空对话，只会觉得「越用越卡、列表越来越乱」。所以必须钉死。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    // AppDatabase 是单例且持有**首次** init 时的 prefs 实例，
    // 后续 setMockInitialValues 换掉的是 SharedPreferences 的静态缓存，
    // db 里那份数据并不会消失 —— 必须显式清空，否则用例之间互相污染
    //（表现为 `characters.length` 莫名比预期多）。
    final db = await AppDatabase.init();
    for (final c in db.getCharacters()) {
      await db.deleteCharacter(c.id);
    }
    for (final c in db.getConversations()) {
      await db.deleteConversation(c.id);
    }
  });

  Future<CharacterProvider> seedProvider() async {
    final db = await AppDatabase.init();
    final provider = CharacterProvider(db);
    // 构造函数里的 loadCharacters() 是异步触发的，等它落地再断言
    await provider.loadCharacters();
    return provider;
  }

  OnlineCharacter sampleCharacter() => const OnlineCharacter(
        id: 'char-001',
        name: 'Cricket',
        description: 'Triple A 商社的柜台小姐',
        extensions: {'depth': 40, 'sourceUrl': 'https://chub.ai/x'},
      );

  group('sourceId 留存', () {
    test('importExtensions 注入后端 ID，且不覆盖卡片自带扩展', () {
      final c = sampleCharacter();

      final ext = c.importExtensions;
      expect(ext['sourceId'], 'char-001');
      // 卡片原有扩展必须原样保留
      expect(ext['depth'], 40);
      expect(ext['sourceUrl'], 'https://chub.ai/x');
    });

    test('空 ID 不写入 sourceId（避免空串被误判为已导入）', () {
      const c = OnlineCharacter(id: '', name: 'X', description: '');
      expect(c.importExtensions.containsKey('sourceId'), isFalse);
    });

    test('Character.sourceId 从 extensions 读出；未导入过则为 null', () {
      final imported = Character(
        id: 'local-uuid',
        name: 'Cricket',
        extensions: const {'sourceId': 'char-001'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(imported.sourceId, 'char-001');

      final manual = imported.copyWith(extensions: {});
      expect(manual.sourceId, isNull);
    });
  });

  group('一键导入查重', () {
    test('本地 id 是重新分配的 uuid，因此只能靠 sourceId 查重', () async {
      final characters = await seedProvider();
      final online = sampleCharacter();

      final created = await characters.createCharacter(
        name: online.name,
        description: online.description,
        extensions: online.importExtensions,
      );

      // 这条断言是去重的**前提**：如果本地 id 就是后端 id，
      // findById 就够了，也就不会有当初那个重复导入的 bug。
      expect(created.id, isNot(online.id));
      expect(characters.findById(online.id), isNull);
      expect(characters.findBySourceId(online.id)?.id, created.id);
    });

    test('重复点击同一张卡不会堆出副本', () async {
      final characters = await seedProvider();
      final online = sampleCharacter();

      // 第 1 次点击：拉取详情 → 建卡
      await characters.createCharacter(
        name: online.name,
        description: online.description,
        extensions: online.importExtensions,
      );

      // 第 2、3 次点击：走查重分支，直接复用
      final reused = characters.findBySourceId(online.id);
      expect(reused, isNotNull);
      expect(characters.characters.length, 1);
      expect(reused!.name, 'Cricket');
    });

    test('不同在线角色各自独立，不互相误判', () async {
      final characters = await seedProvider();

      await characters.createCharacter(
        name: 'A',
        extensions: const OnlineCharacter(
          id: 'char-001',
          name: 'A',
          description: '',
        ).importExtensions,
      );
      await characters.createCharacter(
        name: 'B',
        extensions: const OnlineCharacter(
          id: 'char-002',
          name: 'B',
          description: '',
        ).importExtensions,
      );

      expect(characters.findBySourceId('char-001')?.name, 'A');
      expect(characters.findBySourceId('char-002')?.name, 'B');
      expect(characters.findBySourceId('char-003'), isNull);
    });
  });

  group('导入后进入对话', () {
    test('已有对话则续聊（返回最近一条），无则新建', () async {
      final db = await AppDatabase.init();
      final chats = ChatProvider(db);
      await chats.loadConversations();

      expect(chats.latestConversationOf('char-local'), isNull);

      await chats.createConversation(characterId: 'char-local', title: '旧');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final newer =
          await chats.createConversation(characterId: 'char-local', title: '新');

      expect(chats.latestConversationOf('char-local')?.id, newer.id);
      // 其它角色不受影响
      expect(chats.latestConversationOf('char-other'), isNull);
    });
  });
}

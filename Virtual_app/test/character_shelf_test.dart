import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/providers/character_provider.dart';
import 'package:virtual/providers/chat_provider.dart';
import 'package:virtual/services/online_character_service.dart';

/// 角色库（原「书架」）的核心契约
///
/// 曾经的真实 bug：详情页在**在线卡列表**上点「加入角色库」后，库里空空如也。
/// 根因是 **id 空间错配** —— 详情页拿到的 `characterId` 是后端卡 ID（如「希露妲」），
/// 而角色库存的是本地角色 UUID；在线卡若未先导入本地库，`getCharacter(后端ID)`
/// 永远查不到 → `shelfCharacters` 过滤成空数组，且**不报任何错**。
///
/// 这些用例把「必须先导入本地、用本地 id 入库」这条链路钉死：
/// 一旦有人把入库改回直接用后端 ID，用例立刻变红。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    // AppDatabase 是单例，持有首次 init 的 prefs 实例；
    // setMockInitialValues 只换 SharedPreferences 静态缓存，不清 db 内数据，
    // 因此必须显式清空（含角色库），否则用例互相污染。
    final db = await AppDatabase.init();
    for (final c in db.getCharacters()) {
      await db.deleteCharacter(c.id);
    }
    for (final c in db.getConversations()) {
      await db.deleteConversation(c.id);
    }
    await db.clearCharacterShelf();
  });

  Future<CharacterProvider> seedProvider() async {
    final db = await AppDatabase.init();
    final provider = CharacterProvider(db);
    await provider.loadCharacters();
    return provider;
  }

  const onlineCard = OnlineCharacter(
    id: '希露妲',
    name: '希露妲',
    description: '无期迷途角色',
  );

  /// 模拟详情页「加入角色库」的正确流程：
  /// 先按 sourceId 查重，没有再导入本地，最后用**本地 id** 入库。
  Future<void> addOnlineCardToShelf(
    CharacterProvider chars,
    OnlineCharacter online,
  ) async {
    final existing = chars.findBySourceId(online.id);
    final local = existing ??
        await chars.createCharacter(
          name: online.name,
          description: online.description,
          extensions: online.importExtensions,
        );
    await chars.addToShelf(local.id);
  }

  group('复现根因', () {
    test('直接用后端卡 ID 入角色库 → 库内查不到（这就是当初的空库 bug）', () async {
      final chars = await seedProvider();

      // 在线卡还没导入本地库时，后端 ID 在本地是「查无此人」
      expect(chars.findBySourceId(onlineCard.id), isNull);
      expect(chars.getCharacter(onlineCard.id), isNull);

      // 即便如此，addToShelf 也会「成功」写入 —— 因为它是纯字符串记账，
      // 不校验 id 是否真的有对应角色。这正是 bug 静默无报错的原因。
      await chars.addToShelf(onlineCard.id);
      expect(chars.shelfIds, contains(onlineCard.id));

      // 但渲染用的 shelfCharacters 会把它全部过滤掉 → 界面空白
      expect(chars.shelfCharacters, isEmpty);
    });
  });

  group('正确链路：先导入本地，再用本地 id 入库', () {
    test('加入角色库后 shelfCharacters 能查到该卡', () async {
      final chars = await seedProvider();

      await addOnlineCardToShelf(chars, onlineCard);

      expect(chars.shelfCharacters.length, 1);
      expect(chars.shelfCharacters.first.name, '希露妲');
      // 存的是本地 UUID，不是后端 ID
      expect(chars.shelfIds.single, isNot(onlineCard.id));
      expect(chars.isInShelf(chars.findBySourceId(onlineCard.id)!.id), isTrue);
    });

    test('重复加入不会堆副本，且库内始终只有一张', () async {
      final chars = await seedProvider();

      await addOnlineCardToShelf(chars, onlineCard);
      await addOnlineCardToShelf(chars, onlineCard);
      await addOnlineCardToShelf(chars, onlineCard);

      expect(chars.characters.length, 1);
      expect(chars.shelfCharacters.length, 1);
      expect(chars.shelfIds.length, 1);
    });

    test('移出角色库后库内清空，但本地角色卡保留', () async {
      final chars = await seedProvider();
      await addOnlineCardToShelf(chars, onlineCard);

      final localId = chars.shelfIds.single;
      await chars.removeFromShelf(localId);

      expect(chars.shelfCharacters, isEmpty);
      expect(chars.shelfIds, isEmpty);
      // 移出角色库 ≠ 删除角色卡
      expect(chars.getCharacter(localId), isNotNull);
    });

    test('移出后再次加入仍能命中同一张本地卡（不产生第二张）', () async {
      final chars = await seedProvider();
      await addOnlineCardToShelf(chars, onlineCard);
      final localId = chars.shelfIds.single;

      await chars.removeFromShelf(localId);
      await addOnlineCardToShelf(chars, onlineCard);

      expect(chars.characters.length, 1);
      expect(chars.shelfIds.single, localId);
    });
  });

  group('持久化与排序', () {
    test('角色库跨 provider 实例存活（落 SharedPreferences）', () async {
      final chars = await seedProvider();
      await addOnlineCardToShelf(chars, onlineCard);
      final localId = chars.shelfIds.single;

      // 新建 provider 模拟重启后重新读库
      final reopened = await seedProvider();
      expect(reopened.shelfIds, contains(localId));
      expect(reopened.shelfCharacters.length, 1);
    });

    test('最新加入的排在最前', () async {
      final chars = await seedProvider();

      final first = await chars.createCharacter(name: '先加入');
      final second = await chars.createCharacter(name: '后加入');
      await chars.addToShelf(first.id);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await chars.addToShelf(second.id);

      expect(chars.shelfCharacters.first.name, '后加入');
      expect(chars.shelfCharacters.last.name, '先加入');
    });

    test('本地卡被删除后，残留的库记录不会崩（静默过滤）', () async {
      final chars = await seedProvider();
      await addOnlineCardToShelf(chars, onlineCard);
      final localId = chars.shelfIds.single;

      final db = await AppDatabase.init();
      await db.deleteCharacter(localId);
      await chars.loadCharacters();

      // id 记录还在，但角色已不存在 → 渲染层必须过滤掉，不能抛异常
      expect(chars.shelfIds, contains(localId));
      expect(chars.shelfCharacters, isEmpty);
    });
  });

  group('与「历史」分段的分工', () {
    test('加入角色库不自动创建会话（会话只在历史里出现）', () async {
      final db = await AppDatabase.init();
      final chars = CharacterProvider(db);
      await chars.loadCharacters();
      final chats = ChatProvider(db);
      await chats.loadConversations();

      await addOnlineCardToShelf(chars, onlineCard);

      final localId = chars.shelfIds.single;
      expect(chats.latestConversationOf(localId), isNull);

      // 建会话后，角色库卡面的「最近对话」预览才有内容
      await chats.createConversation(characterId: localId, title: '希露妲');
      expect(chats.latestConversationOf(localId), isNotNull);
    });
  });
}

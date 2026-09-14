import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/models/chat_message.dart';

/// 消息持久化契约：单条 key（O(1) 写入）+ 内存缓存 + 旧版整表迁移
///
/// 此前 saveMessage 每条消息都「读整表 JSON → 反序列化 → 追加 → 整表回写」，
/// 长对话每轮都有 O(n) 主线程 IO。改造后按条分 key，本文件钉死行为。
///
/// ⚠️ AppDatabase 是单例、持有首次 init 的 prefs 实例（同 character_shelf_test）：
/// 用例间靠唯一 convId 隔离；底层断言用 db 同款的 prefs 引用。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDatabase.init();
    // 与 AppDatabase 内部持有的是同一个缓存实例
    prefs = await SharedPreferences.getInstance();
  });

  String uniqueConv(String tag) =>
      'conv-$tag-${DateTime.now().microsecondsSinceEpoch}';

  ChatMessage msg(String convId, String id, String content, {int minute = 0}) =>
      ChatMessage(
        id: id,
        conversationId: convId,
        role: MessageRole.user,
        content: content,
        isGenerating: false,
        createdAt: DateTime(2026, 9, 14, 8, minute),
      );

  test('saveMessage 落单条 key（非整表），getMessages 可回读', () async {
    final db = await AppDatabase.init();
    final convId = uniqueConv('save');

    await db.saveMessage(convId, msg(convId, 'm1', '第一条', minute: 1));
    await db.saveMessage(convId, msg(convId, 'm2', '第二条', minute: 2));

    // 底层：两条 db_msg_<conv>_<id>，无 db_messages_<conv> 整表
    expect(
      prefs.getKeys().where((k) => k.startsWith('db_msg_$convId')),
      hasLength(2),
    );
    expect(
      prefs.getKeys().where((k) => k.startsWith('db_messages_$convId')),
      isEmpty,
    );

    final loaded = db.getMessages(convId);
    expect(loaded.map((m) => m.id), ['m1', 'm2']);
    expect(loaded.map((m) => m.content), ['第一条', '第二条']);
  });

  test('重复 saveMessage 同 id 只更新不追加', () async {
    final db = await AppDatabase.init();
    final convId = uniqueConv('upd');

    await db.saveMessage(convId, msg(convId, 'm1', '旧内容'));
    await db.saveMessage(convId, msg(convId, 'm1', '新内容'));

    final loaded = db.getMessages(convId);
    expect(loaded, hasLength(1));
    expect(loaded.single.content, '新内容');
    expect(
      prefs.getKeys().where((k) => k.startsWith('db_msg_$convId')),
      hasLength(1),
    );
  });

  test('旧版整表 key 懒迁移：数据保留、旧 key 删除、幂等', () async {
    final db = await AppDatabase.init();
    final convId = uniqueConv('legacy');
    final legacy = [
      msg(convId, 'l1', '旧一', minute: 1).toJson(),
      msg(convId, 'l2', '旧二', minute: 2).toJson(),
    ];
    prefs.setString('db_messages_$convId', jsonEncode(legacy));

    final loaded = db.getMessages(convId);
    expect(loaded.map((m) => m.id), ['l1', 'l2']);
    expect(loaded.map((m) => m.content), ['旧一', '旧二']);

    // 旧 key 已删除、单条 key 存在；再触发不重复
    expect(prefs.getString('db_messages_$convId'), isNull);
    expect(
      prefs.getKeys().where((k) => k.startsWith('db_msg_$convId')),
      hasLength(2),
    );
    final again = db.getMessages(convId);
    expect(again.map((m) => m.id), ['l1', 'l2']);
  });

  test('坏数据迁移：丢弃旧 key 不抛异常', () async {
    final db = await AppDatabase.init();
    final convId = uniqueConv('corrupt');
    prefs.setString('db_messages_$convId', '{not-json');

    expect(db.getMessages(convId), isEmpty);
    expect(prefs.getString('db_messages_$convId'), isNull);
  });

  test('deleteMessage 只删对应单条 key', () async {
    final db = await AppDatabase.init();
    final convId = uniqueConv('del');

    await db.saveMessage(convId, msg(convId, 'm1', '一', minute: 1));
    await db.saveMessage(convId, msg(convId, 'm2', '二', minute: 2));
    await db.deleteMessage(convId, 'm1');

    expect(db.getMessages(convId).map((m) => m.id), ['m2']);
  });

  test('clearMessages 清空该对话全部单条 key（含旧版 key）', () async {
    final db = await AppDatabase.init();
    final convId = uniqueConv('clr');

    await db.saveMessage(convId, msg(convId, 'm1', '一', minute: 1));
    await db.saveMessage(convId, msg(convId, 'm2', '二', minute: 2));
    // 再塞一个旧版 key，验证一并清理
    prefs.setString('db_messages_$convId', '[]');
    await db.clearMessages(convId);

    expect(db.getMessages(convId), isEmpty);
    expect(
      prefs.getKeys().where((k) => k.startsWith('db_msg_$convId')),
      isEmpty,
    );
    expect(prefs.getString('db_messages_$convId'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/data/app_database.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/models/chat_message.dart';
import 'package:virtual/models/lorebook.dart';
import 'package:virtual/models/preset.dart';
import 'package:virtual/providers/chat_provider.dart';
import 'package:virtual/services/prompt_service.dart';
import 'package:virtual/services/world_info_service.dart';

/// 「启用角色卡 → 字段参数绑定与切换」回归防线
///
/// 此前角色卡上的 `lorebookId` 只在编辑页展示，**从未进入 Prompt 组装**；
/// 预设（Preset）同样只有数据层没有组装层。对「角色全在世界书里」的卡，
/// 表现是模型完全不知道任何设定。本文件钉死：
///
/// 1. 世界书激活规则（constant 恒注入 / 关键词扫描 / selective AND /
///    scanDepth 窗口 / disable 反语义 / tokenBudget 截断）
/// 2. 绑定与切换：`会话绑定 > 角色卡绑定 > 全局激活`，切换角色即切换参数
/// 3. 端到端：世界书块 + 预设出现在最终 system / 消息列表里
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorldInfoService 条目激活', () {
    Lorebook book(List<LorebookEntry> entries,
            {int scanDepth = 0, int tokenBudget = 0, bool enabled = true}) =>
        Lorebook(
          id: 'book-1',
          name: '测试世界书',
          entries: entries,
          enabled: enabled,
          scanDepth: scanDepth,
          tokenBudget: tokenBudget,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    LorebookEntry entry(
      String content, {
      List<String> keys = const [],
      bool constant = false,
      bool enabled = true,
      List<String> secondary = const [],
      bool selective = false,
      int priority = 10,
      int order = 0,
      LorebookEntryPosition position = LorebookEntryPosition.afterSystem,
    }) =>
        LorebookEntry(
          id: content,
          key: keys.isNotEmpty ? keys.first : '',
          keys: keys,
          content: content,
          constant: constant,
          enabled: enabled,
          secondaryKeys: secondary,
          selective: selective,
          priority: priority,
          order: order,
          position: position,
        );

    test('constant 条目无关键词也恒注入', () {
      final b = book([entry('常驻设定', constant: true)]);
      final out = WorldInfoService.selectEntries(b, ['跟关键词无关的消息']);
      expect(out, hasLength(1));
      expect(out.single.content, '常驻设定');
    });

    test('关键词命中最近消息触发；未命中不注入', () {
      final b = book([entry('易中海是四合院一大爷', keys: ['易中海'])]);
      expect(WorldInfoService.selectEntries(b, ['聊聊易中海吧']), hasLength(1));
      expect(WorldInfoService.selectEntries(b, ['聊聊傻柱吧']), isEmpty);
    });

    test('匹配默认大小写不敏感', () {
      final b = book([entry('X-Shadow 协议', keys: ['x-shadow'])]);
      expect(WorldInfoService.selectEntries(b, ['启动 X-SHADOW']), hasLength(1));
    });

    test('disable（反语义）条目永不注入', () {
      final b = book([entry('已停用', keys: ['易中海'], enabled: false)]);
      expect(WorldInfoService.selectEntries(b, ['易中海']), isEmpty);
    });

    test('书整体停用（enabled=false）→ 全部不注入', () {
      final b = book([entry('常驻设定', constant: true)], enabled: false);
      expect(WorldInfoService.selectEntries(b, ['任意']), isEmpty);
    });

    test('selective：次要关键词须全部命中', () {
      final b = book([
        entry('秦淮茹的设定',
            keys: ['秦淮茹'], secondary: ['棉纺厂', '1965'], selective: true),
      ]);
      expect(WorldInfoService.selectEntries(b, ['秦淮茹在棉纺厂']), isEmpty);
      expect(WorldInfoService.selectEntries(b, ['秦淮茹进了棉纺厂，正是1965年']),
          hasLength(1));
    });

    test('scanDepth 窗口：窗口外的关键词不触发', () {
      final b = book([entry('聋老太的设定', keys: ['聋老太'])], scanDepth: 2);
      // 最近 2 条不含关键词，更早的第 3 条含 → 不触发
      final out = WorldInfoService.selectEntries(b, [
        '聋老太出场',
        '别的消息',
        '别的消息',
      ]);
      expect(out, isEmpty);
    });

    test('tokenBudget 截断：高优先级先占预算', () {
      final b = book([
        entry('低优先级设定' * 4, keys: ['kw'], priority: 1),
        entry('高优先级设定' * 4, keys: ['kw'], priority: 99),
      ], tokenBudget: 12); // 24 字符 ≈ 12 token
      final out = WorldInfoService.selectEntries(b, ['kw']);
      expect(out, hasLength(1));
      expect(out.single.content, '高优先级设定' * 4);
    });

    test('渲染分块：位置语义正确，top 归 beforeSystem、bottom 归 afterSystem', () {
      final blocks = WorldInfoService.renderBlocks([
        entry('前块', constant: true, position: LorebookEntryPosition.beforeSystem),
        entry('后块', constant: true, position: LorebookEntryPosition.afterSystem),
        entry('用户前', constant: true, position: LorebookEntryPosition.beforeUser),
        entry('用户后', constant: true, position: LorebookEntryPosition.afterUser),
        entry('兜底', constant: true, position: LorebookEntryPosition.top),
      ]);
      expect(blocks.beforeSystem, '前块\n兜底');
      expect(blocks.afterSystem, '后块');
      expect(blocks.beforeUser, '用户前');
      expect(blocks.afterUser, '用户后');
    });
  });

  group('绑定与切换（ChatProvider.resolve*）', () {
    late AppDatabase db;
    late ChatProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await AppDatabase.init();
      for (final b in db.getLorebooks()) {
        await db.deleteLorebook(b.id);
      }
      provider = ChatProvider(db);
    });

    test('角色卡绑定书 → 启用即生效；书停用/删除后自动解绑', () async {
      final now = DateTime(2026);
      final book = Lorebook(
        id: 'lb-1',
        name: '情满四合院',
        createdAt: now,
        updatedAt: now,
        entries: [LorebookEntry(id: 'e1', key: '易中海', content: '一大爷')],
      );
      await db.saveLorebook(book);
      expect(provider.resolveLorebook('lb-1'), isNotNull);

      await db.saveLorebook(Lorebook(
        id: 'lb-1',
        name: '情满四合院',
        enabled: false,
        createdAt: now,
        updatedAt: now,
      ));
      expect(provider.resolveLorebook('lb-1'), isNull);

      await db.deleteLorebook('lb-1');
      expect(provider.resolveLorebook('lb-1'), isNull);
    });

    test('切换绑定 id 即切换书（A/B 两书互不影响）', () async {
      final now = DateTime(2026);
      await db.saveLorebook(Lorebook(
          id: 'lb-a', name: 'A书', createdAt: now, updatedAt: now));
      await db.saveLorebook(Lorebook(
          id: 'lb-b', name: 'B书', createdAt: now, updatedAt: now));

      expect(provider.resolveLorebook('lb-a')!.name, 'A书');
      expect(provider.resolveLorebook('lb-b')!.name, 'B书');
    });

    test('预设：会话绑定优先于全局激活', () async {
      final now = DateTime(2026);
      final active = Preset(
        id: 'p-active',
        name: '全局激活',
        entries: const [],
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      final bound = Preset(
        id: 'p-bound',
        name: '会话绑定',
        entries: const [],
        createdAt: now,
        updatedAt: now,
      );
      await db.savePreset(active);
      await db.savePreset(bound);

      expect(provider.resolvePreset(null)!.id, 'p-active');
      expect(provider.resolvePreset('p-bound')!.id, 'p-bound');
    });
  });

  group('端到端：buildMessages 注入', () {
    Lorebook book() => Lorebook(
          id: 'lb-x',
          name: '四合院世界书',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          entries: [
            LorebookEntry(
              id: 'e1',
              key: '',
              content: '常驻：故事发生在红星公社四合院',
              constant: true,
              position: LorebookEntryPosition.afterSystem,
            ),
          ],
        );

    Preset preset() => Preset(
          id: 'p-x',
          name: '文风预设',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          entries: [
            PresetEntry(
              id: 'pe1',
              label: 'System Prompt',
              type: PresetEntryType.systemPrompt,
              role: PresetEntryRole.system,
              position: PresetEntryPosition.top,
              content: '以京味儿口语写作',
              order: 0,
            ),
          ],
        );

    Character character() => Character(
          id: 'char-1',
          name: '希露妲',
          description: '四合院的采购员。',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('预设置于最前，世界书常驻块进 system，且宏已替换', () {
      final messages = PromptService.buildMessages(
        character: character(),
        history: const [],
        userMessage: '你好',
        persona: null,
        lorebook: book(),
        preset: preset(),
      );

      final system = messages.first['content'] as String;
      expect(system.indexOf('以京味儿口语写作'),
          lessThan(system.indexOf('四合院的采购员')));
      expect(system.contains('常驻：故事发生在红星公社四合院'), isTrue);
      // 只有 system 一条 + 用户消息（beforeUser/afterUser 为空不插系统消息）
      expect(messages, hasLength(2));
    });

    test('beforeUser / afterUser 块插在最新用户消息前后', () {
      final b = Lorebook(
        id: 'lb-y',
        name: 'AN 位',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        entries: [
          LorebookEntry(
            id: 'e1',
            key: '',
            content: '用户前注入',
            constant: true,
            position: LorebookEntryPosition.beforeUser,
          ),
          LorebookEntry(
            id: 'e2',
            key: '',
            content: '用户后注入',
            constant: true,
            position: LorebookEntryPosition.afterUser,
          ),
        ],
      );

      final messages = PromptService.buildMessages(
        character: character(),
        history: const [],
        userMessage: '{{user}} 推门而入',
        persona: null,
        lorebook: b,
      );

      expect(messages, hasLength(4)); // system / 系统(用户前) / user / 系统(用户后)
      expect(messages[1]['content'], '用户前注入');
      expect(messages[2]['content'], 'User 推门而入'); // 无 persona 无昵称 → User
      expect(messages[3]['content'], '用户后注入');
    });

    test('关键词条目命中历史消息触发，未命中缺席', () {
      final b = Lorebook(
        id: 'lb-z',
        name: '触发书',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        entries: [
          LorebookEntry(id: 'e1', key: '许大茂', content: '许大茂是二溜子'),
        ],
      );
      final history = [
        ChatMessage(
          id: 'm1',
          conversationId: 'c1',
          role: MessageRole.user,
          content: '许大茂又干什么了？',
          createdAt: DateTime(2026),
        ),
      ];

      final hit = PromptService.buildMessages(
        character: character(),
        history: history,
        userMessage: '继续',
        persona: null,
        lorebook: b,
      );
      final miss = PromptService.buildMessages(
        character: character(),
        history: const [],
        userMessage: '继续',
        persona: null,
        lorebook: b,
      );

      expect(
        (hit.first['content'] as String).contains('许大茂是二溜子'),
        isTrue,
      );
      expect(
        (miss.first['content'] as String).contains('许大茂是二溜子'),
        isFalse,
      );
    });
  });
}

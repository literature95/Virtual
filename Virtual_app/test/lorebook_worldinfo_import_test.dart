import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/models/lorebook.dart';
import 'package:virtual/services/lorebook_import_service.dart';

import 'fixtures/cricket_card.dart';

/// 世界书 JSON 导入的回归基线
///
/// 锁定的核心事实：**真实世界书不是 CCv3 `character_book` 的形态**。
/// 对磁盘上 231 个真实文件实测，221 个用的是 SillyTavern World Info ——
/// `entries` 是**对象**而非数组、用 `disable`（反语义）而非 `enabled`、
/// `position` 是**整数**而非字符串。旧实现只按数组解析，对这批文件会
/// 静默得到 0 条目（"导入成功"但世界书是空的）。
///
/// 每个字段的断言都对应一个会静默出错的具体写法，而非泛泛的"能解析"。
void main() {
  final service = LorebookImportService();

  /// 与磁盘真实文件同构的 SillyTavern World Info
  String stWorldInfo({
    String? name,
    Map<String, dynamic>? entryOverride,
    Map<String, dynamic>? extraEntry,
  }) {
    return jsonEncode({
      if (name != null) 'name': name,
      'entries': {
        '0': {
          'uid': 0,
          'key': ['魔晶'],
          'keysecondary': ['魔力结晶'],
          'comment': '魔晶',
          'content': '是魔力的结晶，可以快速提高魔法亲合度。',
          'constant': true,
          'selective': true,
          'order': 50,
          'position': 1,
          'excludeRecursion': false,
          'disable': false,
          'addMemo': true,
          'displayIndex': 0,
          'probability': 100,
          'useProbability': true,
          ...?entryOverride,
        },
        if (extraEntry != null) '1': extraEntry,
      },
    });
  }

  group('SillyTavern World Info（真实世界书的主流形态）', () {
    test('entries 为对象时逐个解析，而不是当成空数组', () {
      final result = service.importFromJsonText(stWorldInfo());

      expect(result.sourceFormat, 'SillyTavern World Info');
      expect(result.lorebook.entries.length, 1);
      final e = result.lorebook.entries.single;
      expect(e.keys, ['魔晶']);
      expect(e.content, contains('魔力的结晶'));
      expect(e.constant, isTrue);
      expect(e.order, 50);
      expect(e.comment, '魔晶');
    });

    test('disable 是反语义：disable:true → enabled:false', () {
      final result = service.importFromJsonText(
        stWorldInfo(entryOverride: {'disable': true}),
      );
      expect(result.lorebook.entries.single.enabled, isFalse);

      final enabled = service.importFromJsonText(
        stWorldInfo(entryOverride: {'disable': false}),
      );
      expect(enabled.lorebook.entries.single.enabled, isTrue);
    });

    test('整数 position 映射到注入位置', () {
      // 0=before_char 1=after_char 2=before_AN 3=after_AN 4=at_depth
      final expected = {
        0: LorebookEntryPosition.beforeSystem,
        1: LorebookEntryPosition.afterSystem,
        2: LorebookEntryPosition.beforeUser,
        3: LorebookEntryPosition.afterUser,
        4: LorebookEntryPosition.beforeUser,
      };
      expected.forEach((raw, position) {
        final result = service.importFromJsonText(
          stWorldInfo(entryOverride: {'position': raw}),
        );
        expect(
          result.lorebook.entries.single.position,
          position,
          reason: 'position=$raw 应映射为 $position',
        );
      });
    });

    test('selective:false 表示次要关键词不参与匹配，应当清空', () {
      final result = service.importFromJsonText(
        stWorldInfo(entryOverride: {'selective': false}),
      );
      expect(result.lorebook.entries.single.secondaryKeys, isEmpty);
    });

    test('selectiveLogic 决定 AND/OR 语义，而非直接照搬 selective 布尔', () {
      // 0 = AND_ANY（主关键词 + 任一次要关键词）→ 等价于本模型 selective:false
      final any = service.importFromJsonText(
        stWorldInfo(entryOverride: {'selective': true, 'selectiveLogic': 0}),
      );
      expect(any.lorebook.entries.single.secondaryKeys, ['魔力结晶']);
      expect(any.lorebook.entries.single.selective, isFalse);

      // 3 = AND_ALL（次要关键词需全部命中）→ 本模型 selective:true
      final all = service.importFromJsonText(
        stWorldInfo(entryOverride: {'selective': true, 'selectiveLogic': 3}),
      );
      expect(all.lorebook.entries.single.selective, isTrue);
    });

    test('useProbability:false 时概率归 100（否则条目会随机失效）', () {
      final result = service.importFromJsonText(
        stWorldInfo(
          entryOverride: {'useProbability': false, 'probability': 0},
        ),
      );
      expect(result.lorebook.entries.single.probability, 100);
    });

    test('key 写成字符串（非数组）时不丢触发词', () {
      final result = service.importFromJsonText(
        stWorldInfo(entryOverride: {'key': '单个关键词', 'keysecondary': []}),
      );
      expect(result.lorebook.entries.single.matchKeys, ['单个关键词']);
    });

    test('顶层缺 name 时回退到文件名，而不是一屏同名 World Book', () {
      final result = service.importFromJsonText(
        stWorldInfo(),
        sourceName: r'D:\cards\魔晶世界书.json',
      );
      expect(result.lorebook.name, '魔晶世界书');
    });

    test('顶层有 name 时以 name 为准', () {
      final result = service.importFromJsonText(
        stWorldInfo(name: '提瓦特设定集'),
        sourceName: '随便.json',
      );
      expect(result.lorebook.name, '提瓦特设定集');
    });

    test('SillyTavern 专有字段进 extensions，导出时回写', () {
      final result = service.importFromJsonText(
        stWorldInfo(
          entryOverride: {
            'group': 'g1',
            'scanDepth': 4,
            'matchWholeWords': true,
            'sticky': 3,
          },
        ),
      );
      final e = result.lorebook.entries.single;
      expect(e.extensions['group'], 'g1');
      expect(e.extensions['scanDepth'], 4);

      final back = e.toWorldInfo(index: 7);
      expect(back['group'], 'g1');
      expect(back['matchWholeWords'], true);
      expect(back['uid'], 7);
    });

    test('条目 id 唯一（一次解析上千条时不能靠时间戳碰运气）', () {
      final entries = <String, dynamic>{};
      for (var i = 0; i < 800; i++) {
        entries['$i'] = {
          'uid': i,
          'key': ['k$i'],
          'keysecondary': <String>[],
          'content': 'c$i',
          'disable': false,
        };
      }
      final result = service.importFromJsonText(
        jsonEncode({'entries': entries}),
      );
      final ids = result.lorebook.entries.map((e) => e.id).toSet();
      expect(result.lorebook.entries.length, 800);
      expect(ids.length, 800, reason: 'id 出现重复会导致编辑页条目互相覆盖');
    });
  });

  group('CCv3 character_book（entries 为数组）', () {
    test('真实夹具卡内的 character_book 可独立导入', () {
      final card = jsonDecode(cricketCardJson) as Map<String, dynamic>;
      final book = (card['data'] as Map)['character_book'] as Map;
      final result = service.importFromJson(Map<String, dynamic>.from(book));

      expect(result.sourceFormat, 'Character Card v3 character_book');
      expect(result.lorebook.entries.length, 2);
      expect(result.lorebook.entries.first.keys, isNotEmpty);
    });
  });

  group('错误与引导', () {
    test('角色卡 JSON 被拒绝，并提示改用 PNG 入口', () {
      expect(
        () => service.importFromJsonText(cricketCardJson),
        throwsA(
          predicate<Exception>(
            (e) => e.toString().contains('角色卡') && e.toString().contains('PNG'),
            '应明确告知角色卡用 PNG 导入',
          ),
        ),
      );
    });

    test('SillyTavern 预设（采样参数）被识别为非世界书', () {
      final preset = jsonEncode({
        'chat_completion_source': 'openai',
        'temperature': 0.8,
        'top_p': 0.9,
      });
      expect(
        () => service.importFromJsonText(preset),
        throwsA(isA<Exception>()),
      );
    });

    test('非 JSON 文本给出可读错误', () {
      expect(
        () => service.importFromBytes(
          utf8.encode('这不是 JSON'),
          sourceName: 'a.json',
        ),
        throwsA(
          predicate<Exception>((e) => e.toString().contains('a.json')),
        ),
      );
    });
  });

  group('导出往返', () {
    test('toWorldInfo → 再导入，条目数与关键字段一致', () {
      final first = service.importFromJsonText(
        stWorldInfo(name: '往返测试'),
      ).lorebook;

      final reimported =
          service.importFromJson(first.toWorldInfo()).lorebook;

      expect(reimported.name, first.name);
      expect(reimported.entries.length, first.entries.length);
      for (var i = 0; i < first.entries.length; i++) {
        final a = first.entries[i];
        final b = reimported.entries[i];
        expect(b.matchKeys, a.matchKeys);
        expect(b.secondaryKeys, a.secondaryKeys);
        expect(b.content, a.content);
        expect(b.enabled, a.enabled, reason: 'disable 反语义必须双向对称');
        expect(b.order, a.order);
        expect(b.constant, a.constant);
        expect(b.position, a.position);
      }
    });
  });
}

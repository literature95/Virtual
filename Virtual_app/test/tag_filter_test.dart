import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/services/online_character_service.dart';
import 'package:virtual/utils/random_order.dart';
import 'package:virtual/views/home/tag_filter_data.dart';

void main() {
  final chars = [
    const OnlineCharacter(
      id: 'c1',
      name: '晓夜',
      description: '深夜便利店的夜班店员，温柔治愈。',
      tags: ['治愈', '日常', '店员', '深夜'],
    ),
    const OnlineCharacter(
      id: 'c2',
      name: '星图',
      description: '星舰舰长，在科幻宇宙里探索未知星域。',
      tags: ['科幻', '探索', '舰长'],
    ),
    const OnlineCharacter(
      id: 'c3',
      name: '墨白',
      description: '古风书生，儒雅安静。',
      tags: ['古风', '文人'],
    ),
  ];

  group('buildTagFilterGroups', () {
    test('固定四组，顺序与左侧栏一致', () {
      final groups = buildTagFilterGroups(chars);
      expect(groups.map((g) => g.title).toList(), kTagGroupTitles);
      expect(groups.length, 4);
    });

    test('优先使用角色真实 tags', () {
      final groups = buildTagFilterGroups(chars);
      expect(groups[0].tags, containsAll(['治愈', '日常'])); // 热门标签
      expect(groups[1].tags, contains('科幻')); // 主题
      expect(groups[2].tags, contains('店员')); // 角色
      expect(groups[3].tags, contains('深夜')); // 情节
    });

    test('不会输出数据中不存在的标签（否则必然空结果）', () {
      final groups = buildTagFilterGroups(chars);
      final allTags = chars.expand((c) => c.tags).toSet();
      for (final g in groups) {
        for (final tag in g.tags) {
          final present = allTags.contains(tag) ||
              chars.any((c) => c.name.contains(tag) || c.description.contains(tag));
          expect(present, isTrue, reason: '「$tag」不在数据中');
        }
      }
    });
  });

  group('characterMatchesGroups', () {
    test('同组并集：命中组内任一标签即通过', () {
      expect(
        characterMatchesGroups(chars[0], {
          '主题': {'治愈', '科幻'},
        }),
        isTrue,
      );
    });

    test('跨组交集：每组都必须命中', () {
      // 晓夜没有「舰长」，跨组交集失败
      expect(
        characterMatchesGroups(chars[0], {
          '主题': {'治愈'},
          '角色': {'舰长'},
        }),
        isFalse,
      );
      // 星图同时命中科幻 + 舰长
      expect(
        characterMatchesGroups(chars[1], {
          '主题': {'科幻'},
          '角色': {'舰长'},
        }),
        isTrue,
      );
    });

    test('空选组视为未启用，不参与过滤', () {
      expect(
        characterMatchesGroups(chars[2], {'主题': <String>{}}),
        isTrue,
      );
    });

    test('无对应 tag 时可按名称/描述关键词命中', () {
      expect(characterMatchesTag(chars[2], '书生'), isTrue);
      expect(characterMatchesTag(chars[2], '舰长'), isFalse);
    });
  });

  group('shuffledOrder', () {
    test('返回副本，不修改原列表，元素不丢', () {
      final src = List<int>.generate(10, (i) => i);
      final out = shuffledOrder(src, Random(42));
      expect(src, equals(List<int>.generate(10, (i) => i)));
      final sorted = out.toList()..sort();
      expect(sorted, equals(src));
    });

    test('固定种子结果稳定，可用于确定性测试', () {
      final a = shuffledOrder([1, 2, 3, 4, 5], Random(7));
      final b = shuffledOrder([1, 2, 3, 4, 5], Random(7));
      expect(a, equals(b));
    });
  });
}

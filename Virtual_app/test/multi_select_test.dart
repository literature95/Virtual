import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/utils/multi_select.dart';

void main() {
  group('MultiSelectState', () {
    test('初始为空，count=0', () {
      const s = MultiSelectState();
      expect(s.count, 0);
      expect(s.isEmpty, isTrue);
      expect(s.contains('a'), isFalse);
    });

    test('toggle 加入与移除', () {
      final s1 = const MultiSelectState().toggle('a');
      expect(s1.count, 1);
      expect(s1.contains('a'), isTrue);

      final s2 = s1.toggle('b');
      expect(s2.count, 2);

      final s3 = s2.toggle('a');
      expect(s3.count, 1);
      expect(s3.contains('a'), isFalse);
      expect(s3.contains('b'), isTrue);
    });

    test('toggle 不修改原状态（不可变）', () {
      const base = MultiSelectState({'a'});
      final next = base.toggle('b');
      expect(base.contains('b'), isFalse);
      expect(base.count, 1);
      expect(next.count, 2);
    });

    test('selectAll 全选并保留已选项', () {
      final s = const MultiSelectState({'a'}).selectAll(['a', 'b', 'c']);
      expect(s.count, 3);
      expect(s.selected, {'a', 'b', 'c'});
    });

    test('selectAll 空集合不改变计数', () {
      final s = const MultiSelectState({'a'}).selectAll(const []);
      expect(s.count, 1);
    });

    test('clear 归零', () {
      final s = const MultiSelectState({'a', 'b'}).clear();
      expect(s.count, 0);
      expect(s.isEmpty, isTrue);
    });

    test('重复 id 不会重复计数', () {
      final s = const MultiSelectState({'a'}).selectAll(['a', 'a', 'b']);
      expect(s.count, 2);
    });
  });
}

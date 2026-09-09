import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/models/banner_item.dart';

void main() {
  group('BannerItem.fromJson', () {
    test('解析完整字段', () {
      final item = BannerItem.fromJson(const {
        'id': 'banner-001',
        'title': '晓夜 · 深夜便利店',
        'subtitle': '「要不要热一下？」',
        'imageUrl': 'http://192.168.1.9:8080/avatars/char-001.jpg',
        'characterId': 'char-001',
      });

      expect(item.id, 'banner-001');
      expect(item.title, '晓夜 · 深夜便利店');
      expect(item.subtitle, '「要不要热一下？」');
      expect(item.imageUrl, endsWith('/avatars/char-001.jpg'));
      expect(item.characterId, 'char-001');
      expect(item.canOpen, isTrue);
    });

    test('字段缺失或为 null 时不抛错', () {
      final item = BannerItem.fromJson(const {
        'id': null,
        'imageUrl': null,
      });

      expect(item.id, isEmpty);
      expect(item.title, isEmpty);
      expect(item.subtitle, isEmpty);
      expect(item.imageUrl, isNull);
      expect(item.canOpen, isFalse);
    });

    test('characterId 为空串时不可点击', () {
      final item = BannerItem.fromJson(const {
        'id': 'banner-x',
        'title': '纯展示位',
        'characterId': '',
      });

      expect(item.canOpen, isFalse);
    });

    test('非字符串 id 被转成字符串', () {
      final item = BannerItem.fromJson(const {'id': 7});

      expect(item.id, '7');
    });
  });
}

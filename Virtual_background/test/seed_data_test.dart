import 'package:test/test.dart';
import 'package:virtual_background/database/seed.dart';

/// 种子数据契约测试：守护 /api/* 响应结构与 R3 安全修复（密钥不硬编码）。
/// 纯内存测试，不依赖 PostgreSQL 与网络，CI 可稳定运行。
void main() {
  group('SeedData.metadata', () {
    test('包含必备条目（uris / quick-setup / plugin-market）', () {
      final ids = SeedData.metadata.map((e) => e['id']).toSet();
      expect(ids, containsAll(['uris', 'quick-setup', 'plugin-market']));
    });

    test('默认不含 api-secret（R3：密钥仅通过编译期变量注入）', () {
      final ids = SeedData.metadata.map((e) => e['id']);
      expect(ids, isNot(contains('api-secret')));
    });

    test('每项均含 desc/id/name/obj/tag 五个字段', () {
      for (final entry in SeedData.metadata) {
        expect(
          entry.keys,
          containsAll(['desc', 'id', 'name', 'obj', 'tag']),
          reason: '条目 ${entry['id']} 字段不完整',
        );
      }
    });
  });

  group('SeedData.characters', () {
    test('包含 5 个角色', () {
      expect(SeedData.characters, hasLength(5));
    });

    test('每个角色字段完整且 id 唯一', () {
      final ids = <String>{};
      for (final c in SeedData.characters) {
        expect(
          c.keys,
          containsAll([
            'id',
            'name',
            'description',
            'avatar_url',
            'tags',
            'greeting',
            'first_message',
            'persona',
          ]),
          reason: '角色 ${c['id']} 字段不完整',
        );
        expect(ids.add(c['id'] as String), isTrue, reason: '角色 id 重复');
        expect(c['tags'], isA<List<dynamic>>());
      }
    });
  });

  group('SeedData.appInfo', () {
    test('字段完整', () {
      expect(
        SeedData.appInfo.keys,
        containsAll([
          'id',
          'name',
          'version',
          'description',
          'features',
          'download_url',
        ]),
      );
      expect(SeedData.appInfo['features'], isA<List<dynamic>>());
    });
  });
}

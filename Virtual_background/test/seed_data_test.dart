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

    test('每个角色字段完整（CCv3 命名）且 id 唯一', () {
      final ids = <String>{};
      for (final c in SeedData.characters) {
        expect(
          c.keys,
          containsAll([
            'id',
            'name',
            'description',
            'personality',
            'scenario',
            'avatar_url',
            'tags',
            'first_mes',
            'example_messages',
            'alternate_greetings',
            'creator',
            'character_version',
            'source',
          ]),
          reason: '角色 ${c['id']} 字段不完整',
        );
        expect(ids.add(c['id'] as String), isTrue, reason: '角色 id 重复');
        expect(c['tags'], isA<List<dynamic>>());
        expect(c['avatar_url'], startsWith('/avatars/'));
      }
    });

    /// 反「纸片人」护栏。
    ///
    /// 成熟第三方卡片（如 chub.ai 的 Cricket）约 1.4k tokens；只写一句 persona 的
    /// 角色在三轮对话后必然漂移。此处用可量化的下限锁住这件事：
    /// 若有人把 description 改回一句话，这条测试会直接失败。
    test('人设密度达标：description / first_mes / example_messages 有实质内容', () {
      for (final c in SeedData.characters) {
        final id = c['id'];
        final desc = c['description'] as String? ?? '';
        final first = c['first_mes'] as String? ?? '';

        expect(desc.length, greaterThan(400),
            reason: '$id 的 description 过薄（${desc.length} 字符）');
        expect(desc, contains('\n'),
            reason: '$id 的 description 应为结构化多行人设');
        expect((c['personality'] as String? ?? '').length, greaterThan(60),
            reason: '$id 缺少 personality');
        expect((c['scenario'] as String? ?? '').length, greaterThan(40),
            reason: '$id 缺少 scenario');
        expect(first.length, greaterThan(150),
            reason: '$id 的 first_mes 太短，起不到开场作用');

        final examples = c['example_messages'] as List? ?? [];
        expect(examples.length, greaterThanOrEqualTo(2),
            reason: '$id 的示例对话不足 2 组，语气样本不够');
        for (final e in examples) {
          final m = e as Map<String, dynamic>;
          expect((m['userMessage'] as String? ?? '').trim(), isNotEmpty,
              reason: '$id 示例对话缺 userMessage');
          expect((m['assistantMessage'] as String? ?? '').trim(), isNotEmpty,
              reason: '$id 示例对话缺 assistantMessage');
          // 语气样本要有长度，单句对答无法示范文风
          expect((m['assistantMessage'] as String).length, greaterThan(80),
              reason: '$id 示例对话过短，无法示范语气');
        }

        final alts = c['alternate_greetings'] as List? ?? [];
        expect(alts.length, greaterThanOrEqualTo(2),
            reason: '$id 的备用开场不足 2 条');
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

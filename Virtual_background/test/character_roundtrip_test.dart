import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:virtual_background/character_card_mapper.dart';

/// 角色卡上传/导出 round-trip 契约测试。
///
/// 核心承诺（docs/character-publish-design.md §1 目标 4）：
/// 上传 → 导出，语义级完全一致。实现上依赖 `raw_card` 原样存取——
/// 本测试在纯内存层验证 mapper 双向函数，不依赖 PostgreSQL。
///
/// 夹具：真实 chub.ai 卡（Cricket），每 entry 带 15 个字段、
/// data.extensions 含 chub/agnai/depth_prompt，是「经模型往返必丢字段」的
/// 最严苛样本。谁改丢了字段，这里会红。
void main() {
  final fixtureFile = File('test/fixtures/cricket_card_v2.json');
  final card =
      jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
  final data = card['data'] as Map<String, dynamic>;

  group('CharacterCardMapper.cardToRow（上传投影）', () {
    test('完整 spec 包与裸 data 两种形态均识别', () {
      final fromEnvelope = CharacterCardMapper.normalizeCardJson(card);
      expect(canonicalEquals(fromEnvelope, data), isTrue);
      expect(
        canonicalEquals(CharacterCardMapper.normalizeCardJson(data), data),
        isTrue,
      );
      expect(CharacterCardMapper.normalizeCardJson({'foo': 1}), isNull);
      expect(CharacterCardMapper.normalizeCardJson('not a map'), isNull);
    });

    test('版本决策：请求字段 > 卡内值 > 1.0', () {
      // 卡内值为 "main"
      final row = CharacterCardMapper.cardToRow(data);
      expect(row['character_version'], 'main');

      final rowOverride = CharacterCardMapper.cardToRow(
        Map<String, dynamic>.from(data),
        characterVersion: '2.0',
      );
      expect(rowOverride['character_version'], '2.0');

      final noVersion = Map<String, dynamic>.from(data)
        ..remove('character_version');
      expect(
        CharacterCardMapper.cardToRow(noVersion)['character_version'],
        '1.0',
      );
    });

    test('character_id 未传时由 name 生成 slug', () {
      final row = CharacterCardMapper.cardToRow(data);
      expect(row['id'], 'cricket');
      final rowWithId = CharacterCardMapper.cardToRow(
        data,
        characterId: 'my-local-uuid',
      );
      expect(rowWithId['id'], 'my-local-uuid');
    });

    test('mes_example 字符串解析为 App 可消费的结构化数组', () {
      final row = CharacterCardMapper.cardToRow(data);
      final pairs = CharacterCardMapper.decodeJson<List<dynamic>>(
        row['example_messages'],
        [],
      );
      // Cricket 卡用 `1.` `2.` 编号分界 + 任意角色名前缀（Handsome Dragonborn）
      expect(pairs, hasLength(2));
      final first = pairs.first as Map;
      // 说话人前缀剥离：Dragonborn（未知第三方名）→ user 侧，名字不进消息体
      expect(
        first['userMessage'],
        'Good evening! Are you the owner of this fine establishment?',
      );
      // Cricket（== charName）→ assistant 侧
      expect(first['assistantMessage'], contains('Uh-huh! Yep! Hi!'));
      expect(first['assistantMessage'], isNot(startsWith('Cricket:')));
      // 续写行归并到上一位说话人
      expect(first['assistantMessage'], contains('pulls out a paper'));
    });

    test('character_book 与 extensions 原样存取（M3 约束）', () {
      final row = CharacterCardMapper.cardToRow(data);
      final book = CharacterCardMapper.decodeJson<Map<String, dynamic>>(
        row['character_book'],
        {},
      );
      final entries = book['entries'] as List;
      final ext0 = (entries.first as Map)['extensions'] as Map;
      // 这些私有字段经模型往返必丢，原样存取必须全保留
      expect(ext0['characterFilter'], isNull); // 卡内即为 null，仅验证键存在语义
      expect(ext0['excludeRecursion'], true);
      expect(ext0['displayIndex'], 1);
      expect(ext0['useProbability'], true);
      expect((entries.first as Map)['case_sensitive'], false);
      expect((entries.first as Map)['selectiveLogic'], 0);

      final dataExt = CharacterCardMapper.decodeJson<Map<String, dynamic>>(
        row['extensions'],
        {},
      );
      expect(
        (dataExt['chub'] as Map)['full_path'],
        'cutenotlewd/cricket-674c71b2',
      );
      expect(dataExt['depth_prompt'], isNotNull);
      expect(dataExt['agnai'], isNotNull);
    });
  });

  group('CharacterCardMapper.rowToExportData（round-trip）', () {
    test('raw_card 路径：导出与上传语义级全等（含 avatar）', () {
      final row = CharacterCardMapper.cardToRow(
        data,
        characterId: 'cricket',
        avatarUrl: '/uploads/char-cricket-main.jpg',
      );
      // 模拟 DB round-trip：JSONB 出来是字符串，decodeJson 统一兜底
      final exported = CharacterCardMapper.rowToExportData(row);
      final canonical = CharacterCardMapper.canonicalJson(exported);
      final expected = CharacterCardMapper.canonicalJson(data);

      expect(canonical, expected, reason: 'round-trip 破坏性差异：导出内容与上传不一致');
    });

    test('raw_card 为 NULL 时走列重组路径（种子形态）', () {
      final row = <String, dynamic>{
        'id': 'char-001',
        'character_version': '1.0',
        'name': '晓夜',
        'description': '描述',
        'personality': '性格',
        'scenario': '场景',
        'first_message': '开场白',
        'example_messages': CharacterCardMapper.jsonb([
          {'userMessage': '你好', 'assistantMessage': '嗨'},
        ]),
        'creator_notes': '备注',
        'system_prompt': null,
        'post_history_instructions': null,
        'creator': 'Virtual',
        'avatar_url': '/avatars/char-001.jpg',
        'tags': CharacterCardMapper.jsonb(['治愈']),
        'alternate_greetings': CharacterCardMapper.jsonb([]),
        'group_only_greetings': CharacterCardMapper.jsonb([]),
        'extensions': CharacterCardMapper.jsonb({}),
        'character_book': CharacterCardMapper.jsonb({}),
        'creator_notes_multilingual': CharacterCardMapper.jsonb({}),
        'raw_card': null,
      };
      final exported = CharacterCardMapper.rowToExportData(row);
      expect(exported['name'], '晓夜');
      expect(exported['first_mes'], '开场白');
      expect(exported['mes_example'], contains('{{user}}: 你好'));
      expect(exported['mes_example'], contains('{{char}}: 嗨'));
      expect(exported['avatar'], '/avatars/char-001.jpg');
      final envelope = CharacterCardMapper.exportEnvelope(exported);
      expect(envelope['spec'], 'chara_card_v2');
      expect(envelope['spec_version'], '2.0');
    });

    test('exportEnvelope 产出完整 CCv2 包', () {
      final row = CharacterCardMapper.cardToRow(data, characterId: 'cricket');
      final exported = CharacterCardMapper.rowToExportData(row);
      final envelope = CharacterCardMapper.exportEnvelope(exported);
      expect(envelope.keys, containsAll(['spec', 'spec_version', 'data']));
      expect(canonicalEquals(envelope['data'], data), isTrue);
    });
  });

  group('decodeJson（JSONB 列取值归一化）', () {
    // 回归：详情路由曾对 jsonb 列先 toString() 再解析，而驱动返回的已是 Map，
    // Dart 风格字符串（键无引号）导致 jsonDecode 失败 → 世界书被静默置空。
    test('驱动返回 Map 时原样透传，不做字符串化', () {
      final book = {
        'entries': [
          {
            'id': 0,
            'name': 'Triple A',
            'keys': <dynamic>['tavern'],
          },
        ],
      };
      final decoded = CharacterCardMapper.decodeJson<Map<String, dynamic>>(
        book,
        const {},
      );
      expect(decoded['entries'], hasLength(1));
      final entries = decoded['entries']! as List<Map<String, dynamic>>;
      expect(entries.first['name'], 'Triple A');
    });

    test('驱动返回 JSON 字符串时正常解析', () {
      const raw =
          '{"entries": [{"id": 0, "name": "Triple A", "keys": ["tavern"]}]}';
      final decoded = CharacterCardMapper.decodeJson<Map<String, dynamic>>(
        raw,
        const {},
      );
      expect(decoded['entries'], hasLength(1));
    });

    test('空值与不可解析值回退到默认值', () {
      expect(
        CharacterCardMapper.decodeJson<Map<String, dynamic>>(null, const {}),
        isEmpty,
      );
      expect(
        CharacterCardMapper.decodeJson<List<dynamic>>('', const []),
        isEmpty,
      );
      expect(
        CharacterCardMapper.decodeJson<Map<String, dynamic>>('not json', const {
          'fallback': true,
        }),
        {'fallback': true},
      );
    });
  });
}

/// 键序无关的 deep 相等判定
bool canonicalEquals(Object? a, Object? b) =>
    CharacterCardMapper.canonicalJson(a) ==
    CharacterCardMapper.canonicalJson(b);

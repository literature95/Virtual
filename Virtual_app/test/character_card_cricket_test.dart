import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/models/character.dart';
import 'package:virtual/models/lorebook.dart';
import 'package:virtual/services/character_export_service.dart';
import 'package:virtual/services/character_import_service.dart';
import 'package:virtual/services/online_character_service.dart';

import 'fixtures/cricket_card.dart';

/// 真实角色卡回归测试
///
/// fixture 为 chub.ai @cutenotlewd 的 Cricket（Character Card v2），
/// 覆盖本项目此前会**静默丢失**的三处关键数据：
///   1. `mes_example` —— 说话人前缀是角色名而非 `{{char}}`，旧解析器全部丢弃
///   2. `character_book` —— 世界书完全没有实现，地点/货币/债务设定丢失
///   3. `extensions.depth_prompt` —— 键名为 snake_case，Prompt 层读 camelCase
void main() {
  final service = CharacterImportService(Dio());
  final card = jsonDecode(cricketCardJson) as Map<String, dynamic>;

  group('真实卡片 Cricket（CCv2）导入', () {
    test('基础字段与元数据完整', () {
      final bundle = service.importBundleFromJson(card);

      expect(bundle.sourceFormat, 'Character Card v2.0');
      expect(bundle.character.name, 'Cricket');
      expect(bundle.character.creator, 'cutenotlewd');
      expect(bundle.character.characterVersion, 'main');
      expect(bundle.character.tags, contains('Comedy'));
      expect(bundle.character.tags, hasLength(7));
      expect(bundle.character.alternateGreetings, hasLength(2));
      expect(bundle.character.avatarPath, startsWith('https://'));

      // 高密度人设是角色的核心资产，不能被截断
      expect(bundle.character.description!.length, greaterThan(3000));
      expect(bundle.character.firstMessage!.length, greaterThan(1000));
    });

    test('mes_example 说话人前缀为角色名时不再丢失（旧实现返回空字符串）', () {
      final bundle = service.importBundleFromJson(card);
      final examples = bundle.character.exampleMessages;

      // 该卡不含 <START>，用 `1.` `2.` 分隔两组示例
      expect(examples, hasLength(2));

      final first = examples[0];
      // 说话人前缀被剥离，只保留台词本体
      expect(first.userMessage,
          contains('Good evening! Are you the owner of this fine establishment?'));
      expect(first.assistantMessage, contains('Uh-huh! Yep! Hi!'));
      expect(first.assistantMessage, contains('Are, uh, you here for a quest?'));
      expect(first.assistantMessage, contains('He looks pissed'));

      final second = examples[1];
      expect(second.userMessage, contains('do you have a team ready'));
      expect(second.assistantMessage, contains('talented folks'));
      expect(second.assistantMessage,
          contains("There they are now! I'll get 'em right away!"));
    });

    test('character_book 导入为 Lorebook 且字段对齐', () {
      final bundle = service.importBundleFromJson(card);

      expect(bundle.hasLorebook, isTrue);
      final book = bundle.lorebook!;
      expect(book.name, 'Setting / RPG info');
      expect(book.scanDepth, 40);
      expect(book.tokenBudget, 500);
      expect(book.recursiveScanning, isFalse);
      expect(book.entries, hasLength(2));

      final agency = book.entries.firstWhere((e) => e.key == 'AAA');
      expect(agency.keys, hasLength(12));
      expect(agency.keys, contains('Triple A'));
      expect(agency.content, contains('Triple A Adventuring Agency'));
      expect(agency.enabled, isTrue);
      expect(agency.priority, 10);
      expect(agency.probability, 100);
      expect(agency.selective, isFalse);
      expect(agency.constant, isFalse);
      expect(agency.depth, 4); // 来自 extensions.depth
      expect(agency.order, 1); // insertion_order
      expect(agency.position, LorebookEntryPosition.afterSystem); // after_char

      final money = book.entries.firstWhere((e) => e.key == 'money');
      expect(money.content, contains('5000gp debt'));
    });

    test('extensions 归一化：depth_prompt 提升为 camelCase，并保留 chub 来源', () {
      final bundle = service.importBundleFromJson(card);
      final exts = bundle.character.extensions;

      // 原始结构仍需完整保留（不可破坏性）
      expect(exts['chub'], isA<Map>());
      expect(exts['depth_prompt'], isA<Map>());
      expect(exts['depth_prompt']['depth'], 40);
      // 归一化后的键供 Prompt 组装层读取
      expect(exts['depth'], 40);
      expect(exts['sourceUrl'], contains('cutenotlewd/cricket-674c71b2'));
    });

    test('导入摘要可读（UI SnackBar 使用）', () {
      final bundle = service.importBundleFromJson(card);
      expect(bundle.summary, contains('示例对话 2 条'));
      expect(bundle.summary, contains('世界书 2 条'));
      expect(bundle.warnings, isEmpty);
    });
  });

  group('mes_example 解析器边界', () {
    test('{{user}}/{{char}} 宏前缀（旧支持的写法不回归）', () {
      final examples = Character.parseMesExample(
        '<START>\n{{user}}: hi\n{{char}}: hello\n',
        charName: 'Cricket',
      );
      expect(examples, hasLength(1));
      expect(examples.first.userMessage, 'hi');
      expect(examples.first.assistantMessage, 'hello');
    });

    test('未知第三方名字归入 user 侧', () {
      final examples = Character.parseMesExample(
        'Stranger: who goes there?\nCricket: uh, hi!\n',
        charName: 'Cricket',
      );
      expect(examples, hasLength(1));
      expect(examples.first.userMessage, 'who goes there?');
      expect(examples.first.assistantMessage, 'uh, hi!');
    });

    test('角色独白：无 user 侧时仍保留 assistant 内容', () {
      final examples = Character.parseMesExample(
        'Cricket: *she sighs* Another dead day.\n',
        charName: 'Cricket',
      );
      expect(examples, hasLength(1));
      expect(examples.first.userMessage, isEmpty);
      expect(examples.first.assistantMessage, contains('Another dead day'));
    });

    test('叙述性星号行不会被误判为说话人', () {
      final examples = Character.parseMesExample(
        '{{user}}: hi\nCricket: sure\n*Cricket thinks: maybe not*\n',
        charName: 'Cricket',
      );
      expect(examples, hasLength(1));
      expect(examples.first.assistantMessage, contains('sure'));
      expect(examples.first.assistantMessage, contains('maybe not'));
    });

    test('空输入与空块不产生空记录', () {
      expect(Character.parseMesExample(null), isEmpty);
      expect(Character.parseMesExample(''), isEmpty);
      expect(Character.parseMesExample('   \n\n  '), isEmpty);
    });
  });

  group('后端完整角色卡 → 本地 Character（OnlineCharacter 契约）', () {
    // 取自 GET /api/characters/char-001 的真实响应结构（camelCase）
    final apiPayload = <String, dynamic>{
      'id': 'char-001',
      'name': '晓夜',
      'nickname': '小夜',
      'description': '姓名：晓夜\n年龄：24\n身份：夜班店员',
      'personality': '温柔、克制、细心到有点过度。',
      'scenario': '深夜的城市边缘，「夜灯」便利店亮着白光。',
      'avatarUrl': 'http://192.168.1.9:8080/avatars/char-001.jpg',
      'tags': ['治愈', '日常'],
      'greeting': '欢迎光临~',
      'firstMessage': '叮铃——自动门的提示音响起来。',
      'creator': 'Virtual',
      'characterVersion': '1.0',
      'source': 'Virtual seed',
      'alternateGreetings': ['今天也很晚呢。'],
      'groupOnlyGreetings': [],
      'exampleMessages': [
        {
          'userMessage': '你每天晚上都一个人在这儿，不害怕吗？',
          'assistantMessage': '怕的。*她说得很干脆。*',
        },
      ],
      'extensions': {},
      'creatorNotesMultilingual': {},
    };

    test('完整字段全部映射到 Character，无静默丢失', () {
      final online = OnlineCharacter.fromJson(apiPayload);
      expect(online.isFullCard, isTrue);
      expect(online.exampleMessages, hasLength(1));

      final c = online.toCharacter();
      expect(c.id, 'char-001');
      expect(c.nickname, '小夜');
      expect(c.personality, contains('温柔'));
      expect(c.scenario, contains('便利店'));
      expect(c.firstMessage, contains('叮铃'));
      expect(c.avatarPath, startsWith('http://'));
      expect(c.alternateGreetings, hasLength(1));
      expect(c.exampleMessages.first.userMessage, contains('不害怕吗'));
      expect(c.exampleMessages.first.assistantMessage, contains('怕的'));
      expect(c.creator, 'Virtual');
      expect(c.characterVersion, '1.0');
    });

    test('列表精简条目（缺完整字段）不报错且降级为空', () {
      final summary = OnlineCharacter.fromJson({
        'id': 'char-002',
        'name': '星尘',
        'description': '来自天琴座。',
        'avatarUrl': 'http://x/avatars/char-002.jpg',
        'tags': ['科幻'],
        'greeting': '你好，碳基生命！',
        'persona': '星际探索者',
      });
      expect(summary.isFullCard, isFalse);
      expect(summary.exampleMessages, isEmpty);
      // firstMessage 缺失时回落 greeting，保留旧行为
      expect(summary.toCharacter().firstMessage, '你好，碳基生命！');
    });
  });

  group('导出回环（import → export → import）', () {
    test('CCv3 导出后再导入，关键内容保持一致', () {
      final bundle = service.importBundleFromJson(card);
      final exported = CharacterExportService().toCCv3(
        bundle.character,
        lorebook: bundle.lorebook,
      );

      expect(exported['spec'], 'chara_card_v3');
      final data = exported['data'] as Map<String, dynamic>;
      expect(data['name'], 'Cricket');
      expect(data['creator'], 'cutenotlewd');
      expect(data['alternate_greetings'], hasLength(2));
      expect(data['character_book'], isA<Map>());

      final roundTrip = service.importBundleFromJson(exported);
      expect(roundTrip.character.name, 'Cricket');
      // 示例对话经渲染后按 <START> 分组，条数不减
      expect(
        roundTrip.character.exampleMessages.length,
        greaterThanOrEqualTo(bundle.character.exampleMessages.length),
      );
      expect(roundTrip.hasLorebook, isTrue);
      expect(roundTrip.lorebook!.entries, hasLength(2));

      // 世界书内容与位置映射保持稳定
      final agency = roundTrip.lorebook!.entries.firstWhere((e) => e.key == 'AAA');
      expect(agency.content, contains('Triple A Adventuring Agency'));
      expect(agency.keys, contains('Triple A'));
    });
  });
}

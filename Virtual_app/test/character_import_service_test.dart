import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/services/character_import_service.dart';

/// 极简 Dio adapter：捕获请求路径并返回预设 JSON，用于离线测试 URL 改写逻辑。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.data, {this.onPath});

  final dynamic data;
  final void Function(Uri uri)? onPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onPath?.call(options.uri);
    final body = data is String ? data : jsonEncode(data);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CharacterImportService.importFromJson', () {
    final service = CharacterImportService(Dio());

    test('CCv3 完整字段解析（含 mes_example / system_prompt / 备用问候）', () {
      final card = {
        'spec': 'chara_card_v3',
        'data': {
          'name': 'Cricket',
          'description': 'Founding owner of the Triple A Adventuring Agency.',
          'personality': 'A cheerful, chaotic professional fuck-up.',
          'scenario': 'User is a client of the adventuring agency.',
          'first_mes': 'Hey! Welcome to Triple A.',
          'mes_example': '<START>\n{{user}}: hi\n{{char}}: hello there!\n',
          'system_prompt': 'Stay in character. Comedy, fantasy.',
          'post_history_instructions': 'Do not break character.',
          'alternate_greetings': ['yo', 'hey there'],
          'group_only_greetings': ['hi everyone'],
          'creator_notes_multilingual': {'zh_CN': '创作者备注'},
          'tags': ['Fantasy', 'Comedy'],
          'creator': 'cutenotlewd',
        },
      };

      final c = service.importFromJson(card);

      expect(c.name, 'Cricket');
      expect(c.personality, contains('cheerful'));
      expect(c.scenario, isNotEmpty);
      expect(c.systemPrompt, 'Stay in character. Comedy, fantasy.');
      expect(c.postHistoryInstructions, 'Do not break character.');
      expect(c.alternateGreetings, ['yo', 'hey there']);
      expect(c.groupOnlyGreetings, ['hi everyone']);
      expect(c.creatorNotesMultilingual, {'zh_CN': '创作者备注'});
      expect(c.tags, ['Fantasy', 'Comedy']);
      expect(c.creator, 'cutenotlewd');
      // 关键：示例对话不再丢失
      expect(c.exampleMessages, hasLength(1));
      expect(c.exampleMessages.first.userMessage, 'hi');
      expect(c.exampleMessages.first.assistantMessage, 'hello there!');
    });

    test('SillyTavern 直接格式（无 spec 包裹）同样补全字段', () {
      final card = {
        'name': 'X',
        'mes_example': '<START>\n{{user}}: a\n{{char}}: b\n',
        'alternate_greetings': ['g1'],
      };

      final c = service.importFromJson(card);

      expect(c.name, 'X');
      expect(c.alternateGreetings, ['g1']);
      expect(c.exampleMessages, hasLength(1));
    });
  });

  group('CharacterImportService.importFromUrl（chub.ai）', () {
    test('chub.ai 网页链接给出可操作的引导错误（公开下载 API 已废弃）', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter({'name': 'Cricket'});
      final service = CharacterImportService(dio);

      expect(
        () => service.importFromUrl(
          'https://chub.ai/characters/cutenotlewd/cricket-674c71b2',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('从文件导入'),
        )),
      );
    });

    test('非 chub.ai 直链原样透传', () async {
      final dio = Dio();
      Uri? requested;
      dio.httpClientAdapter = _FakeAdapter(
        {'name': 'Plain'},
        onPath: (u) => requested = u,
      );
      final service = CharacterImportService(dio);

      final c = await service.importFromUrl('https://example.com/card.json');

      expect(requested.toString(), 'https://example.com/card.json');
      expect(c.name, 'Plain');
    });
  });
}

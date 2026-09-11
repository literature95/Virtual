import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:virtual/services/character_export_service.dart';
import 'package:virtual/services/character_import_service.dart';
import 'package:virtual/utils/png_card_extractor.dart';
import 'package:virtual/utils/png_card_writer.dart';

import 'fixtures/cricket_card.dart';

/// PNG 角色卡**写入**侧的回归基线
///
/// 与 `character_png_import_test.dart` 配对：那边验证"读得进来"，这边
/// 验证"写得出去、且能被读回来"。往返闭环是关键 —— 解析侧曾经的缺陷
/// （整包跑正则、base64 未解码）正是因为读写各写一套、互不校验才长期潜伏。
void main() {
  final exportService = CharacterExportService();

  test('写出的 PNG 能被自身解析器读回（往返闭环）', () {
    final bytes = buildCardPng(cricketCardJson);

    expect(hasPngSignature(bytes), isTrue, reason: '应产出合法 PNG');

    final payload = extractPngCard(bytes);
    expect(payload, isNotNull, reason: '解析器必须能读回自己写入的块');
    expect(
      cardChunkKeywords,
      contains(payload!.keyword),
      reason: '关键字应是 chara / ccv3 之一',
    );

    final bundle = CharacterImportService(Dio())
        .importBundleFromJsonText(payload.json);
    expect(bundle.character.name, 'Cricket');
    expect(bundle.lorebook?.entries.length, 2, reason: '世界书不得丢失');
  });

  test('真实卡片：导入 → 导出 PNG → 再导入，核心字段全等', () async {
    final importService = CharacterImportService(Dio());
    final source = importService.importBundleFromJson(
      jsonDecode(cricketCardJson) as Map<String, dynamic>,
    );

    // 显式传底图：夹具的 avatar 是 https 外链，不应让单元测试走网络
    final bytes = await exportService.exportPngBytes(
      source.character,
      lorebook: source.lorebook,
      baseImage: buildPlaceholderPng(),
    );

    final back = importService.importBundleFromBytes(
      bytes,
      sourceName: 'roundtrip.png',
    );

    // 契约是**语义级全等**：导出时 `_dropNulls` 会剥掉空字符串，
    // 因此「空串」与「缺字段」在本项目中等价，不作为往返差异。
    // 这一点必须显式写出，否则测试会退化成"只要不抛异常就算过"。
    String n(String? v) => v ?? '';

    expect(back.character.name, source.character.name);
    expect(n(back.character.description), n(source.character.description));
    expect(n(back.character.personality), n(source.character.personality));
    expect(n(back.character.scenario), n(source.character.scenario));
    expect(n(back.character.firstMessage), n(source.character.firstMessage));
    expect(n(back.character.systemPrompt), n(source.character.systemPrompt));
    expect(
      n(back.character.postHistoryInstructions),
      n(source.character.postHistoryInstructions),
    );
    expect(n(back.character.creator), n(source.character.creator));
    expect(
      n(back.character.characterVersion),
      n(source.character.characterVersion),
    );
    expect(back.character.tags, source.character.tags);
    expect(
      back.character.alternateGreetings,
      source.character.alternateGreetings,
    );
    expect(
      back.character.groupOnlyGreetings,
      source.character.groupOnlyGreetings,
    );

    // 示例对话逐条比对：只比数量会漏掉"示例被截断/错位"这类问题
    final srcEx = source.character.exampleMessages;
    final backEx = back.character.exampleMessages;
    expect(backEx.length, srcEx.length, reason: '示例对话是最易在往返中丢失的字段');
    for (var i = 0; i < srcEx.length; i++) {
      expect(n(backEx[i].userMessage), n(srcEx[i].userMessage), reason: '示例 $i 用户侧');
      expect(
        n(backEx[i].assistantMessage),
        n(srcEx[i].assistantMessage),
        reason: '示例 $i 角色侧',
      );
    }

    // 世界书逐条比对
    final srcEntries = source.lorebook?.entries ?? const [];
    final backEntries = back.lorebook?.entries ?? const [];
    expect(backEntries.length, srcEntries.length);
    for (var i = 0; i < srcEntries.length; i++) {
      expect(backEntries[i].matchKeys, srcEntries[i].matchKeys, reason: '条目 $i 关键词');
      expect(backEntries[i].content, srcEntries[i].content, reason: '条目 $i 内容');
      expect(backEntries[i].position, srcEntries[i].position, reason: '条目 $i 位置');
      expect(backEntries[i].enabled, srcEntries[i].enabled, reason: '条目 $i 启用态');
    }
  });

  test('底图可以是 JPEG（内部统一转 PNG）', () {
    final jpeg = img.encodeJpg(img.Image(width: 16, height: 24));
    final bytes = buildCardPng(cricketCardJson, baseImage: jpeg);

    expect(hasPngSignature(bytes), isTrue);
    expect(extractPngCard(bytes), isNotNull);
  });

  test('底图无法解码时抛可读错误，而不是静默产出坏图', () {
    final garbage = Uint8List.fromList(List<int>.filled(64, 0x00));
    expect(
      () => buildCardPng(cricketCardJson, baseImage: garbage),
      throwsA(isA<FormatException>()),
    );
  });

  test('占位图本身不含卡片数据（不应被误认为角色卡）', () {
    final placeholder = buildPlaceholderPng();
    expect(hasPngSignature(placeholder), isTrue);
    expect(extractPngCard(placeholder), isNull);
    expect(
      () => CharacterImportService(Dio())
          .importBundleFromBytes(placeholder, sourceName: 'art.png'),
      throwsA(isA<Exception>()),
    );
  });

  test('内嵌 data URL 头像被剥离，避免卡片体积翻倍', () async {
    final importService = CharacterImportService(Dio());
    final source = importService.importBundleFromJson(
      jsonDecode(cricketCardJson) as Map<String, dynamic>,
    );
    // 模拟"从 PNG 导入"后 avatarPath 为 data URL 的情形
    final withInline = source.character.copyWith(
      avatarPath:
          'data:image/png;base64,${base64Encode(buildPlaceholderPng())}',
    );

    final bytes = await exportService.exportPngBytes(
      withInline,
      baseImage: buildPlaceholderPng(),
    );

    final payload = extractPngCard(bytes)!;
    final card = jsonDecode(payload.json) as Map<String, dynamic>;
    expect((card['data'] as Map)['avatar'], 'none');
  });

  test('文件名去掉路径分隔符与 Windows 保留字符', () {
    final importService = CharacterImportService(Dio());
    final c = importService
        .importBundleFromJson(
          jsonDecode(cricketCardJson) as Map<String, dynamic>,
        )
        .character
        .copyWith(name: r'a/b:c*d?e"f<g>h|i');

    final name = exportService.pngFileName(c);
    expect(name.endsWith('.png'), isTrue);
    expect(RegExp(r'[\\/:*?"<>|]').hasMatch(name.substring(0, name.length - 4)),
        isFalse);
  });
}

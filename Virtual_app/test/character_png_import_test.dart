import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/services/character_import_service.dart';
import 'package:virtual/utils/png_card_extractor.dart';

import 'fixtures/cricket_card.dart';
import 'support/png_builder.dart';

/// 由 **Python `zlib.compress(..., 9)`** 产生的压缩流，解压后为
/// `{"spec":"chara_card_v2","data":{"name":"Python zlib probe"}}`。
///
/// 存在的意义：Web 端走 archive 的纯 Dart inflate，而真实卡片由第三方工具
/// （多为 Python / JS 的 zlib）压缩。这组字节固化下来，即可在 CI 里验证
/// **纯 Dart inflate 能解开外部实现产生的流**，而不只是自家 encoder 的自洽。
const List<int> _pythonZlibPayload = [
  0x78, 0xDA, 0xAB, 0x56, 0x2A, 0x2E, 0x48, 0x4D, 0x56, 0xB2, 0x52, 0x4A,
  0xCE, 0x48, 0x2C, 0x4A, 0x8C, 0x4F, 0x4E, 0x2C, 0x4A, 0x89, 0x2F, 0x33,
  0x52, 0xD2, 0x51, 0x4A, 0x49, 0x2C, 0x49, 0x54, 0xB2, 0xAA, 0x56, 0xCA,
  0x4B, 0xCC, 0x4D, 0x05, 0x4A, 0x07, 0x54, 0x96, 0x64, 0xE4, 0xE7, 0x29,
  0x54, 0xE5, 0x64, 0x26, 0x29, 0x14, 0x14, 0xE5, 0x27, 0xA5, 0x2A, 0xD5,
  0xD6, 0x02, 0x00, 0x66, 0xB7, 0x14, 0x8F,
];

/// PNG 容器导入的回归基线
///
/// 这些用例锁定的是一个曾经**完全失效**的路径：旧实现把整个 PNG 当作字符串
/// 跑正则，而 CCv2/v3 规范要求文本块值是 base64(UTF-8 JSON)，base64 字母表
/// 不含花括号，因此正则恒零匹配 —— 任何真实导出的角色卡 PNG 都导不进来。
void main() {
  final service = CharacterImportService(Dio());

  /// 真实卡片的最小等价体：顶层扁平字段 + spec + data（对齐 chub.ai 导出形态）
  const hybridCard = '''
{
  "name": "希露妲",
  "first_mes": "",
  "spec": "chara_card_v3",
  "spec_version": "3.0",
  "creatorcomment": "",
  "data": {
    "name": "希露妲",
    "description": "{\\"chineseName\\": \\"希露妲\\", \\"age\\": 26}",
    "personality": "",
    "scenario": "",
    "first_mes": "",
    "mes_example": "1.\\nUser: 你好\\n希露妲: 你好。\\n\\n2.\\nUser: 再见\\n希露妲: 再见。",
    "tags": ["无期迷途"],
    "creator": "tester",
    "character_version": "1.0",
    "alternate_greetings": [],
    "extensions": {"talkativeness": "0.5", "depth_prompt": {"prompt": "保持希露妲的语气", "depth": 4}},
    "group_only_greetings": []
  }
}''';

  group('extractPngCard（编解码层）', () {
    test('空字节与不足 8 字节的内容返回 null，不抛异常', () {
      expect(extractPngCard(Uint8List(0)), isNull);
      expect(extractPngCard(Uint8List.fromList([0x89, 0x50])), isNull);
    });

    test('签名不符的内容返回 null', () {
      final notPng = Uint8List.fromList(utf8.encode('{"name":"x"}'));
      expect(extractPngCard(notPng), isNull);
    });

    test('没有文本块的合法 PNG 返回 null', () {
      expect(extractPngCard(buildPng(const [])), isNull);
    });

    test('关键字不属于角色卡集合时返回 null', () {
      final png = buildPng([PngTextBlock.base64('Comment', cricketCardJson)]);
      expect(extractPngCard(png), isNull);
    });

    test('zTXt 块经解压后命中，chunkType 如实回报', () {
      final png = buildPng([PngTextBlock.zlibBase64('chara', cricketCardJson)]);
      final hit = extractPngCard(png);

      expect(hit, isNotNull);
      expect(hit!.chunkType, 'zTXt');
      expect(hit.keyword, 'chara');
    });

    test('块长度越界（文件截断）时安全返回 null，不越界读取', () {
      final png = buildPng(
        [PngTextBlock.base64('chara', cricketCardJson)],
        truncateLastChunk: true,
      );
      expect(extractPngCard(png), isNull);
    });

    group('Web 端纯 Dart inflate 路径（CI 在 VM 上强制覆盖）', () {
      test('ZLibDecoderWeb 能解开 Python zlib 产生的流（跨实现兼容）', () {
        const expected =
            '{"spec":"chara_card_v2","data":{"name":"Python zlib probe"}}';
        final out = const ZLibDecoderWeb().decodeBytes(_pythonZlibPayload);

        expect(utf8.decode(out), expected);
      });

      test('强制走纯 Dart inflate 时，zTXt 块仍可完整解析', () {
        final png = buildPng([PngTextBlock.zlibBase64('chara', cricketCardJson)]);
        final hit = extractPngCard(
          png,
          zlibInflate: (b) => const ZLibDecoderWeb().decodeBytes(b),
        );

        expect(hit, isNotNull);
        expect(hit!.chunkType, 'zTXt');
        expect(hit.json, contains('Cricket'));
      });

      test('纯 Dart inflate 遇到损坏流时返回 null 而非抛出', () {
        final png = buildPng([PngTextBlock.corruptZlib('chara')]);
        expect(
          extractPngCard(
            png,
            zlibInflate: (b) => const ZLibDecoderWeb().decodeBytes(b),
          ),
          isNull,
        );
      });
    });
  });

  group('importBundleFromBytes · PNG 规范形态', () {
    test('chara 块 + base64 → 完整导入（含世界书与示例对话）', () {
      final png = buildPng([PngTextBlock.base64('chara', cricketCardJson)]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'cricket.png');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.lorebook, isNotNull);
      expect(bundle.lorebook!.entries.length, 2, reason: '世界书不得丢失');
      expect(bundle.character.exampleMessages.length, 2);
      expect(bundle.character.alternateGreetings.length, 2);
      expect(bundle.sourceFormat, contains('PNG(chara)'));
    });

    test('ccv3 块 + base64 → 同样导入成功', () {
      final png = buildPng([PngTextBlock.base64('ccv3', cricketCardJson)]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'cricket.png');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.sourceFormat, contains('PNG(ccv3)'));
    });

    test('base64 缺少 "=" 填充（真实导出常见）仍可解析', () {
      final png = buildPng([
        PngTextBlock.base64('chara', cricketCardJson, padToMultipleOfFour: false),
      ]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'cricket.png');

      expect(bundle.character.name, 'Cricket');
    });

    test('iTXt 块（未压缩）可解析', () {
      final png = buildPng([
        PngTextBlock.base64('chara', cricketCardJson, isITxt: true),
      ]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'cricket.png');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.sourceFormat, contains('PNG(chara)'));
    });

    test('关键字大小写混合（Chara）可解析', () {
      final png = buildPng([PngTextBlock.base64('Chara', cricketCardJson)]);
      expect(service.importBundleFromBytes(png).character.name, 'Cricket');
    });

    test('chara 与 ccv3 并存的真实形态命中 chara', () {
      final png = buildPng([
        PngTextBlock.base64('chara', cricketCardJson),
        PngTextBlock.base64('ccv3', cricketCardJson),
      ]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'cricket.png');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.sourceFormat, contains('PNG(chara)'));
    });

    test('iTXt 压缩形态（compressionFlag=1）解压后可解析', () {
      final png = buildPng([
        PngTextBlock.base64(
          'chara',
          cricketCardJson,
          isITxt: true,
          compressionFlag: true,
        ),
      ]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'compressed.png');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.lorebook!.entries.length, 2, reason: '解压后不得丢世界书');
      expect(bundle.sourceFormat, contains('PNG(chara)'));
    });

    test('zTXt 块（zlib 压缩的 base64）可解析', () {
      final png = buildPng([
        PngTextBlock.zlibBase64('chara', cricketCardJson),
      ]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'cricket.png');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.character.exampleMessages.length, 2);
      expect(bundle.lorebook!.entries.length, 2);
      expect(bundle.sourceFormat, contains('PNG(chara)'));
    });

    test('zTXt 块（zlib 压缩的原始 JSON）同样兼容', () {
      final png = buildPng([PngTextBlock.zlibRaw('ccv3', cricketCardJson)]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'cricket.png');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.sourceFormat, contains('PNG(ccv3)'));
    });

    test('zTXt 压缩流损坏时安全跳过，不抛异常', () {
      final png = buildPng([
        PngTextBlock.corruptZlib('chara'),
        PngTextBlock.base64('chara', cricketCardJson),
      ]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'cricket.png');

      expect(bundle.character.name, 'Cricket', reason: '应回退到未损坏的 tEXt 块');
    });

    test('chara(V2) 与 ccv3(V3) 并存且内容不同时，取 spec 更高的一份', () {
      const v2Copy = '{"spec":"chara_card_v2","spec_version":"2.0",'
          '"data":{"name":"V2 兼容副本","description":"v2","mes_example":""}}';
      const v3Full = '{"spec":"chara_card_v3","spec_version":"3.0",'
          '"data":{"name":"V3 完整卡","description":"v3","mes_example":""}}';

      final ccv3First = buildPng([
        PngTextBlock.base64('ccv3', v3Full),
        PngTextBlock.base64('chara', v2Copy),
      ]);
      expect(service.importBundleFromBytes(ccv3First).character.name, 'V3 完整卡');

      // 顺序颠倒结论一致 —— 判据是 spec 版本，不是文档顺序
      final charaFirst = buildPng([
        PngTextBlock.base64('chara', v2Copy),
        PngTextBlock.base64('ccv3', v3Full),
      ]);
      final bundle = service.importBundleFromBytes(charaFirst, sourceName: 'x.png');
      expect(bundle.character.name, 'V3 完整卡');
      expect(bundle.sourceFormat, contains('PNG(ccv3)'));
    });
  });

  group('importBundleFromBytes · 兼容形态', () {
    test('非规范 PNG：块内直写 JSON', () {
      final png = buildPng([PngTextBlock.raw('chara', cricketCardJson)]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'raw.png');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.lorebook!.entries.length, 2);
    });

    test('非规范 PNG + 中文内容：不得退化成 latin1 乱码', () {
      final png = buildPng([PngTextBlock.raw('chara', hybridCard)]);
      final bundle = service.importBundleFromBytes(png, sourceName: 'zh.png');

      expect(bundle.character.name, '希露妲');
      expect(bundle.character.description, contains('希露妲'));
      expect(bundle.character.description, isNot(contains('å')));
    });

    test('裸 JSON 字节（无 PNG 容器）', () {
      final bytes = Uint8List.fromList(utf8.encode(cricketCardJson));
      final bundle = service.importBundleFromBytes(bytes, sourceName: 'card.json');

      expect(bundle.character.name, 'Cricket');
      expect(bundle.lorebook!.entries.length, 2);
    });

    test('带 BOM 的 JSON 文本', () {
      final bytes = Uint8List.fromList(
        utf8.encode('\uFEFF$cricketCardJson'),
      );
      expect(service.importBundleFromBytes(bytes).character.name, 'Cricket');
    });

    test('顶层扁平 + spec + data 的混合形态取 data 节点', () {
      final bytes = Uint8List.fromList(utf8.encode(hybridCard));
      final bundle = service.importBundleFromBytes(bytes, sourceName: 'hybrid.json');

      expect(bundle.character.name, '希露妲');
      expect(bundle.character.creator, 'tester');
      expect(bundle.character.tags, ['无期迷途']);
      expect(bundle.character.exampleMessages.length, 2);
      expect(
        bundle.character.extensions['depthPrompt'],
        '保持希露妲的语气',
        reason: 'depth_prompt.prompt 应被归一到 depthPrompt',
      );
      expect(bundle.character.extensions['depth'], 4);
      expect(bundle.character.description, contains('chineseName'));
    });

    test('既不是 PNG 也没有角色卡数据时给出可读错误', () {
      final bytes = Uint8List.fromList(List<int>.filled(64, 0x41));
      expect(
        () => service.importBundleFromBytes(bytes, sourceName: 'photo.jpg'),
        throwsA(
          predicate<Exception>(
            (e) => e.toString().contains('photo.jpg'),
            '错误信息应包含来源文件名',
          ),
        ),
      );
    });

    test('是 PNG 但不含文本块（纯插画）时，错误提示点明"不是角色卡"', () {
      final png = buildPng(const []);
      expect(
        () => service.importBundleFromBytes(png, sourceName: '插画.png'),
        throwsA(
          predicate<Exception>(
            (e) =>
                e.toString().contains('插画.png') &&
                e.toString().contains('不含角色卡数据'),
            '应区别于"选错格式"，明确告知这是一张没有卡片数据的图片',
          ),
        ),
      );
    });
  });
}

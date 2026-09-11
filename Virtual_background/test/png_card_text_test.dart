import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:virtual_background/png_card_text.dart';

/// 后端 PNG 卡内文本块提取器回归测试。
///
/// 与 App 端 `png_card_extractor_test.dart` 覆盖**同一批语义**（base64 补填充、
/// UTF-8 优先于 latin1、多块取 spec 高者），因为后端是独立实现 —— 两处都必须
/// 挡住「静默乱码入库」与「V3 独有字段丢失」这两类无声的数据损坏。
void main() {
  const v3Json =
      '{"spec":"chara_card_v3","spec_version":"3.0","data":{"name":"希露妲",'
      '"description":"无期迷途","nickname":"露"}}';
  const v2Json =
      '{"spec":"chara_card_v2","spec_version":"2.0","data":{"name":"希露妲",'
      '"description":"旧副本"}}';

  group('容器形态：tEXt / zTXt / iTXt', () {
    test('tEXt + base64(UTF-8 JSON)：解出且中文不乱码', () {
      final png = _png([_tEXt('chara', base64Encode(utf8.encode(v3Json)))]);
      final payload = extractPngCard(png);
      expect(payload, isNotNull);
      expect(payload!.keyword, 'chara');
      expect(payload.chunkType, 'tEXt');
      final obj = jsonDecode(payload.json) as Map<String, dynamic>;
      expect((obj['data'] as Map)['name'], '希露妲');
      expect((obj['data'] as Map)['nickname'], '露');
    });

    test('base64 省略 = 填充（真实导出工具的常见写法）仍能解出', () {
      final encoded = base64Encode(utf8.encode(v3Json));
      final withoutPadding = encoded.replaceAll('=', '');
      expect(withoutPadding.contains('='), isFalse);

      final png = _png([_tEXt('chara', withoutPadding)]);
      final payload = extractPngCard(png);
      expect(payload, isNotNull);
      expect(payload!.json, v3Json);
    });

    test('非规范：块内直接就是 JSON 文本也能解出', () {
      final png = _png([_tEXt('chara', v3Json)]);
      expect(extractPngCard(png)!.json, v3Json);
    });

    test('zTXt（zlib 压缩）能解出', () {
      final png = _png([_zTXt('chara', base64Encode(utf8.encode(v3Json)))]);
      final payload = extractPngCard(png);
      expect(payload, isNotNull);
      expect(payload!.chunkType, 'zTXt');
      expect(payload.json, v3Json);
    });

    test('iTXt 压缩与非压缩两种都能解出', () {
      final compressed = _png([
        _iTXt('ccv3', base64Encode(utf8.encode(v3Json)), compressed: true),
      ]);
      final plain = _png([
        _iTXt('ccv3', base64Encode(utf8.encode(v3Json)), compressed: false),
      ]);
      expect(extractPngCard(compressed)!.json, v3Json);
      expect(extractPngCard(plain)!.json, v3Json);
      expect(extractPngCard(plain)!.chunkType, 'iTXt');
    });

    test('zlib 流损坏时当作未找到，不抛异常', () {
      final png = _png([
        _chunk('zTXt', [...ascii.encode('chara'), 0, 0, 1, 2, 3, 4, 5, 6]),
      ]);
      expect(extractPngCard(png), isNull);
    });
  });

  group('多块命中：取 spec 版本高者，同版本取文档顺序前者', () {
    test('chara(v2) 在前、ccv3(v3) 在后 → 取 v3，避免丢 V3 独有字段', () {
      final png = _png([
        _tEXt('chara', base64Encode(utf8.encode(v2Json))),
        _tEXt('ccv3', base64Encode(utf8.encode(v3Json))),
      ]);
      final payload = extractPngCard(png)!;
      expect(payload.keyword, 'ccv3');
      final obj = jsonDecode(payload.json) as Map<String, dynamic>;
      expect(
        (obj['data'] as Map)['nickname'],
        '露',
        reason: 'v2 副本没有 nickname，取错就会静默丢字段',
      );
    });

    test('同为 v3 时取先出现的那块（文档顺序，不用不稳定的 sort）', () {
      const first = '{"spec":"chara_card_v3","data":{"name":"先"}}';
      const second = '{"spec":"chara_card_v3","data":{"name":"后"}}';
      final png = _png([
        _tEXt('chara', base64Encode(utf8.encode(first))),
        _tEXt('ccv3', base64Encode(utf8.encode(second))),
      ]);
      final obj =
          jsonDecode(extractPngCard(png)!.json) as Map<String, dynamic>;
      expect((obj['data'] as Map)['name'], '先');
    });

    test('无 spec 字段的裸字段卡记 0，不敌带 spec 的副本', () {
      const bare = '{"name":"裸卡","description":"x"}';
      final png = _png([
        _tEXt('chara', base64Encode(utf8.encode(bare))),
        _tEXt('ccv3', base64Encode(utf8.encode(v2Json))),
      ]);
      expect(extractPngCard(png)!.json, v2Json);
    });
  });

  group('返回 null 的边界', () {
    test('不是 PNG（签名不符）', () {
      expect(extractPngCard(Uint8List.fromList(utf8.encode('not a png'))), isNull);
    });

    test('普通插画：PNG 但无卡片关键字', () {
      final png = _png([_tEXt('Comment', 'hello')]);
      expect(hasPngSignature(png), isTrue);
      expect(extractPngCard(png), isNull);
    });

    test('块长度声称越界（文件截断）时不抛异常', () {
      final png = _png([_tEXt('chara', base64Encode(utf8.encode(v3Json)))]);
      final truncated = Uint8List.sublistView(png, 0, png.length ~/ 2);
      expect(() => extractPngCard(truncated), returnsNormally);
      expect(extractPngCard(truncated), isNull);
    });

    test('空文件 / 仅签名', () {
      expect(extractPngCard(Uint8List(0)), isNull);
      expect(extractPngCard(Uint8List.fromList(_signature)), isNull);
    });
  });

  group('编码护栏：UTF-8 必须优先于 latin1', () {
    test('中文人设按 latin1 逐字节映射也能得到「合法 JSON」，但会乱码', () {
      final payload = utf8.encode(v3Json);
      final asLatin1 = String.fromCharCodes(payload);
      // 前提：latin1 解释同样以 '{' 开头，所以 jsonDecode 不会报错 —— 这就是坑
      expect(asLatin1.startsWith('{'), isTrue);
      expect(asLatin1.contains('希露妲'), isFalse);
      // 正确解释下中文完整
      expect(utf8.decode(payload), contains('希露妲'));

      final png = _png([_tEXt('chara', base64Encode(payload))]);
      expect(extractPngCard(png)!.json, contains('希露妲'));
    });
  });
}

// ---------------------------------------------------------------------------
// 内存 PNG 夹具（不依赖磁盘与 CRC 校验 —— 提取器不校验 CRC）
// ---------------------------------------------------------------------------

const List<int> _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Uint8List _chunk(String type, List<int> data) {
  final len = ByteData(4)..setUint32(0, data.length);
  return Uint8List.fromList([
    ...len.buffer.asUint8List(),
    ...ascii.encode(type),
    ...data,
    0, 0, 0, 0, // CRC 占位
  ]);
}

Uint8List _png(List<Uint8List> chunks) => Uint8List.fromList([
      ..._signature,
      ..._chunk('IHDR', List<int>.filled(13, 0)),
      for (final c in chunks) ...c,
      ..._chunk('IEND', const []),
    ]);

/// tEXt：关键字 \0 值
///
/// 值按 **UTF-8** 写入 —— 非规范卡（块内直写 JSON）与部分导出工具都这样落盘；
/// 规范形态的 base64 载荷只含 ASCII，两种编码等价。
Uint8List _tEXt(String keyword, String value) =>
    _chunk('tEXt', [...ascii.encode(keyword), 0, ...utf8.encode(value)]);

/// zTXt：关键字 \0 压缩方式(0) zlib流
Uint8List _zTXt(String keyword, String value) => _chunk('zTXt', [
      ...ascii.encode(keyword),
      0,
      0,
      ...ZLibCodec().encode(utf8.encode(value)),
    ]);

/// iTXt：关键字 \0 标志位 方式 \0 langTag \0 translatedKeyword \0 值
Uint8List _iTXt(String keyword, String value, {required bool compressed}) {
  final body = <int>[
    ...ascii.encode(keyword),
    0,
    if (compressed) 1 else 0,
    0,
    0, // langTag 空
    0, // translatedKeyword 空
  ];
  if (compressed) {
    body.addAll(ZLibCodec().encode(utf8.encode(value)));
  } else {
    body.addAll(utf8.encode(value));
  }
  return _chunk('iTXt', body);
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 测试用 PNG 构造器
///
/// 只写入 IHDR + 若干文本块 + IDAT + IEND，产出一个**结构合法**的 PNG。
/// 这样 PNG 导入用例完全不依赖二进制夹具：块的类型、关键字、编码方式
/// 都在用例里显式声明，评审时一眼能看出测的是哪一种真实形态。
Uint8List buildPng(
  List<PngTextBlock> blocks, {
  int width = 1,
  int height = 1,
  bool truncateLastChunk = false,
}) {
  final out = BytesBuilder();
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final ihdr = BytesBuilder()
    ..add(_uint32(width))
    ..add(_uint32(height))
    ..add(const [8, 2, 0, 0, 0]); // 8 bit / truecolor RGB / 无隔行
  out.add(_chunk('IHDR', ihdr.toBytes()));

  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    final bytes = _encodeTextBlock(block);
    if (truncateLastChunk && i == blocks.length - 1) {
      // 只写长度与类型，故意不给数据与 CRC —— 模拟下载中断的文件
      out.add(_uint32(bytes.length));
      out.add(ascii.encode(block.chunkType));
      break;
    }
    out.add(_chunk(block.chunkType, bytes));
  }

  // 1x1 RGB 像素的 zlib 流（filter byte 0x00 + 三个颜色分量）
  out.add(_chunk('IDAT', Uint8List.fromList(_idat1x1Rgb)));
  out.add(_chunk('IEND', Uint8List(0)));
  return out.toBytes();
}

/// PNG 文本块的描述
class PngTextBlock {
  final String keyword;

  /// 明文载荷；[preCompressed] 为 true 时表示"直接写入的最终字节"
  final Uint8List payload;

  /// `tEXt` / `zTXt` / `iTXt`
  final String chunkType;

  /// iTXt 的压缩标志；为 true 时载荷会被 zlib 压缩后写入
  final bool compressionFlag;

  /// 跳过压缩，原样写入 [payload]（用于注入损坏的压缩流）
  final bool preCompressed;

  const PngTextBlock._(
    this.keyword,
    this.payload,
    this.chunkType,
    this.compressionFlag,
    this.preCompressed,
  );

  /// 规范形态：块值 = base64(UTF-8 JSON)。SillyTavern / chub.ai 的导出方式。
  factory PngTextBlock.base64(
    String keyword,
    String json, {
    bool isITxt = false,
    bool compressionFlag = false,
    bool padToMultipleOfFour = true,
  }) {
    var encoded = base64.encode(utf8.encode(json));
    if (!padToMultipleOfFour) encoded = encoded.replaceAll('=', '');
    return PngTextBlock._(
      keyword,
      Uint8List.fromList(latin1.encode(encoded)),
      isITxt ? 'iTXt' : 'tEXt',
      compressionFlag,
      false,
    );
  }

  /// 非规范形态：块值就是原始 JSON
  factory PngTextBlock.raw(
    String keyword,
    String json, {
    bool isITxt = false,
  }) =>
      PngTextBlock._(
        keyword,
        Uint8List.fromList(utf8.encode(json)),
        isITxt ? 'iTXt' : 'tEXt',
        false,
        false,
      );

  /// zTXt 规范形态：base64 文本再经 zlib 压缩（`keyword \0 method \0 zlib`）
  factory PngTextBlock.zlibBase64(String keyword, String json) =>
      PngTextBlock._(
        keyword,
        Uint8List.fromList(latin1.encode(base64.encode(utf8.encode(json)))),
        'zTXt',
        false,
        false,
      );

  /// zTXt 非规范形态：原始 JSON 经 zlib 压缩
  factory PngTextBlock.zlibRaw(String keyword, String json) => PngTextBlock._(
        keyword,
        Uint8List.fromList(utf8.encode(json)),
        'zTXt',
        false,
        false,
      );

  /// 故障注入：块体符合 zTXt 布局，但压缩流被人为破坏
  factory PngTextBlock.corruptZlib(
    String keyword, [
    List<int> garbage = const [0xDE, 0xAD, 0xBE, 0xEF],
  ]) =>
      PngTextBlock._(
        keyword,
        Uint8List.fromList(garbage),
        'zTXt',
        false,
        true,
      );
}

Uint8List _encodeTextBlock(PngTextBlock block) {
  final needsCompression = block.chunkType == 'zTXt' || block.compressionFlag;
  final payload = (needsCompression && !block.preCompressed)
      ? ZLibEncoder().encodeBytes(block.payload)
      : block.payload;

  final out = BytesBuilder()
    ..add(ascii.encode(block.keyword))
    ..addByte(0); // keyword 终止符

  if (block.chunkType == 'iTXt') {
    out
      ..addByte(block.compressionFlag ? 1 : 0)
      ..addByte(0) // compressionMethod
      ..addByte(0) // langTag 为空
      ..addByte(0); // translatedKeyword 为空
  } else if (block.chunkType == 'zTXt') {
    out.addByte(0); // compressionMethod（zlib）
  }

  return (out..add(payload)).toBytes();
}

Uint8List _chunk(String type, Uint8List data) {
  final out = BytesBuilder()
    ..add(_uint32(data.length))
    ..add(ascii.encode(type))
    ..add(data)
    ..add(_uint32(_crc32(type, data)));
  return out.toBytes();
}

Uint8List _uint32(int value) => Uint8List(4)
  ..buffer.asByteData().setUint32(0, value);

final List<int> _crcTable = _buildCrcTable();

List<int> _buildCrcTable() {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}

int _crc32(String type, Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in ascii.encode(type)) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// 1x1 RGB 像素经 zlib 压缩后的 IDAT 载荷（预先算好，避免测试引入 zlib 依赖）
const List<int> _idat1x1Rgb = [
  0x78, 0xDA, 0x63, 0x60, 0x60, 0x60, 0x00, 0x00, 0x00, 0x04, 0x00, 0x01,
];

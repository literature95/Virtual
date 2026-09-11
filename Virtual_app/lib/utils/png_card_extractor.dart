import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// PNG 容器中内嵌角色卡的提取结果
class PngCardPayload {
  /// 解出的 JSON 文本（尚未做 schema 解释）
  final String json;

  /// 命中的文本块关键字，如 `chara` / `ccv3`
  final String keyword;

  /// 承载该内容的块类型，`tEXt` / `zTXt` / `iTXt`
  final String chunkType;

  const PngCardPayload({
    required this.json,
    required this.keyword,
    required this.chunkType,
  });
}

/// PNG 文件签名（前 8 字节）
const List<int> _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// 可能承载角色卡的文本块关键字（统一转小写后比较）
///
/// - `chara` —— SillyTavern / Character Card V2 约定
/// - `ccv3`  —— Character Card V3 约定
/// - `chara_card_v2` / `chara_card_v3` —— 少数工具直接以 spec 名作关键字
const Set<String> _cardKeywords = {
  'chara',
  'ccv3',
  'chara_card_v2',
  'chara_card_v3',
};

/// 是否为 PNG 签名（只判前 8 字节）。
///
/// 供调用方在"完全没有卡片数据"时区分两种情形：**普通图片**（用户误拖了插画）
/// 与**其他格式**（本想导入 JSON 却选错文件），从而给出更准确的提示。
bool hasPngSignature(Uint8List bytes) {
  if (bytes.length < 8) return false;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != _pngSignature[i]) return false;
  }
  return true;
}

/// zlib 解压函数签名（输入压缩流，输出解压字节）
typedef ZlibInflate = Uint8List Function(List<int> bytes);

/// 从 PNG 字节流中提取内嵌的角色卡 JSON。
///
/// 按 PNG 规范逐块遍历，命中 [tEXt] / [zTXt] / [iTXt] 且关键字属于
/// [_cardKeywords] 时，将块值按 **base64** 解码（这是 CCv2/v3 规范要求的存储
/// 方式），并兼容少数工具"把 JSON 直接写进文本块"的非规范写法。压缩块
/// （`zTXt` 恒压缩、`iTXt` 的 `compressionFlag == 1`）先做 zlib 解压再走同一路径。
///
/// 一块卡片里常同时存在 `chara` 与 `ccv3`（前者为向后兼容副本）。二者内容
/// 通常一致，但当它们**不一致**时，取 `spec` 版本更高的一方 —— 低版本副本会
/// 丢掉 V3 独有字段（`assets` / `nickname` / `group_only_greetings` 等），
/// 直接取首个命中会造成静默的数据丢失。
///
/// 返回 null 的语义是「不是 PNG / 没有相关文本块 / 内容解不出 JSON」，
/// 由调用方决定后续回退。本函数**不抛异常** —— 畸形、截断或压缩损坏的文件
/// 应被当作未找到处理，而不是中断整条导入流程。
///
/// [zlibInflate] 仅为可测试性保留：默认走 [ZLibDecoder]（原生端用 `dart:io` 的
/// `ZLibCodec`、Web 端用 archive 的纯 Dart inflate，由条件导入自动切换）。
/// 单测可传入 `ZLibDecoderWeb` 以在 VM 上覆盖 **Web 那条纯 Dart 路径**，
/// 否则该路径在 CI 中永远不会被执行。
PngCardPayload? extractPngCard(
  Uint8List bytes, {
  ZlibInflate? zlibInflate,
}) {
  if (!hasPngSignature(bytes)) return null;

  final view = ByteData.sublistView(bytes);
  final hits = <PngCardPayload>[];
  var offset = 8;
  while (offset + 8 <= bytes.length) {
    final length = view.getUint32(offset);
    final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
    final dataStart = offset + 8;
    final dataEnd = dataStart + length;

    // 长度字段不可信：越界即说明文件被截断，就地停止
    if (dataEnd + 4 > bytes.length) break;

    if (type == 'tEXt' || type == 'zTXt' || type == 'iTXt') {
      final hit = _readTextChunk(bytes, dataStart, dataEnd, type, zlibInflate);
      if (hit != null) hits.add(hit);
    }
    if (type == 'IEND') break;

    offset = dataEnd + 4; // 跳过 4 字节 CRC
  }

  if (hits.isEmpty) return null;
  return _preferHighestSpec(hits);
}

/// 在多块命中时选出信息量最大的一份（`spec` 版本高者胜，同版本取先出现的）。
///
/// 不用 `List.sort` —— Dart 的排序不保证稳定，同版本时会打乱"文档顺序优先"
/// 这一既定语义。
PngCardPayload _preferHighestSpec(List<PngCardPayload> hits) {
  var best = hits.first;
  var bestRank = _specRank(best.json);
  for (final hit in hits.skip(1)) {
    final rank = _specRank(hit.json);
    if (rank > bestRank) {
      best = hit;
      bestRank = rank;
    }
  }
  return best;
}

final RegExp _specPattern = RegExp(r'"spec"\s*:\s*"chara_card_v(\d+)"');

/// 从 JSON 文本里读出 spec 版本号；无 spec 字段（裸字段卡）记 0。
int _specRank(String json) {
  final match = _specPattern.firstMatch(json);
  if (match == null) return 0;
  return int.tryParse(match.group(1)!) ?? 0;
}

/// 解析单个文本块。布局如下：
///
/// ```
/// tEXt : keyword \0 value
/// zTXt : keyword \0 compressionMethod(1) compressedValue(zlib)
/// iTXt : keyword \0 compressionFlag(1) compressionMethod(1) \
///        langTag \0 translatedKeyword \0 value
/// ```
PngCardPayload? _readTextChunk(
  Uint8List bytes,
  int start,
  int end,
  String chunkType,
  ZlibInflate? zlibInflate,
) {
  final keywordNul = _indexOfByte(bytes, 0x00, start, end);
  if (keywordNul < 0) return null;

  final keyword = String.fromCharCodes(bytes, start, keywordNul).toLowerCase();
  if (!_cardKeywords.contains(keyword)) return null;

  var valueStart = keywordNul + 1;
  var compressed = false;

  if (chunkType == 'zTXt') {
    // zTXt 的载荷恒为 zlib 流，压缩方式字节固定为 0
    if (valueStart + 1 > end) return null;
    compressed = true;
    valueStart += 1;
  } else if (chunkType == 'iTXt') {
    if (valueStart + 2 > end) return null;
    compressed = bytes[valueStart] == 1;
    valueStart += 2; // 跳过 compressionFlag + compressionMethod

    valueStart = _cStringEnd(bytes, valueStart, end) + 1; // langTag
    valueStart = _cStringEnd(bytes, valueStart, end) + 1; // translatedKeyword
  }
  if (valueStart >= end) return null;

  var payload = Uint8List.sublistView(bytes, valueStart, end);
  if (payload.isEmpty) return null;

  if (compressed) {
    final inflated = _inflate(payload, zlibInflate);
    if (inflated == null || inflated.isEmpty) return null;
    payload = inflated;
  }

  for (final candidate in _jsonCandidates(payload)) {
    if (candidate.trimLeft().startsWith('{')) {
      return PngCardPayload(
        json: candidate,
        keyword: keyword,
        chunkType: chunkType,
      );
    }
  }
  return null;
}

/// zlib 解压；载荷损坏时返回 null，由调用方按"未找到"处理。
///
/// `package:archive` 的 [ZLibDecoder] 会在原生平台自动委托给 `dart:io` 的
/// `ZLibCodec`、在 Web 上回落到纯 Dart 的 inflate，因此这里无需条件导入。
///
/// 注意 Web 上的纯 Dart 实现**解压失败不一定抛异常**，可能只返回空字节，
/// 因此调用方必须同时判空 —— 这是 [extractPngCard] 里那处 `isEmpty` 检查的由来。
Uint8List? _inflate(Uint8List payload, ZlibInflate? zlibInflate) {
  try {
    return zlibInflate != null
        ? zlibInflate(payload)
        : ZLibDecoder().decodeBytes(payload);
  } catch (_) {
    return null;
  }
}

/// 依次产出载荷可能的 JSON 文本形态，首个以 `{` 开头者胜出。
Iterable<String> _jsonCandidates(Uint8List payload) sync* {
  // 形态一：非规范 —— 块内直接就是 JSON。
  //
  // 必须先试 UTF-8：按 latin1 逐字节映射同样能得到"看起来是 JSON"的文本，
  // 但多字节字符（中文角色名、人设）会全部变成乱码，且 jsonDecode 不会报错，
  // 于是乱码被静默写进数据库。
  final asUtf8 = utf8.decode(payload, allowMalformed: true).trim();
  final asLatin1 = String.fromCharCodes(payload).trim();

  if (asUtf8.startsWith('{')) yield asUtf8;
  if (asLatin1 != asUtf8 && asLatin1.startsWith('{')) yield asLatin1;

  // 形态二：规范 —— base64(UTF-8 JSON)。导出工具常省掉 '=' 填充，需补齐。
  // base64 字母表只含 ASCII，故两种解释一致，用 asLatin1 即可。
  final encoded = asLatin1.padRight((asLatin1.length + 3) & ~3, '=');
  final decoders = <Uint8List Function(String)>[
    base64Decode,
    // 少数工具用 URL-safe 字母表（- 与 _）
    (s) => base64Decode(s.replaceAll('-', '+').replaceAll('_', '/')),
  ];
  for (final decode in decoders) {
    try {
      yield utf8.decode(decode(encoded), allowMalformed: true);
      return;
    } catch (_) {
      // 换下一种字母表
    }
  }
}

int _indexOfByte(Uint8List bytes, int target, int start, int end) {
  for (var i = start; i < end; i++) {
    if (bytes[i] == target) return i;
  }
  return -1;
}

/// 返回 C 风格字符串的 NUL 下标；未找到时返回 [end]，使调用方越界退出
int _cStringEnd(Uint8List bytes, int start, int end) {
  final index = _indexOfByte(bytes, 0x00, start, end);
  return index < 0 ? end : index;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 角色卡 PNG 的**写入**侧 —— 与 `png_card_extractor.dart` 严格对称。
///
/// 为什么单独成文件：解析侧的坑（整包跑正则、base64 未解码）正是因为
/// 「写入与读取各写一套、互不校验」而长期潜伏。把写入收敛到这里，并由
/// `test/png_card_writer_test.dart` 做**往返闭环**断言（写入 → 解析器读回
/// → 字段全等），任何一侧漂移都会立刻变红。
///
/// 依赖约束：只依赖 `dart:convert` / `dart:typed_data` 与 `package:image`
/// （纯 Dart，Web 与原生同一条路径），**不引 `dart:io`、不引 Flutter**。

/// 品牌渐变（与 `App.css` / `design_tokens.dart` 一致）：紫 → 橙
const int _gradTopR = 0x7e, _gradTopG = 0x4d, _gradTopB = 0xf1;
const int _gradBotR = 0xe5, _gradBotG = 0x80, _gradBotB = 0x29;

/// 角色卡文本块的关键字
///
/// 真实卡片普遍**同时写两块**（793 张实测全部如此，且内容一致）：
/// SillyTavern 读 `chara`，按 CCv3 规范实现的前端读 `ccv3`。
/// 只写其中一块会让另一半前端读不到。
const List<String> cardChunkKeywords = ['chara', 'ccv3'];

/// 把角色卡 JSON 嵌入 PNG，生成可直接分发的角色卡文件。
///
/// [json] 为 CCv3 包装体的序列化文本（`{"spec":"chara_card_v3","data":{…}}`）。
/// 值按规范写成 **base64(UTF-8 JSON)**，而非原始 JSON —— 这一点必须与解析器
/// 的读取方式一致。
///
/// [baseImage] 为底图，PNG / JPEG / GIF / BMP / WebP 均可（内部统一转成
/// PNG）；传 null 时生成品牌色渐变占位图。
Uint8List buildCardPng(String json, {Uint8List? baseImage}) {
  final img.Image? image =
      baseImage == null ? _placeholder() : img.decodeImage(baseImage);
  if (image == null) {
    throw const FormatException(
      '底图无法解码（支持 PNG / JPEG / GIF / BMP / WebP）',
    );
  }

  final payload = base64Encode(utf8.encode(json));
  image.textData = <String, String>{
    for (final keyword in cardChunkKeywords) keyword: payload,
  };

  // singleFrame：底图若是动图（GIF/APNG），只保留首帧，避免产出 APNG
  // 让部分解析器只扫到第一帧之外的内容。
  return img.encodePng(image, singleFrame: true);
}

/// 生成角色卡占位底图（品牌色竖向渐变）
///
/// 角色没有可用立绘时用它兜底 —— 卡片的关键是内嵌的 JSON，底图只是载体，
/// 但不能因此产出一张无法预览的破图。
Uint8List buildPlaceholderPng({int width = 512, int height = 768}) {
  return img.encodePng(_placeholder(width: width, height: height));
}

img.Image _placeholder({int width = 512, int height = 768}) {
  final image = img.Image(width: width, height: height);
  final span = height <= 1 ? 1 : height - 1;
  for (var y = 0; y < height; y++) {
    final t = y / span;
    img.fillRect(
      image,
      x1: 0,
      y1: y,
      x2: width - 1,
      y2: y,
      color: img.ColorRgb8(
        (_gradTopR + (_gradBotR - _gradTopR) * t).round(),
        (_gradTopG + (_gradBotG - _gradTopG) * t).round(),
        (_gradTopB + (_gradBotB - _gradTopB) * t).round(),
      ),
      // 初生位图是透明黑，混合会把品牌色压暗；直接覆盖
      alphaBlend: false,
    );
  }
  return image;
}

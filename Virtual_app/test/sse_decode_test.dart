// SSE 流解码回归测试。
//
// 背景（真机必现的致命缺陷）：
//   dio 的 ResponseBody.stream 运行时类型是 Stream<Uint8List>。若在此接收者上
//   调用 .transform(utf8.decoder)，Stream.transform 的泛型实参按接收者的**运行时**
//   类型实参绑定为 Uint8List，而 Utf8Decoder 实现的是
//   StreamTransformer<List<int>, String> —— 泛型实参不一致，运行时检查直接抛：
//     type 'Utf8Decoder' is not a subtype of type
//     'StreamTransformer<Uint8List, String>' of 'streamTransformer'
//   表现为对话一发送就"生成失败"，三个适配器（openai/anthropic/gemini）全中。
//   `as Stream<List<int>>` 只改静态类型、不改运行时实参，因此无法规避。
//
// 本文件同时固化"反例"，防止重构时改回 .transform(utf8.decoder)。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/services/adapters/llm_adapter.dart';

void main() {
  group('decodeSseLines', () {
    test('在 Stream<Uint8List> 接收者上不抛类型错误（本次线上缺陷的核心回归）',
        () async {
      // 构造与 dio ResponseBody.stream 运行时类型一致的流：Stream<Uint8List>
      final raw = Stream<Uint8List>.fromIterable(<Uint8List>[
        Uint8List.fromList(utf8.encode('data: {"a":1}\n\n')),
        Uint8List.fromList(utf8.encode('data: [DONE]\n\n')),
      ]);

      final lines = await decodeSseLines(raw).toList();

      expect(
        lines.where((l) => l.trim().isNotEmpty).toList(),
        ['data: {"a":1}', 'data: [DONE]'],
      );
    });

    test('多字节 UTF-8 字符被 chunk 边界切断时不产生乱码', () async {
      // 把一个中文字符（3 字节）从中间切开，模拟 TCP 分片
      final bytes = utf8.encode('data: {"t":"你好"}\n\n');
      final split = bytes.indexOf(0xE4) + 1; // "你" 的第一个字节之后
      final raw = Stream<Uint8List>.fromIterable(<Uint8List>[
        Uint8List.fromList(bytes.sublist(0, split)),
        Uint8List.fromList(bytes.sublist(split)),
      ]);

      final lines = await decodeSseLines(raw).toList();

      expect(lines.first, 'data: {"t":"你好"}');
      expect(jsonDecode(lines.first.substring(5).trim())['t'], '你好');
    });

    test('处理 CRLF 与结尾无换行的情况', () async {
      final raw = Stream<Uint8List>.fromIterable(<Uint8List>[
        Uint8List.fromList(utf8.encode('data: 1\r\n')),
        Uint8List.fromList(utf8.encode('data: 2\r\n\r\n')),
      ]);

      final lines = (await decodeSseLines(raw).toList())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(lines, ['data: 1', 'data: 2']);
    });

    test('空流安全返回空序列', () async {
      final raw = Stream<Uint8List>.fromIterable(<Uint8List>[]);
      expect(await decodeSseLines(raw).toList(), isEmpty);
    });
  });

  group('反例固化：为什么不能写 transform(utf8.decoder)', () {
    test('静态类型为 Stream<List<int>> 但运行时实参是 Uint8List 时抛 TypeError',
        () async {
      // 静态类型声明为 Stream<List<int>>（与适配器里的 as 转换等效），
      // 运行时实参仍是 Uint8List —— 与线上环境完全一致。
      final Stream<Uint8List> raw = Stream<Uint8List>.fromIterable(
        <Uint8List>[Uint8List.fromList(utf8.encode('data: x\n\n'))],
      );
      final Stream<List<int>> asList = raw;

      // 注意：该 TypeError 是**同步**抛出的（泛型实参检查发生在 transform 调用点，
      // 而非流事件推送时），所以它在适配器里不会被 `on DioException` 捕获，
      // 而是直接冒泡成"生成失败" —— 与线上现象一致。
      expect(
        () => asList.transform(utf8.decoder).drain<void>(),
        throwsA(
          isA<TypeError>().having(
            (e) => e.toString(),
            'message',
            contains('Utf8Decoder'),
          ),
        ),
      );
    });
  });
}

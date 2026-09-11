// 角色卡 PNG 导出/往返的批量回归探针
//
// 用法：
//   dart run tool/card_png_export_probe.dart <文件或目录> [输出目录]
//
// 对每张输入 PNG：
//   1. 解析出角色卡（CharacterImportService）；
//   2. 用角色卡原图作底图重新导出 PNG（CharacterExportService）；
//   3. 把导出结果**重新解析**，逐字段比对；
//   4. 给出字段级差异清单。
//
// 为什么要有它：写入侧（PngEncoder 的 tEXt）与读取侧（自研 chunk 解析器）是
// 两套独立代码，单元测试只能覆盖构造出来的样本。真实卡片库（数百张、字段
// 千奇百怪）才能暴露"导出后某个字段悄悄丢了"这类问题。
//
// 指定输出目录时会把导出的 PNG 落盘，便于用**另一种语言**的解析器
// （如 tool/inspect_card_png.py）交叉验证 —— 自研读写互相自洽不算证据。
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:virtual/services/character_export_service.dart';
import 'package:virtual/services/character_import_service.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      '用法: dart run tool/card_png_export_probe.dart <文件或目录> [输出目录]',
    );
    exitCode = 2;
    return;
  }

  final targets = <File>[];
  final type = FileSystemEntity.typeSync(args[0]);
  if (type == FileSystemEntityType.directory) {
    targets.addAll(
      Directory(args[0])
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png')),
    );
  } else {
    targets.add(File(args[0]));
  }
  final outDir = args.length > 1 ? Directory(args[1]) : null;
  if (outDir != null && !outDir.existsSync()) outDir.createSync(recursive: true);

  final importService = CharacterImportService(Dio());
  final exportService = CharacterExportService();

  var ok = 0;
  final failures = <String, String>{};
  final diffs = <String, List<String>>{};

  for (final file in targets) {
    final label = file.path.split(RegExp(r'[\\/]')).last;
    try {
      final original = file.readAsBytesSync();
      final bundle = importService.importBundleFromBytes(
        original,
        sourceName: label,
      );

      // 用原卡图作底图，保持视觉不变
      final exported = await exportService.exportPngBytes(
        bundle.character,
        lorebook: bundle.lorebook,
        baseImage: original,
      );

      if (outDir != null) {
        File('${outDir.path}/${exportService.pngFileName(bundle.character)}')
            .writeAsBytesSync(exported);
      }

      // 重新解析导出结果
      final back = importService.importBundleFromBytes(
        exported,
        sourceName: 'roundtrip-$label',
      );

      final d = _diff(bundle, back);
      if (d.isEmpty) {
        ok++;
      } else {
        diffs[label] = d;
      }
    } catch (e) {
      failures[label] = e.toString().replaceFirst('Exception: ', '');
    }
  }

  stdout.writeln('扫描 ${targets.length} 张 PNG');
  stdout.writeln('往返一致 $ok / 有差异 ${diffs.length} / 失败 ${failures.length}');

  if (outDir != null) {
    stdout.writeln('导出产物目录: ${outDir.path}');
  }

  if (diffs.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('=== 字段差异（前 10 张）===');
    diffs.entries.take(10).forEach((e) {
      stdout.writeln('  ${e.key}');
      for (final line in e.value.take(8)) {
        stdout.writeln('      $line');
      }
    });
  }

  if (failures.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('=== 失败清单（前 10 张）===');
    failures.entries.take(10).forEach((e) {
      stdout.writeln('  ${e.key} → ${e.value}');
    });
  }

  if (diffs.isNotEmpty || failures.isNotEmpty) exitCode = 1;
}

/// 逐字段比对两次解析的产物，返回差异描述
///
/// 口径：**语义级全等**。导出时 `_dropNulls` 会剥掉空字符串，所以 `''` 与
/// 缺字段（`null`）视为等价 —— 否则每张真实卡都会刷出一屏无意义的差异，
/// 把真正的字段丢失淹没掉。
List<String> _diff(dynamic a, dynamic b) {
  final out = <String>[];
  final ca = a.character;
  final cb = b.character;

  void cmp(String field, Object? x, Object? y) {
    if (_norm(x) != _norm(y)) out.add('$field: ${_short(x)} → ${_short(y)}');
  }

  cmp('name', ca.name, cb.name);
  cmp('nickname', ca.nickname, cb.nickname);
  cmp('description', ca.description, cb.description);
  cmp('personality', ca.personality, cb.personality);
  cmp('scenario', ca.scenario, cb.scenario);
  cmp('firstMessage', ca.firstMessage, cb.firstMessage);
  cmp('systemPrompt', ca.systemPrompt, cb.systemPrompt);
  cmp('postHistoryInstructions', ca.postHistoryInstructions, cb.postHistoryInstructions);
  cmp('creator', ca.creator, cb.creator);
  cmp('characterVersion', ca.characterVersion, cb.characterVersion);
  cmp('creatorNotes', ca.creatorNotes, cb.creatorNotes);
  cmp('tags', ca.tags.join('|'), cb.tags.join('|'));
  cmp('alternateGreetings.length', ca.alternateGreetings.length, cb.alternateGreetings.length);
  cmp('groupOnlyGreetings.length', ca.groupOnlyGreetings.length, cb.groupOnlyGreetings.length);
  cmp('exampleMessages.length', ca.exampleMessages.length, cb.exampleMessages.length);

  // 世界书是最容易丢的部分
  final la = a.lorebook;
  final lb = b.lorebook;
  if (la == null && lb == null) return out;
  if (la == null || lb == null) {
    out.add('lorebook: ${la?.entries.length ?? 'null'} → ${lb?.entries.length ?? 'null'}');
    return out;
  }
  cmp('lorebook.entries.length', la.entries.length, lb.entries.length);
  cmp('lorebook.name', la.name, lb.name);
  final n = la.entries.length < lb.entries.length ? la.entries.length : lb.entries.length;
  for (var i = 0; i < n; i++) {
    final x = la.entries[i];
    final y = lb.entries[i];
    if (x.content != y.content) out.add('entry[$i].content 不一致');
    if (x.matchKeys.join('|') != y.matchKeys.join('|')) {
      out.add('entry[$i].keys: ${x.matchKeys} → ${y.matchKeys}');
    }
    if (x.enabled != y.enabled) out.add('entry[$i].enabled: ${x.enabled} → ${y.enabled}');
    if (x.order != y.order) out.add('entry[$i].order: ${x.order} → ${y.order}');
  }
  return out;
}

String _short(Object? v) {
  if (v == null) return 'null';
  final s = v.toString();
  return s.length > 40 ? '${s.substring(0, 38)}…' : s;
}

/// 归一化：null 与空串等价（`_dropNulls` 的语义）
Object _norm(Object? v) {
  if (v == null) return '';
  if (v is String && v.isEmpty) return '';
  return v;
}

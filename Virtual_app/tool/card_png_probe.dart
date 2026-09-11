// 探针：实测角色卡导入（PNG 容器 / 裸 JSON），用真实文件验证
//
// 用法：
//   dart run tool/card_png_probe.dart <文件或目录>...
//
// 传入文件时逐张打印详情；传入目录时递归扫描其中的 *.png 并只汇报统计与失败项
// （用于对整库真实卡片做回归，避免刷屏）。
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:virtual/services/character_import_service.dart';

Future<void> main(List<String> args) async {
  final svc = CharacterImportService(Dio());
  if (args.isEmpty) {
    stderr.writeln('用法: dart run tool/card_png_probe.dart <文件或目录>...');
    exitCode = 2;
    return;
  }

  final files = <File>[];
  final dirs = <Directory>[];
  for (final arg in args) {
    final entity = FileSystemEntity.typeSync(arg);
    if (entity == FileSystemEntityType.directory) {
      dirs.add(Directory(arg));
    } else {
      files.add(File(arg));
    }
  }

  for (final file in files) {
    await _inspect(svc, file);
  }
  for (final dir in dirs) {
    await _sweep(svc, dir);
  }
}

/// 单文件详情
Future<void> _inspect(CharacterImportService svc, File file) async {
  final name = file.path.split(RegExp(r'[\\/]')).last;
  stdout.writeln('── $name ──');
  final bytes = await file.readAsBytes();
  stdout.writeln('   文件大小: ${bytes.length} 字节');

  try {
    final b = svc.importBundleFromBytes(bytes, sourceName: name);
    stdout.writeln('   结果: 成功');
    stdout.writeln('   ${b.summary}');
    stdout.writeln('   sourceFormat: ${b.sourceFormat}');
    stdout.writeln('   角色名: ${b.character.name}');
    stdout.writeln('   描述长度: ${b.character.description?.length ?? 0}');
    stdout.writeln('   首条问候: ${_preview(b.character.firstMessage)}');
    stdout.writeln('   extensions 键: ${b.character.extensions.keys.toList()}');
    stdout.writeln('   示例对话: ${b.character.exampleMessages.length} 条');
    if (b.lorebook != null) {
      stdout.writeln('   世界书: ${b.lorebook!.entries.length} 条');
    }
    if (b.warnings.isNotEmpty) stdout.writeln('   warnings: ${b.warnings}');
  } catch (e) {
    stdout.writeln('   结果: 失败 -> $e');
  }
  stdout.writeln('');
}

/// 目录批量扫描：只汇报统计与失败项
Future<void> _sweep(CharacterImportService svc, Directory dir) async {
  final pngs = dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  stdout.writeln('══ 批量扫描 ${dir.path} ══');
  stdout.writeln('共 ${pngs.length} 个 PNG');

  final failures = <String, String>{};
  var noLorebook = 0;
  var emptyName = 0;
  final keywordTally = <String, int>{};

  for (final file in pngs) {
    final name = file.path.split(RegExp(r'[\\/]')).last;
    try {
      final bytes = await file.readAsBytes();
      final b = svc.importBundleFromBytes(bytes, sourceName: name);
      if (b.character.name.trim().isEmpty) emptyName++;
      final fmt = b.sourceFormat;
      final kw = RegExp(r'PNG\(([^)]+)\)').firstMatch(fmt)?.group(1) ?? '(无容器)';
      keywordTally[kw] = (keywordTally[kw] ?? 0) + 1;
      if (b.lorebook == null || b.lorebook!.entries.isEmpty) noLorebook++;
    } catch (e) {
      failures[name] = e.toString();
    }
  }

  final ok = pngs.length - failures.length;
  stdout.writeln('成功 $ok / ${pngs.length}');
  stdout.writeln('命中关键字分布: $keywordTally');
  stdout.writeln('无世界书: $noLorebook 张（卡片本身可能没有 character_book）');
  stdout.writeln('角色名为空: $emptyName 张');
  if (failures.isEmpty) {
    stdout.writeln('失败: 无');
  } else {
    stdout.writeln('失败 ${failures.length} 张:');
    failures.forEach((k, v) => stdout.writeln('  $k -> $v'));
  }
  stdout.writeln('');
}

String _preview(String? s) {
  if (s == null || s.isEmpty) return '(空)';
  final one = s.replaceAll(RegExp(r'\s+'), ' ');
  final encoded = jsonEncode(one);
  return encoded.length <= 60 ? encoded : '${encoded.substring(0, 57)}…';
}

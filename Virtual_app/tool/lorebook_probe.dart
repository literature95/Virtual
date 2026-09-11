// 世界书 JSON 导入的批量回归探针
//
// 用法：
//   dart run tool/lorebook_probe.dart <文件或目录>
//
// 递归扫描目录下全部 *.json，逐个走 LorebookImportService.importFromBytes，
// 统计成功率、识别出的形态分布、条目总数，并列出失败文件与原因。
//
// 为什么要有这个工具：世界书 JSON 的真实形态与「看起来应该是什么」差距很大
// ——实测 231 个真实文件里 221 个用的是 SillyTavern 的 `entries` 对象形态，
// 而不是 CCv3 `character_book` 的数组形态。只靠单元测试的自造夹具无法发现
// 这类偏差，必须跑真实语料。
import 'dart:io';

import 'package:virtual/services/lorebook_import_service.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('用法: dart run tool/lorebook_probe.dart <文件或目录>');
    exitCode = 2;
    return;
  }

  final targets = <File>[];
  for (final arg in args) {
    final type = FileSystemEntity.typeSync(arg);
    if (type == FileSystemEntityType.directory) {
      targets.addAll(
        Directory(arg)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.json')),
      );
    } else if (type == FileSystemEntityType.file) {
      targets.add(File(arg));
    } else {
      stderr.writeln('路径不存在: $arg');
    }
  }

  if (targets.isEmpty) {
    stderr.writeln('没有找到任何 *.json');
    exitCode = 2;
    return;
  }

  final service = LorebookImportService();
  final failures = <String, String>{};
  final formats = <String, int>{};
  final perFile = <String, int>{};
  var ok = 0;
  var totalEntries = 0;
  var totalWarnings = 0;

  for (final file in targets) {
    // 用完整路径做键：不同目录常有同名文件（如同一份世界书的多份副本），
    // 只取 basename 会让失败清单互相覆盖、统计数对不上。
    final name = file.path;
    try {
      final result = service.importFromBytes(
        file.readAsBytesSync(),
        sourceName: name,
      );
      ok++;
      totalEntries += result.lorebook.entries.length;
      totalWarnings += result.warnings.length;
      formats[result.sourceFormat] = (formats[result.sourceFormat] ?? 0) + 1;
      perFile[name] = result.lorebook.entries.length;
    } catch (e) {
      failures[name] = e.toString().replaceFirst('Exception: ', '');
    }
  }

  final total = targets.length;
  stdout.writeln('扫描 ${targets.length} 个 JSON');
  stdout.writeln('成功 $ok / 失败 ${failures.length}');
  stdout.writeln('解析条目合计 $totalEntries，提示合计 $totalWarnings');
  stdout.writeln('');
  stdout.writeln('=== 形态分布 ===');
  final sortedFormats = formats.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sortedFormats) {
    stdout.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
  }

  if (failures.isEmpty) {
    stdout.writeln('');
    stdout.writeln('全部通过（${(ok / total * 100).toStringAsFixed(1)}%）');
    return;
  }

  stdout.writeln('');
  stdout.writeln('=== 失败清单（按原因归类）===');
  final byReason = <String, List<String>>{};
  failures.forEach((path, reason) {
    byReason.putIfAbsent(reason, () => []).add(path.split(RegExp(r'[\\/]')).last);
  });
  byReason.forEach((reason, names) {
    stdout.writeln('  [${names.length}] $reason');
    for (final n in names) {
      stdout.writeln('        · ${n.length > 44 ? '${n.substring(0, 42)}…' : n}');
    }
  });

  // 失败多为「空壳预设 / 角色卡误放」等正确拒绝，非零退出码交给 CI 判断
  exitCode = 1;
}

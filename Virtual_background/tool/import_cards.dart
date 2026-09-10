import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';

/// CCv2/v3 角色卡批量导入工具
///
/// 把一个装满角色卡 JSON 文件的目录批量灌入 PostgreSQL characters 表。
/// 与 POST /api/characters 同一条映射/落库链路（CharacterCardMapper），
/// 但不经过 HTTP，批量事务写入，适合第三方卡片数据集（数万张量级）。
///
/// 用法（在 Virtual_background 目录下执行）：
/// ```sh
/// dart run tool/import_cards.dart <cardsDir> [选项]
/// ```
/// 选项：
/// - `--limit=N`      只导入前 N 张有效卡（0 = 不限，默认 0）
/// - `--batch-size=N` 每个事务的写入条数（默认 100）
/// - `--dry-run`      只解析校验，不写库（不需要 PostgreSQL）
///
/// 身份规则：
/// - character_id = 文件名（去掉 .json 后缀，数据集为 UUID，天然唯一）
/// - character_version = 卡内 `character_version`（缺失时 '1.0'）
/// - avatar 字段为 "none"/空 时落 NULL（客户端走占位图）
/// - 同 (id, version) 重复导入 = 覆盖（幂等，可安全重跑）
Future<void> main(List<String> args) async {
  var cardsDir = '';
  var limit = 0;
  var batchSize = 100;
  var dryRun = false;
  for (final arg in args) {
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg.startsWith('--limit=')) {
      limit = int.tryParse(arg.substring(8)) ?? 0;
    } else if (arg.startsWith('--batch-size=')) {
      batchSize = int.tryParse(arg.substring(13)) ?? 100;
    } else if (!arg.startsWith('-')) {
      cardsDir = arg;
    }
  }
  if (cardsDir.isEmpty) {
    stderr.writeln(
      '用法: dart run tool/import_cards.dart <cardsDir> '
      '[--limit=N] [--batch-size=N] [--dry-run]',
    );
    exitCode = 2;
    return;
  }
  final dir = Directory(cardsDir);
  if (!dir.existsSync()) {
    stderr.writeln('目录不存在: $cardsDir');
    exitCode = 2;
    return;
  }

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  stdout.writeln('[import] 发现 ${files.length} 个 JSON 文件于 $cardsDir');

  // ---------- 解析阶段：文件 → data → DB 行 ----------
  final rows = <Map<String, dynamic>>[];
  var invalid = 0;
  for (final file in files) {
    if (limit > 0 && rows.length >= limit) break;
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      invalid++;
      continue;
    }
    final data = CharacterCardMapper.normalizeCardJson(decoded);
    if (data == null || (data['name']?.toString().isEmpty ?? true)) {
      invalid++;
      continue;
    }
    final id = file.uri.pathSegments.last.replaceAll(
      RegExp(r'\.json$', caseSensitive: false),
      '',
    );
    rows.add(
      CharacterCardMapper.cardToRow(
        data,
        characterId: id,
        avatarUrl: CharacterCardMapper.normalizeAvatar(data['avatar']),
      ),
    );
  }
  stdout.writeln(
    '[import] 解析完成: ${rows.length} 张有效卡, $invalid 张无效跳过',
  );
  if (rows.isEmpty) return;

  if (dryRun) {
    for (final r in rows.take(5)) {
      stdout.writeln(
        '[dry-run] ${r['id']} v${r['character_version']} "${r['name']}" '
        'avatar=${r['avatar_url'] ?? '-'} '
        'book=${r['character_book'] == '{}' || r['character_book'] == '[]' ? 'no' : 'yes'}',
      );
    }
    return;
  }

  // ---------- 写入阶段：分批事务 upsert ----------
  final db = AppDatabase.instance;
  await db.init();
  if (!db.isAvailable) {
    stderr.writeln('[import] PostgreSQL 不可用（见上方连接日志），导入中止');
    exitCode = 1;
    return;
  }
  final conn = (await db.connection)!;

  final watch = Stopwatch()..start();
  var done = 0;
  var failed = 0;
  for (var start = 0; start < rows.length; start += batchSize) {
    final batch = rows.sublist(
      start,
      start + batchSize > rows.length ? rows.length : start + batchSize,
    );
    try {
      await conn.runTx((session) async {
        for (final row in batch) {
          await session.execute(
            Sql.named(CharacterCardMapper.characterUpsertSql),
            parameters: row,
          );
        }
      });
      done += batch.length;
    } catch (e) {
      // 整批回滚后逐条重试，隔离坏行，其余照常入库
      for (final row in batch) {
        try {
          await conn.execute(
            Sql.named(CharacterCardMapper.characterUpsertSql),
            parameters: row,
          );
          done++;
        } catch (_) {
          failed++;
        }
      }
    }
    stdout.writeln(
      '[import] $done/${rows.length} 已写入'
      '${failed > 0 ? ', $failed 失败' : ''} '
      '(${watch.elapsedMilliseconds / 1000}s)',
    );
  }

  stdout.writeln(
    '[import] 完成: 成功 $done, 失败 $failed, 解析期跳过 $invalid, '
    '耗时 ${watch.elapsedMilliseconds / 1000}s',
  );
  // 不关闭连接的话，打开的 socket 会让脚本事件循环不退出
  await db.close();
  if (failed > 0) exitCode = 1;
}

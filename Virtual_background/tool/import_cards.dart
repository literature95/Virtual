import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/png_card_text.dart';

/// 角色卡批量导入工具（PNG 卡片 / JSON 卡片 → PostgreSQL characters 表）
///
/// 与 `POST /api/characters` 走同一条映射/落库链路（[CharacterCardMapper]），
/// 但不经过 HTTP，批量事务写入，适合数千至数万张的卡片数据集。
///
/// **PNG 卡**：从 `tEXt`/`zTXt`/`iTXt` 块解出内嵌 JSON（见 [extractPngCard]），
/// 并默认把**卡面图像本身**落盘为立绘 —— App 的角色墙据此显示头像。
/// **JSON 卡**：直接解析；若 `avatar` 是内嵌 data URL 则解码落盘，
/// 否则按既有规则透传（外链原样存，`none`/空 落 NULL）。
///
/// 用法（在 Virtual_background 目录下执行）：
/// ```sh
/// dart run tool/import_cards.dart <目录或文件> [选项]
/// ```
/// 选项：
/// - `--recursive`        递归子目录（PNG 卡库通常需要）
/// - `--limit=N`          只导入前 N 张有效卡（0 = 不限，默认 0）
/// - `--batch-size=N`     每个事务的写入条数（默认 100）
/// - `--no-avatar`        不落盘立绘（仅入库文本字段，App 走占位图）
/// - `--avatar-dir=PATH`  立绘落盘目录（默认 `public/uploads`）
/// - `--id-from=name|file` 角色 id 来源（默认 `name`：取卡内 name 的 slug）
/// - `--dry-run`          只解析校验，不写库也不落盘（不需要 PostgreSQL）
///
/// 身份规则：
/// - `character_id`：卡内 `name` 的 slug（保留中文），可用 `--id-from=file` 改为文件名
/// - `character_version`：卡内 `character_version`（缺失时 '1.0'）
/// - 立绘命名与 `POST /api/characters` 一致：`char-<id>-<version>.<ext>`
/// - 同 `(id, version)` 重复 = 覆盖（幂等，可安全重跑）；同名不同卡会互相覆盖，
///   运行结束会报告重复计数
Future<void> main(List<String> args) async {
  var target = '';
  var recursive = false;
  var limit = 0;
  var batchSize = 100;
  var dryRun = false;
  var copyAvatar = true;
  var avatarDir = 'public/uploads';
  var idFrom = 'name';

  for (final arg in args) {
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--recursive') {
      recursive = true;
    } else if (arg == '--no-avatar') {
      copyAvatar = false;
    } else if (arg.startsWith('--limit=')) {
      limit = int.tryParse(arg.substring(8)) ?? 0;
    } else if (arg.startsWith('--batch-size=')) {
      batchSize = int.tryParse(arg.substring(13)) ?? 100;
    } else if (arg.startsWith('--avatar-dir=')) {
      avatarDir = arg.substring(13);
    } else if (arg.startsWith('--id-from=')) {
      idFrom = arg.substring(10);
    } else if (!arg.startsWith('-')) {
      target = arg;
    }
  }
  if (target.isEmpty) {
    stderr.writeln(
      '用法: dart run tool/import_cards.dart <目录或文件> '
      '[--recursive] [--limit=N] [--batch-size=N] '
      '[--no-avatar] [--avatar-dir=PATH] [--id-from=name|file] [--dry-run]',
    );
    exitCode = 2;
    return;
  }
  if (idFrom != 'name' && idFrom != 'file') {
    stderr.writeln('--id-from 只支持 name 或 file，收到: $idFrom');
    exitCode = 2;
    return;
  }

  // ---------- 收集文件 ----------
  final List<File> files;
  final asFile = File(target);
  if (asFile.existsSync()) {
    files = [asFile];
  } else {
    final dir = Directory(target);
    if (!dir.existsSync()) {
      stderr.writeln('路径不存在: $target');
      exitCode = 2;
      return;
    }
    files = dir
        .listSync(recursive: recursive)
        .whereType<File>()
        .where((f) => _isSupported(f.path))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }
  stdout.writeln(
    '[import] 发现 ${files.length} 个候选文件于 $target'
    '${recursive ? '（含子目录）' : ''}',
  );

  // ---------- 解析阶段：文件 → data → DB 行 ----------
  final pending = <_PendingCard>[];
  final skipReasons = <String, int>{};
  final seen = <String>{};
  var duplicates = 0;

  void skip(String reason) =>
      skipReasons.update(reason, (v) => v + 1, ifAbsent: () => 1);

  for (final file in files) {
    if (limit > 0 && pending.length >= limit) break;

    Map<String, dynamic>? data;
    Uint8List? cardImage;
    String format;

    try {
      if (file.path.toLowerCase().endsWith('.png')) {
        final bytes = file.readAsBytesSync();
        final payload = extractPngCard(bytes);
        if (payload == null) {
          skip(
            hasPngSignature(bytes) ? 'PNG 无卡片文本块（疑似普通插画）' : '不是合法 PNG',
          );
          continue;
        }
        final decoded = jsonDecode(payload.json);
        data = CharacterCardMapper.normalizeCardJson(decoded);
        cardImage = bytes;
        format = 'PNG(${payload.keyword})';
      } else {
        final decoded = jsonDecode(file.readAsStringSync());
        data = CharacterCardMapper.normalizeCardJson(decoded);
        format = 'JSON';
      }
    } catch (_) {
      skip('文件读取或 JSON 解析失败');
      continue;
    }

    if (data == null) {
      skip('结构不是角色卡（缺 data / name）');
      continue;
    }
    final name = data['name']?.toString() ?? '';
    if (name.isEmpty) {
      skip('缺 name 字段');
      continue;
    }

    final id = idFrom == 'file'
        ? _fileStem(file.path)
        : CharacterCardMapper.slugify(name);
    final version = _resolveVersion(data);

    // 立绘决策：PNG 卡面 > 卡内 data URL > 卡内外链透传
    String? avatarUrl;
    Uint8List? pendingBytes;
    String? pendingName;
    final dataUrlExt = _dataUrlExt(data['avatar']);
    if (copyAvatar && cardImage != null) {
      pendingName = _avatarFileName(id, version, '.png');
      pendingBytes = cardImage;
      avatarUrl = '/uploads/$pendingName';
    } else if (copyAvatar && dataUrlExt != null) {
      final bytes = _decodeDataUrl(data['avatar']);
      if (bytes != null && bytes.isNotEmpty) {
        pendingName = _avatarFileName(id, version, dataUrlExt);
        pendingBytes = bytes;
        avatarUrl = '/uploads/$pendingName';
      }
    } else {
      avatarUrl = CharacterCardMapper.normalizeAvatar(data['avatar']);
    }

    final row = CharacterCardMapper.cardToRow(
      data,
      characterId: id,
      avatarUrl: avatarUrl,
    );

    if (!seen.add('${row['id']}\u0000${row['character_version']}')) {
      duplicates++;
    }
    pending.add(
      _PendingCard(
        row: row,
        source: file.path,
        format: format,
        avatarBytes: pendingBytes,
        avatarFile: pendingName,
      ),
    );
  }

  stdout.writeln('[import] 解析完成: ${pending.length} 张有效卡');
  if (duplicates > 0) {
    stdout.writeln('[import] $duplicates 张 (id,version) 重复，将互相覆盖');
  }
  for (final entry in skipReasons.entries) {
    stdout.writeln('[import] 跳过 ${entry.value} 个: ${entry.key}');
  }
  if (pending.isEmpty) return;

  if (dryRun) {
    for (final p in pending.take(5)) {
      final r = p.row;
      stdout.writeln(
        '[dry-run] ${r['id']} v${r['character_version']} '
        '"${r['name']}" <${p.format}> '
        'avatar=${r['avatar_url'] ?? '-'} '
        'book=${_hasBook(r) ? 'yes' : 'no'} '
        'ex=${_exampleCount(r)}',
      );
    }
    return;
  }

  // ---------- 立绘落盘（先写盘后入库；缺图不会让数据库指向不存在的文件） ----------
  var avatarsWritten = 0;
  var avatarsFailed = 0;
  if (copyAvatar && pending.any((p) => p.avatarBytes != null)) {
    final dir = Directory(avatarDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final p in pending) {
      final bytes = p.avatarBytes;
      final name = p.avatarFile;
      if (bytes == null || name == null) continue;
      try {
        File('$avatarDir/$name').writeAsBytesSync(bytes);
        avatarsWritten++;
      } catch (_) {
        avatarsFailed++;
      }
    }
    stdout.writeln(
      '[import] 立绘写入 $avatarsWritten 个到 $avatarDir'
      '${avatarsFailed > 0 ? ', $avatarsFailed 失败' : ''}',
    );
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
  for (var start = 0; start < pending.length; start += batchSize) {
    final end = start + batchSize > pending.length
        ? pending.length
        : start + batchSize;
    final batch = pending.sublist(start, end);
    try {
      await conn.runTx((session) async {
        for (final p in batch) {
          await session.execute(
            Sql.named(CharacterCardMapper.characterUpsertSql),
            parameters: p.row,
          );
        }
      });
      done += batch.length;
    } catch (_) {
      // 整批回滚后逐条重试，隔离坏行，其余照常入库
      for (final p in batch) {
        try {
          await conn.execute(
            Sql.named(CharacterCardMapper.characterUpsertSql),
            parameters: p.row,
          );
          done++;
        } catch (e) {
          failed++;
          stdout.writeln('[import] 失败 ${p.row['id']}: $e');
        }
      }
    }
    stdout.writeln(
      '[import] $done/${pending.length} 已写入'
      '${failed > 0 ? ', $failed 失败' : ''} '
      '(${watch.elapsedMilliseconds / 1000}s)',
    );
  }

  stdout.writeln(
    '[import] 完成: 成功 $done, 失败 $failed, 立绘 $avatarsWritten, '
    '耗时 ${watch.elapsedMilliseconds / 1000}s',
  );
  // 不关闭连接的话，打开的 socket 会让脚本事件循环不退出
  await db.close();
  if (failed > 0) exitCode = 1;
}

/// 待写入的一张卡（立绘字节与行分开存，便于 `--dry-run` 不产生副作用）
class _PendingCard {
  const _PendingCard({
    required this.row,
    required this.source,
    required this.format,
    this.avatarBytes,
    this.avatarFile,
  });

  final Map<String, dynamic> row;
  final String source;
  final String format;
  final Uint8List? avatarBytes;
  final String? avatarFile;
}

bool _isSupported(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.png') || p.endsWith('.json');
}

/// 版本决策与 [CharacterCardMapper.cardToRow] 保持一致，避免生成
/// `char-cricket-.png` 这类缺段文件名。
String _resolveVersion(Map<String, dynamic> data) {
  final v = data['character_version']?.toString().trim() ?? '';
  return v.isEmpty ? '1.0' : v;
}

/// 立绘落盘名，与 `POST /api/characters` 完全一致。
String _avatarFileName(String id, String version, String ext) =>
    'char-${CharacterCardMapper.sanitizeIdForFile(id)}-'
    '${CharacterCardMapper.sanitizeFilename(version)}$ext';

String _fileStem(String path) {
  final base = path.split(Platform.pathSeparator).last;
  final dot = base.lastIndexOf('.');
  return dot > 0 ? base.substring(0, dot) : base;
}

bool _hasBook(Map<String, dynamic> row) {
  final raw = row['character_book']?.toString() ?? '';
  return raw.isNotEmpty && raw != '{}' && raw != '[]';
}

int _exampleCount(Map<String, dynamic> row) {
  try {
    final list = jsonDecode(row['example_messages']?.toString() ?? '[]');
    return list is List ? list.length : 0;
  } catch (_) {
    return 0;
  }
}

// ---------------------------------------------------------------------------
// data URL 辅助（JSON 卡内嵌头像的解码）
// ---------------------------------------------------------------------------

final RegExp _dataUrlPattern = RegExp(
  r'^data:([^;,]+)(;base64)?,(.*)$',
  dotAll: true,
);

const Map<String, String> _extByMime = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
};

String? _dataUrlExt(dynamic avatar) {
  final match = _dataUrlPattern.firstMatch(avatar?.toString() ?? '');
  if (match == null) return null;
  return _extByMime[match.group(1)!.toLowerCase()];
}

Uint8List? _decodeDataUrl(dynamic avatar) {
  final match = _dataUrlPattern.firstMatch(avatar?.toString() ?? '');
  if (match == null) return null;
  final payload = match.group(3) ?? '';
  try {
    if (match.group(2) != null) {
      return Uint8List.fromList(base64Decode(payload));
    }
    // 非 base64 的 data URL 用百分号编码承载二进制（罕见但合法）
    return Uint8List.fromList(latin1.encode(Uri.decodeComponent(payload)));
  } catch (_) {
    return null;
  }
}

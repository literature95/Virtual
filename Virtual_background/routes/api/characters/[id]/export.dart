import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';
import 'package:virtual_background/path_param.dart';

/// GET /api/characters/[id]/export — 导出角色卡（CCv2 完整 spec 包）
///
/// round-trip 承诺的线上形态（docs/character-publish-design.md §2.3）：
/// - 上传过的角色：`raw_card` **原样吐回**（avatar 保留上传时的原值）
/// - 旧种子：由人设列重组（语义可读，非无损承诺范围）
/// - PG 不可用时仅支持种子角色
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  // dart_frog 不解码路径参数，含汉字的 id 会带 `%XX` 到达（见 path_param.dart）。
  final characterId = decodePathParam(id);

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  Map<String, dynamic>? row;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      final rows = await conn!.execute(
        // postgres 3.5：@命名参数必须经 Sql.named 解析，否则抛
        // "Maps are only supported by Sql.named"（驱动不解析裸字符串里的 @name）。
        Sql.named('''
SELECT id, name, description, personality, scenario, avatar_url, tags,
       first_message, example_messages, system_prompt, post_history_instructions,
       creator_notes, creator, character_version, source, alternate_greetings,
       group_only_greetings, extensions, character_book,
       creator_notes_multilingual, raw_card
  FROM characters WHERE id = @id
  ORDER BY updated_at DESC
  LIMIT 1'''),
        parameters: {'id': characterId},
      );
      if (rows.isNotEmpty) {
        row = rows.first.toColumnMap();
      }
    } catch (e) {
      // 降级到种子
    }
  }

  row ??= () {
    final c = SeedData.characters.firstWhere(
      (c) => c['id'] == characterId,
      orElse: () => <String, dynamic>{},
    );
    if (c.isEmpty) return null;
    // 种子行无 raw_card，补齐 rowToExportData 需要的键
    return <String, dynamic>{
      ...c,
      'first_message': c['first_message'] ?? c['first_mes'],
      'raw_card': null,
    };
  }();

  if (row == null) {
    return Response(statusCode: 404, body: 'Character not found');
  }

  final data = CharacterCardMapper.rowToExportData(row);
  final envelope = CharacterCardMapper.exportEnvelope(data);

  // 中文 id 经 sanitizeIdForFile 得到**唯一**的 ASCII 片段作保底文件名，
  // 再用 RFC 5987 的 filename* 让浏览器优先展示原始中文名（下载名不再坍缩成 `___`）。
  final safeId = CharacterCardMapper.sanitizeIdForFile(characterId);
  return Response.bytes(
    body: utf8.encode(jsonEncode(envelope)),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'content-disposition':
          'attachment; filename="$safeId.json"; '
          "filename*=UTF-8''${Uri.encodeComponent('$characterId.json')}",
    },
  );
}

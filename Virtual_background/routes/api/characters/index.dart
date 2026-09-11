import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import 'package:virtual_background/avatar_url.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/config.dart';
import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';

/// GET  /api/characters — 角色卡列表（按身份去重，只回最新版）
/// POST /api/characters — 发布角色卡（multipart：card + avatar，一次打完整包）
///
/// 发布协议见 docs/character-publish-design.md §2：
/// - `card`（form field）：CCv2/v3 完整 spec 包或裸 data 的 JSON 字符串
/// - `avatar`（form file，可选）：立绘，落 public/uploads/，DB 只存相对路径
/// - `character_id` / `character_version`（form field，可选）：覆盖身份/版本
/// - 版本优先级：请求字段 > 卡内 character_version > '1.0'
/// - 同 (id, version) 再发 = 覆盖；换版本号 = 新行
Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _onGet(context);
    case HttpMethod.post:
      return _onPost(context);
    case HttpMethod.put:
    case HttpMethod.delete:
    case HttpMethod.patch:
    case HttpMethod.head:
    case HttpMethod.options:
      return Response(statusCode: 405, body: 'Method Not Allowed');
  }
}

// ---------------------------------------------------------------------------
// GET：列表（DISTINCT ON 按身份去重，只回 updated_at 最新版）
// ---------------------------------------------------------------------------

Future<Response> _onGet(RequestContext context) async {
  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  List<Map<String, dynamic>> chars;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      final rows = await conn!.execute(
        'SELECT DISTINCT ON (id) id, name, description, avatar_url, tags, '
        'greeting, persona, creator, character_version '
        'FROM characters ORDER BY id, updated_at DESC',
      );
      chars = rows.map((row) {
        final r = row.toColumnMap();
        return {
          'id': r['id'],
          'name': r['name'],
          'description': r['description'],
          'avatar_url': r['avatar_url'],
          'tags': CharacterCardMapper.decodeJson<List<String>>(
            r['tags'],
            const [],
          ),
          'greeting': r['greeting'],
          'persona': r['persona'],
          'creator': r['creator'],
          'character_version': r['character_version'],
        };
      }).toList();
    } catch (e) {
      chars = SeedData.characters;
    }
  } else {
    chars = SeedData.characters;
  }

  final uri = context.request.uri;
  final summary = chars.map((c) {
    final raw = (c['avatar_url'] ?? c['avatarUrl'])?.toString();
    return CharacterCardMapper.toSummaryJson(
      c,
      avatarUrl: raw == null || raw.isEmpty ? null : resolveAvatarUrl(raw, uri),
    );
  }).toList();

  return Response.json(body: summary);
}

// ---------------------------------------------------------------------------
// POST：发布（multipart/form-data）
// ---------------------------------------------------------------------------

/// 立绘大小上限（防滥用）
const _maxAvatarBytes = 10 * 1024 * 1024;

/// content-type → 扩展名白名单
const _avatarExtByMime = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
};

Future<Response> _onPost(RequestContext context) async {
  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  // 1) 可选鉴权：配置 PUBLISH_TOKEN 后要求请求头匹配（本地默认开放）
  final token = AppConfig.publishToken;
  if (token.isNotEmpty && context.request.headers['x-api-token'] != token) {
    return Response(statusCode: 401, body: 'Unauthorized');
  }

  // 2) PG 不可用：内存种子无法持久化上传，明确拒绝
  if (!db.isAvailable) {
    return Response(
      statusCode: 503,
      body: 'Service Unavailable: PostgreSQL is required for publishing',
    );
  }

  // 3) multipart 解析
  final FormData form;
  try {
    form = await context.request.formData();
  } catch (_) {
    return Response(
      statusCode: 400,
      body: 'Bad Request: expected multipart/form-data',
    );
  }

  // 4) card 字段 → data
  final cardRaw = form.fields['card'];
  if (cardRaw == null || cardRaw.isEmpty) {
    return Response(statusCode: 400, body: 'Bad Request: missing "card" field');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(cardRaw);
  } catch (_) {
    return Response(
      statusCode: 400,
      body: 'Bad Request: "card" is not valid JSON',
    );
  }
  final data = CharacterCardMapper.normalizeCardJson(decoded);
  if (data == null || (data['name']?.toString().isEmpty ?? true)) {
    return Response(
      statusCode: 400,
      body: 'Bad Request: card must contain a non-empty "name"',
    );
  }

  // 5) 立绘落盘（先写盘后入库；写盘失败不入库）
  String? avatarUrl;
  final avatarFile = form.files['avatar'];
  if (avatarFile != null) {
    final ext = _avatarExtByMime[avatarFile.contentType.mimeType];
    if (ext == null) {
      return Response(
        statusCode: 415,
        body: 'Unsupported Media Type: avatar must be jpeg/png/webp/gif',
      );
    }
    final bytes = await avatarFile.readAsBytes();
    if (bytes.length > _maxAvatarBytes) {
      return Response(
        statusCode: 413,
        body: 'Payload Too Large: avatar > 10MB',
      );
    }

    final idForFile =
        CharacterCardMapper.cardToRow(
              data,
              characterId: form.fields['character_id'],
            )['id']
            as String;
    // 版本决策与 cardToRow 保持一致：field > 卡内 > '1.0'（避免空版本生成
    // `char-cricket-.jpg` 这类缺段文件名）
    final versionForFile =
        (form.fields['character_version']?.isNotEmpty ?? false)
        ? form.fields['character_version']!
        : ((data['character_version']?.toString().isNotEmpty ?? false)
              ? data['character_version'].toString()
              : '1.0');
    final filename =
        'char-${CharacterCardMapper.sanitizeIdForFile(idForFile)}-'
        '${CharacterCardMapper.sanitizeFilename(versionForFile)}$ext';

    try {
      final dir = Directory('public/uploads');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('public/uploads/$filename').writeAsBytesSync(bytes, flush: true);
    } catch (e) {
      return Response(
        statusCode: 500,
        body: 'Internal Error: failed to save avatar',
      );
    }
    avatarUrl = '/uploads/$filename';
  } else {
    // 未上传文件时回退到卡内 avatar 外链：原样透传（服务端不抓取，防 SSRF）。
    // 卡内没有或为 "none" 占位值则存 NULL，App 侧走占位图。
    avatarUrl = CharacterCardMapper.normalizeAvatar(data['avatar']);
  }

  // 6) 投影 + upsert
  final row = CharacterCardMapper.cardToRow(
    data,
    characterId: form.fields['character_id'],
    characterVersion: form.fields['character_version'],
    avatarUrl: avatarUrl,
  );
  final id = row['id'] as String;
  final version = row['character_version'] as String;

  final conn = (await db.connection)!;
  try {
    // 存在性判定决定 action（避免依赖 xmax 等驱动相关的 RETURNING 技巧）。
    // 注意：postgres 3.5 驱动必须用 Sql.named 解析 @命名参数，
    // 直接传 String + parameters 会抛 "Maps are only supported by Sql.named"。
    final existing = await conn.execute(
      Sql.named(
        'SELECT 1 FROM characters WHERE id = @id AND character_version = @v',
      ),
      parameters: {'id': id, 'v': version},
    );
    final existed = existing.isNotEmpty;

    // characterUpsertSql 的命名参数与 cardToRow 行键一一对应，行 map 直接绑定
    await conn.execute(
      Sql.named(CharacterCardMapper.characterUpsertSql),
      parameters: row,
    );

    return Response.json(
      statusCode: existed ? 200 : 201,
      body: {
        'id': id,
        'characterVersion': version,
        'avatarUrl': avatarUrl == null
            ? null
            : resolveAvatarUrl(avatarUrl, context.request.uri),
        'action': existed ? 'updated' : 'created',
      },
    );
  } catch (e) {
    return Response(statusCode: 500, body: 'Internal Error: $e');
  }
}

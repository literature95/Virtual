import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';

/// GET /api/characters/[id] — 角色卡详情
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  Map<String, dynamic>? result;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      final rows = await conn!.execute(
        'SELECT id, name, description, avatar_url, tags, greeting, first_message, persona FROM characters WHERE id = @id',
        parameters: {'id': id},
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final rawTags = row[4];
        var tags = <String>[];
        if (rawTags is String && rawTags.isNotEmpty) {
          final decoded = jsonDecode(rawTags);
          if (decoded is List) tags = decoded.map((e) => e.toString()).toList();
        } else if (rawTags is List) {
          tags = rawTags.map((e) => e.toString()).toList();
        }
        result = {
          'id': row[0],
          'name': row[1],
          'description': row[2],
          'avatarUrl': row[3],
          'tags': tags,
          'greeting': row[5],
          'firstMessage': row[6],
          'persona': row[7],
        };
      }
    } catch (e) {
      // 回退到内存
    }
  }

  result ??= SeedData.characters.firstWhere(
    (c) => c['id'] == id,
    orElse: () => <String, dynamic>{},
  );

  if (result.isEmpty || result['id'] == null) {
    return Response(statusCode: 404, body: 'Character not found');
  }

  return Response.json(body: result);
}

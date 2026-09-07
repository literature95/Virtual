import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';

/// GET /api/characters — 角色卡列表（精简字段，供 Web 卡片展示）
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  List<Map<String, dynamic>> chars;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      final rows = await conn!.execute(
        'SELECT id, name, description, avatar_url, tags FROM characters ORDER BY created_at',
      );
      chars = rows.map((row) {
        final rawTags = row[4];
        var tags = <String>[];
        if (rawTags is String && rawTags.isNotEmpty) {
          final decoded = jsonDecode(rawTags);
          if (decoded is List) tags = decoded.map((e) => e.toString()).toList();
        } else if (rawTags is List) {
          tags = rawTags.map((e) => e.toString()).toList();
        }
        return {
          'id': row[0]! as String,
          'name': row[1]! as String,
          'description': row[2] as String?,
          'avatar_url': row[3] as String?,
          'tags': tags,
        };
      }).toList();
    } catch (e) {
      chars = SeedData.characters;
    }
  } else {
    chars = SeedData.characters;
  }

  final summary = chars.map((c) => {
    'id': c['id'],
    'name': c['name'],
    'description': c['description'],
    'avatarUrl': c['avatar_url'] ?? c['avatarUrl'],
    'tags': c['tags'],
  }).toList();

  return Response.json(body: summary);
}

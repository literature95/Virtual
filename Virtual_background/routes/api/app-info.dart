import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';

/// GET /api/app-info — 应用介绍/下载信息
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  Map<String, dynamic> info;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      final rows = await conn!.execute(
        'SELECT id, name, version, description, features, download_url FROM app_info LIMIT 1',
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final featuresRaw = row[4];
        var features = <Map<String, dynamic>>[];
        if (featuresRaw is String && featuresRaw.isNotEmpty) {
          final decoded = jsonDecode(featuresRaw);
          if (decoded is List) {
            features = decoded.cast<Map<String, dynamic>>();
          }
        } else if (featuresRaw is List) {
          features = featuresRaw.cast<Map<String, dynamic>>();
        }
        info = {
          'id': row[0],
          'name': row[1],
          'version': row[2],
          'description': row[3],
          'features': features,
          'download_url': row[5],
        };
      } else {
        info = SeedData.appInfo;
      }
    } catch (e) {
      info = SeedData.appInfo;
    }
  } else {
    info = SeedData.appInfo;
  }

  final camelCase = {
    'id': info['id'],
    'name': info['name'],
    'version': info['version'],
    'description': info['description'],
    'features': info['features'],
    'downloadUrl': info['download_url'] ?? info['downloadUrl'],
  };

  return Response.json(body: camelCase);
}

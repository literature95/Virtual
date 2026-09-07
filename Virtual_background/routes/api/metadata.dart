import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/database/db.dart';
import 'package:virtual_background/database/seed.dart';

/// GET /api/metadata?ch=&lc=&pf=&version_code=&is_first_launch=
///
/// 返回格式：JSON 顶级数组，每项 {desc, id, name, obj, tag}
/// 与 App 端 AppMetadata.fromJsonList() 解析格式完全一致。
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final db = AppDatabase.instance;
  if (!db.isAvailable) await db.init();

  // DB 可用时从 DB 读，否则回退到内存种子
  List<Map<String, dynamic>> result;

  if (db.isAvailable) {
    try {
      final conn = await db.connection;
      final rows = await conn!.execute('SELECT payload FROM metadata ORDER BY id');
      final payloads = <Map<String, dynamic>>[];
      for (final row in rows) {
        final raw = row.first;
        if (raw is Map<String, dynamic>) {
          payloads.add(raw);
        } else if (raw is String) {
          payloads.add(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
      result = payloads.isNotEmpty ? payloads : SeedData.metadata;
    } catch (e) {
      result = SeedData.metadata;
    }
  } else {
    result = SeedData.metadata;
  }

  return Response.json(body: result);
}

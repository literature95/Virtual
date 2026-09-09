import 'package:dart_frog/dart_frog.dart';

import 'package:virtual_background/avatar_url.dart';
import 'package:virtual_background/banner_seed.dart';

/// GET /api/banners — 首页轮播位
///
/// 返回运营位列表（横版图 + 标题 + 关联角色）。
/// App 侧拿不到数据时直接不渲染轮播，不影响首页其余部分。
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final uri = context.request.uri;
  final banners = BannerSeed.items.map((b) {
    final raw = b['imageUrl']?.toString();
    return <String, dynamic>{
      'id': b['id'],
      'title': b['title'],
      'subtitle': b['subtitle'],
      'imageUrl': raw == null || raw.isEmpty ? null : resolveAvatarUrl(raw, uri),
      'characterId': b['characterId'],
    };
  }).toList();

  return Response.json(body: banners);
}

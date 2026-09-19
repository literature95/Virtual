import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual/models/community_post.dart';
import 'package:virtual/services/amap_location_service.dart';
import 'package:virtual/services/community_api_service.dart';

class _Rec implements HttpClientAdapter {
  _Rec({this.status = 200, this.body});

  final int status;
  final Object? body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    final s = body == null ? '' : jsonEncode(body);
    return ResponseBody.fromString(
      s,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CommunityPost.location', () {
    test('fromJson 解析 location', () {
      final p = CommunityPost.fromJson({
        'id': 'p1',
        'title': 't',
        'author': {'id': 'u', 'name': 'n'},
        'location': '上海市·徐汇区',
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(p.location, '上海市·徐汇区');
    });

    test('fromJson 缺省 location 为 null', () {
      final p = CommunityPost.fromJson({
        'id': 'p2',
        'title': 't',
        'author': {'id': 'u', 'name': 'n'},
      });
      expect(p.location, isNull);
    });
  });

  group('createPost 携带定位', () {
    test('请求 body 含 location，返回帖子带 location 字段', () async {
      final rec = _Rec(body: {
        'id': 'new-1',
        'createdAt': DateTime.utc(2026, 9, 18, 10).toIso8601String(),
      });
      final dio = Dio()..httpClientAdapter = rec;
      final svc = CommunityApiService(dio);

      final post = await svc.createPost(
        'http://127.0.0.1:8080',
        'token-x',
        title: '带位置的动态',
        content: '正文',
        community: '综合',
        location: {
          'name': '北京市·朝阳区',
          'address': '北京市朝阳区某处',
          'lat': 39.9,
          'lng': 116.4,
        },
      );

      final sent = (rec.last!.data as Map).cast<String, dynamic>();
      expect(sent['location'], isA<Map>());
      expect((sent['location'] as Map)['name'], '北京市·朝阳区');
      expect(post.location, '北京市·朝阳区');
      expect(post.id, 'new-1');
    });

    test('无 location 时不携带该字段', () async {
      final rec = _Rec(body: {
        'id': 'new-2',
        'createdAt': DateTime.utc(2026, 9, 18, 10).toIso8601String(),
      });
      final dio = Dio()..httpClientAdapter = rec;
      final svc = CommunityApiService(dio);

      final post = await svc.createPost(
        'http://127.0.0.1:8080',
        'token-x',
        title: '无位置',
      );
      final sent = (rec.last!.data as Map).cast<String, dynamic>();
      expect(sent.containsKey('location'), isFalse);
      expect(post.location, isNull);
    });
  });

  group('高德 Key 与隐私', () {
    test('Key 与包名约定一致', () {
      expect(AmapLocationService.amapKey,
          '59a835b927b9bb78abb1b93a8ee3e3b1');
      expect(AmapLocationService.amapKey, isNotEmpty);
    });

    test('隐私同意可写入并读回', () async {
      expect(await AmapLocationService.isPrivacyAccepted(), isFalse);
      await AmapLocationService.acceptPrivacy();
      expect(await AmapLocationService.isPrivacyAccepted(), isTrue);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/services/app_update_service.dart';

class _Rec implements HttpClientAdapter {
  _Rec(this.map);
  final Map<String, Object?> map;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(map),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('isNewerVersion：主版本与 build 号', () {
    expect(AppUpdateService.isNewerVersion('1.0.8+9', '1.0.7+8'), isTrue);
    expect(AppUpdateService.isNewerVersion('1.0.7+8', '1.0.8+9'), isFalse);
    expect(AppUpdateService.isNewerVersion('1.0.7+9', '1.0.7+8'), isTrue);
    expect(AppUpdateService.isNewerVersion('1.0.7+8', '1.0.7+8'), isFalse);
    expect(AppUpdateService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
  });

  test('version.json 优先解析', () async {
    final dio = Dio()..httpClientAdapter = _Rec({
          'version': '1.0.8+9',
          'downloadUrl': 'https://virtual.literature95.com/app-release.apk',
          'changes': ['定位', '全页发布'],
        });
    final info = await AppUpdateService(dio)
        .fetchLatest('https://virtual.literature95.com');
    expect(info, isNotNull);
    expect(info!.version, '1.0.8+9');
    expect(info.downloadUrl, contains('app-release.apk'));
    expect(info.changes, hasLength(2));
    expect(AppUpdateService.isNewerVersion(info.version, '1.0.7+8'), isTrue);
  });
}

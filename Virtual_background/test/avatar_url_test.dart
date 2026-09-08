import 'package:test/test.dart';
import 'package:virtual_background/avatar_url.dart';

void main() {
  group('resolveAvatarUrl', () {
    final req = Uri.parse('http://localhost:8080/api/characters');

    test('相对路径按请求来源补全为绝对 URL', () {
      expect(
        resolveAvatarUrl('/avatars/char-001.jpg', req),
        'http://localhost:8080/avatars/char-001.jpg',
      );
    });

    test('局域网地址请求保持其 host（真机调试场景）', () {
      final lanReq = Uri.parse('http://192.168.1.145:8080/api/characters');
      expect(
        resolveAvatarUrl('/avatars/char-001.jpg', lanReq),
        'http://192.168.1.145:8080/avatars/char-001.jpg',
      );
    });

    test('https 默认端口省略端口号', () {
      final httpsReq = Uri.parse('https://virtual.dev/api/characters');
      expect(
        resolveAvatarUrl('/avatars/char-001.jpg', httpsReq),
        'https://virtual.dev/avatars/char-001.jpg',
      );
    });

    test('外链 URL 原样透传', () {
      const external = 'https://cdn.example.com/a.png';
      expect(resolveAvatarUrl(external, req), external);
    });

    test('空值与空串返回空串', () {
      expect(resolveAvatarUrl(null, req), '');
      expect(resolveAvatarUrl('', req), '');
    });
  });
}

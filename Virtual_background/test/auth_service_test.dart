import 'package:test/test.dart';
import 'package:virtual_background/auth_service.dart';

/// 认证纯逻辑层测试（不依赖 PostgreSQL / SMTP）：
/// 哈希、JWT 会话、邮箱校验、验证码格式。
/// DB 交互（验证码存取/冷却/错误次数）与 SMTP 发信走本地联调验证。
void main() {
  group('密码哈希（bcrypt）', () {
    test('哈希可验证，且每次加盐结果不同', () {
      final h1 = AuthService.hashPassword('secret123');
      final h2 = AuthService.hashPassword('secret123');
      expect(h1, isNot(h2), reason: '随机盐应使同密码两次哈希不同');
      expect(AuthService.verifyPassword('secret123', h1), isTrue);
      expect(AuthService.verifyPassword('wrong', h1), isFalse);
    });
  });

  group('JWT 会话', () {
    test('签发后可验证并取回 sub', () {
      final token = AuthService.issueToken(
        '00000000-0000-0000-0000-000000000001',
        'user@test.dev',
      );
      expect(AuthService.verifyToken(token),
          '00000000-0000-0000-0000-000000000001');
    });

    test('篡改与垃圾 token 拒绝', () {
      final token = AuthService.issueToken('uid-1', 'user@test.dev');
      expect(AuthService.verifyToken('$token-x'), isNull);
      expect(AuthService.verifyToken('not-a-jwt'), isNull);
      expect(AuthService.verifyToken(''), isNull);
    });

    test('Bearer 头解析', () {
      final token = AuthService.issueToken('uid-42', 'user@test.dev');
      expect(
        AuthService.userIdFromHeaders({'authorization': 'Bearer $token'}),
        'uid-42',
      );
      expect(
        AuthService.userIdFromHeaders({'authorization': token}),
        isNull,
        reason: '缺少 Bearer 前缀不算认证',
      );
      expect(AuthService.userIdFromHeaders({}), isNull);
    });
  });

  group('邮箱与验证码', () {
    test('邮箱格式校验', () {
      expect(AuthService.isValidEmail('user@example.com'), isTrue);
      expect(AuthService.isValidEmail('a.b+c@sub.domain.cn'), isTrue);
      expect(AuthService.isValidEmail('no-at-sign.com'), isFalse);
      expect(AuthService.isValidEmail('a@b'), isFalse);
      expect(AuthService.isValidEmail('a b@c.com'), isFalse);
      expect(AuthService.isValidEmail(''), isFalse);
    });

    test('验证码为 6 位数字字符串', () {
      for (var i = 0; i < 20; i++) {
        final code = AuthService.generateCode();
        expect(code, matches(RegExp(r'^\d{6}$')));
        expect(int.parse(code), inInclusiveRange(100000, 999999));
      }
    });
  });
}

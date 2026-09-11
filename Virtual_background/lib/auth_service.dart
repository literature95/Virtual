import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart' show BCrypt;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:postgres/postgres.dart';

import 'config.dart';
import 'database/db.dart';

/// 邮箱账号认证：注册验证码 / 注册 / 登录 / JWT 会话
///
/// 降级策略与项目其他外部依赖一致：SMTP 未配置（SMTP_USER/SMTP_PASS 为空）
/// 时验证码不真实发信，打到服务端控制台并随接口下发 `devCode`，
/// 保证本地零配置即可跑通注册登录全流程。
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// JWT 密钥：环境变量固定 → 每次启动随机（重启后旧会话全部失效）
  static final SecretKey _jwtKey = () {
    final secret = AppConfig.jwtSecret;
    if (secret.isNotEmpty) return SecretKey(secret);
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    stderr.writeln(
      '[auth] JWT_SECRET 未配置，使用临时随机密钥（重启后所有登录态失效）',
    );
    return SecretKey(base64UrlEncode(bytes));
  }();

  static const _codeTtl = Duration(minutes: 10);
  static const _resendCooldown = Duration(seconds: 60);
  static const _maxAttempts = 5;

  // ── 邮箱与密码 ────────────────────────────────────────────

  /// 宽松但实用的邮箱格式校验（本地@域名.后缀）
  static bool isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  static String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt());

  static bool verifyPassword(String password, String hash) =>
      BCrypt.checkpw(password, hash);

  static String generateCode() =>
      (Random.secure().nextInt(900000) + 100000).toString();

  // ── JWT 会话 ─────────────────────────────────────────────

  static String issueToken(String userId, String email) => JWT({
        'sub': userId,
        'email': email,
      }).sign(_jwtKey, expiresIn: const Duration(days: 30));

  /// 校验通过返回 userId；无效/过期返回 null
  static String? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, _jwtKey);
      return (jwt.payload as Map)['sub']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// 从请求头解析 Bearer token → userId
  static String? userIdFromHeaders(Map<String, String> headers) {
    final auth = headers['authorization'] ?? '';
    if (!auth.toLowerCase().startsWith('bearer ')) return null;
    return verifyToken(auth.substring(7).trim());
  }

  // ── 验证码：存储与校验（DB，email+purpose 主键 upsert）──────

  /// 发码入口：60 秒重发冷却；SMTP 未配置时走控制台降级。
  /// 返回 (ok, devCode/error 提示)
  Future<(bool, String?)> sendCode(String email,
      {String purpose = 'register'}) async {
    final db = AppDatabase.instance;
    if (!db.isAvailable) await db.init();
    if (!db.isAvailable) return (false, '数据库不可用');

    final conn = (await db.connection)!;
    final existing = await conn.execute(
      Sql.named(
        'SELECT created_at FROM email_codes WHERE email = @e AND purpose = @p',
      ),
      parameters: {'e': email, 'p': purpose},
    );
    if (existing.isNotEmpty) {
      final last = existing.first.toColumnMap()['created_at'] as DateTime;
      final waited = DateTime.now().difference(last.toUtc());
      if (waited < _resendCooldown) {
        return (false, '发送太频繁，请 ${_resendCooldown.inSeconds - waited.inSeconds} 秒后重试');
      }
    }

    final code = generateCode();
    final result = await sendVerificationEmail(email, code);

    if (!result.$1) return (false, result.$2 ?? '邮件发送失败');

    await conn.execute(Sql.named('''
INSERT INTO email_codes (email, purpose, code, attempts, expires_at, created_at)
VALUES (@e, @p, @c, 0, @exp, NOW())
ON CONFLICT (email, purpose) DO UPDATE SET
  code = EXCLUDED.code, attempts = 0,
  expires_at = EXCLUDED.expires_at, created_at = NOW()
'''), parameters: {
      'e': email,
      'p': purpose,
      'c': code,
      'exp': DateTime.now().toUtc().add(_codeTtl),
    });
    // SMTP 未配置时 result.$2 是降级验证码（devCode），路由层决定是否下发
    return (true, result.$2);
  }

  /// 校验验证码：过期 / 错 5 次作废 / 正确即销毁
  Future<(bool, String?)> verifyCode(String email, String code,
      {String purpose = 'register'}) async {
    final db = AppDatabase.instance;
    if (!db.isAvailable) await db.init();
    if (!db.isAvailable) return (false, '数据库不可用');

    final conn = (await db.connection)!;
    final rows = await conn.execute(
      Sql.named(
        'SELECT code, attempts, expires_at FROM email_codes '
        'WHERE email = @e AND purpose = @p',
      ),
      parameters: {'e': email, 'p': purpose},
    );
    if (rows.isEmpty) return (false, '请先获取验证码');
    final row = rows.first.toColumnMap();
    if ((row['attempts'] as int? ?? 0) >= _maxAttempts) {
      return (false, '错误次数过多，请重新获取验证码');
    }
    if ((row['expires_at'] as DateTime).isBefore(DateTime.now().toUtc())) {
      return (false, '验证码已过期，请重新获取');
    }
    if (row['code'].toString() != code.trim()) {
      await conn.execute(
        Sql.named(
          'UPDATE email_codes SET attempts = attempts + 1 '
          'WHERE email = @e AND purpose = @p',
        ),
        parameters: {'e': email, 'p': purpose},
      );
      return (false, '验证码错误');
    }
    await conn.execute(
      Sql.named('DELETE FROM email_codes WHERE email = @e AND purpose = @p'),
      parameters: {'e': email, 'p': purpose},
    );
    return (true, null);
  }

  // ── 用户 ─────────────────────────────────────────────────

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final db = AppDatabase.instance;
    if (!db.isAvailable) await db.init();
    if (!db.isAvailable) return null;
    final conn = (await db.connection)!;
    final rows = await conn.execute(
      Sql.named('SELECT * FROM users WHERE email = @e'),
      parameters: {'e': email},
    );
    if (rows.isEmpty) return null;
    return rows.first.toColumnMap();
  }

  Future<Map<String, dynamic>?> findUserById(String id) async {
    final db = AppDatabase.instance;
    if (!db.isAvailable) await db.init();
    if (!db.isAvailable) return null;
    final conn = (await db.connection)!;
    final rows = await conn.execute(
      Sql.named('SELECT * FROM users WHERE id = @i::uuid'),
      parameters: {'i': id},
    );
    if (rows.isEmpty) return null;
    return rows.first.toColumnMap();
  }

  /// 注册：返回用户行；邮箱已存在返回 null（路由层转 409）
  Future<Map<String, dynamic>?> registerUser(
      String email, String password, String? nickname) async {
    if (await findUserByEmail(email) != null) return null;
    final db = AppDatabase.instance;
    final conn = (await db.connection)!;
    final rows = await conn.execute(Sql.named('''
INSERT INTO users (email, password_hash, nickname)
VALUES (@e, @h, @n)
RETURNING *'''), parameters: {
      'e': email,
      'h': hashPassword(password),
      'n': (nickname == null || nickname.trim().isEmpty)
          ? 'Virtual 用户'
          : nickname.trim(),
    });
    return rows.first.toColumnMap();
  }

  /// 对外输出的用户字段（绝不含 password_hash）
  static Map<String, dynamic> publicUser(Map<String, dynamic> row) => {
        'id': row['id'].toString(),
        'email': row['email'],
        'nickname': row['nickname'],
        'avatarUrl': row['avatar_url'],
        'createdAt': (row['created_at'] as DateTime?)?.toIso8601String(),
      };

  // ── 发信（SMTP，未配置时控制台降级）────────────────────────

  /// 返回 (成功, 说明)。成功且 SMTP 未配置时说明=验证码本身（devCode，
  /// 路由层随响应回给调用方，本地零配置可跑通）；成功且已发信时为 null；
  /// 失败时为错误提示。
  Future<(bool, String?)> sendVerificationEmail(String to, String code) async {
    if (!AppConfig.smtpConfigured) {
      stderr.writeln('[auth] SMTP 未配置，验证码降级输出 → $to: $code');
      return (true, code);
    }
    final smtp = SmtpServer(
      AppConfig.smtpHost,
      port: AppConfig.smtpPort,
      ssl: AppConfig.smtpPort == 465,
      username: AppConfig.smtpUser,
      password: AppConfig.smtpPass,
    );
    final message = Message()
      ..from = Address(AppConfig.smtpFrom, 'Virtual')
      ..recipients.add(to)
      ..subject = 'Virtual 注册验证码：$code'
      ..text = '你的验证码是 $code，10 分钟内有效。若非本人操作请忽略本邮件。';
    try {
      // mailer 7.x：失败直接抛异常，成功返回 SendReport
      await send(message, smtp);
      return (true, null);
    } catch (e) {
      stderr.writeln('[auth] 邮件发送失败: $e');
      return (false, '邮件发送失败，请检查 SMTP 配置');
    }
  }
}

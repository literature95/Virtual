/// 后端配置
///
/// 端口固定 8080，数据库可通过环境变量覆盖。
///
/// 敏感配置（DB 密码 / SMTP 授权码 / JWT 密钥）统一走
/// 「运行时环境变量优先，编译期 --dart-define 兜底」：
/// 本地开发 `PowerShell: $env:SMTP_PASS='xxx'` 后启动即可，密钥不进代码库。
library;

import 'dart:io';

class AppConfig {
  AppConfig._();

  static const int port = 8080;

  /// 运行时环境变量优先，其次编译期 --dart-define 注入值
  static String env(String name, String compileTimeValue,
          {String? defaultValue}) =>
      (Platform.environment[name] ?? '').isNotEmpty
          ? Platform.environment[name]!
          : (compileTimeValue.isNotEmpty
              ? compileTimeValue
              : (defaultValue ?? ''));

  // PostgreSQL（未安装时可忽略，走降级策略）
  static final String dbHost = env('DB_HOST', const String.fromEnvironment(
    'DB_HOST',
    defaultValue: 'localhost',
  ));
  static final int dbPort = int.tryParse(
        env('DB_PORT', const String.fromEnvironment('DB_PORT'),
            defaultValue: '5432'),
      ) ??
      5432;
  static final String dbName = env('DB_NAME', const String.fromEnvironment(
    'DB_NAME',
    defaultValue: 'virtual',
  ));
  static final String dbUser = env('DB_USER', const String.fromEnvironment(
    'DB_USER',
    defaultValue: 'postgres',
  ));
  static final String dbPassword = env('DB_PASSWORD',
      const String.fromEnvironment('DB_PASSWORD', defaultValue: 'postgres'));

  /// 发布接口可选令牌（docs/character-publish-design.md §2.4）：
  /// 配置后，POST /api/characters 需携带请求头 X-Api-Token: <值>；
  /// 未配置时接口不校验（本地开发零门槛）。
  static final String publishToken = env(
    'PUBLISH_TOKEN',
    const String.fromEnvironment('PUBLISH_TOKEN'),
  );

  // ── SMTP 邮件（邮箱验证码）──
  // QQ 邮箱示例：host=smtp.qq.com，port=465（SSL），
  // user=QQ 邮箱地址，pass=设置账户里生成的「授权码」（非 QQ 密码）。
  static final String smtpHost = env('SMTP_HOST',
      const String.fromEnvironment('SMTP_HOST'),
      defaultValue: 'smtp.qq.com');
  static final int smtpPort = int.tryParse(env(
        'SMTP_PORT',
        const String.fromEnvironment('SMTP_PORT'),
        defaultValue: '465',
      )) ??
      465;
  static final String smtpUser = env('SMTP_USER',
      const String.fromEnvironment('SMTP_USER'));
  static final String smtpPass = env('SMTP_PASS',
      const String.fromEnvironment('SMTP_PASS'));
  /// 发件人显示地址；未单独配置时与登录账号一致
  static final String smtpFrom = env('SMTP_FROM',
      const String.fromEnvironment('SMTP_FROM'),
      defaultValue: smtpUser);

  /// SMTP 是否已配置（决定验证码走真实发信还是控制台降级）
  static bool get smtpConfigured => smtpUser.isNotEmpty && smtpPass.isNotEmpty;

  // ── JWT 会话签名 ──
  // 未配置时每次启动随机生成（重启后所有已登录会话失效，开发可接受）；
  // 生产部署务必固定 JWT_SECRET。
  static final String jwtSecret = env('JWT_SECRET',
      const String.fromEnvironment('JWT_SECRET'));
}

/// 后端配置
///
/// 端口固定 8080，数据库可通过环境变量覆盖。
class AppConfig {
  AppConfig._();

  static const int port = 8080;

  // PostgreSQL（未安装时可忽略，走降级策略）
  static const String dbHost = String.fromEnvironment('DB_HOST', defaultValue: 'localhost');
  static const int dbPort = int.fromEnvironment('DB_PORT', defaultValue: 5432);
  static const String dbName = String.fromEnvironment('DB_NAME', defaultValue: 'virtual');
  static const String dbUser = String.fromEnvironment('DB_USER', defaultValue: 'postgres');
  static const String dbPassword = String.fromEnvironment('DB_PASSWORD', defaultValue: 'postgres');
}

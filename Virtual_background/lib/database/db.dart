import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:virtual_background/config.dart';

/// PostgreSQL 连接管理器
///
/// 采用降级策略：DB 连接失败时 isAvailable = false，调用方应走内存数据。
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Connection? _conn;
  bool _isAvailable = false;
  bool _initialized = false;

  bool get isAvailable => _isAvailable;

  Future<Connection?> get connection async {
    if (!_initialized) await init();
    return _conn;
  }

  /// 初始化（尝试连接，失败则降级）
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _conn = await Connection.open(
        Endpoint(
          host: AppConfig.dbHost,
          port: AppConfig.dbPort,
          database: AppConfig.dbName,
          username: AppConfig.dbUser,
          password: AppConfig.dbPassword,
        ),
        settings: const ConnectionSettings(
          sslMode: SslMode.disable,
        ),
      ).timeout(const Duration(seconds: 3));

      await _ensureTables();
      _isAvailable = true;
      stderr.writeln('[Virtual_background] PostgreSQL connected');
    } catch (e) {
      _isAvailable = false;
      stderr.writeln('[Virtual_background] PostgreSQL unavailable: $e (degraded to memory)');
    }
  }

  Future<void> close() async {
    await _conn?.close();
  }

  /// 确保表存在
  Future<void> _ensureTables() async {
    final conn = _conn!;
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS characters (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        avatar_url TEXT,
        tags JSONB DEFAULT '[]',
        greeting TEXT,
        first_message TEXT,
        persona TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS app_info (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        version TEXT,
        description TEXT,
        features JSONB DEFAULT '[]',
        download_url TEXT,
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        id TEXT PRIMARY KEY,
        payload JSONB NOT NULL,
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');
  }
}

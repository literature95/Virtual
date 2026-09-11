import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:virtual_background/config.dart';
// 延迟导入：seed.dart 反向依赖 db.dart（循环），延迟加载可打破初始化顺序耦合，
// 且种子数据（大量角色卡文案）只在真正需要落库时才载入内存。
import 'seed.dart' deferred as seed;

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
      await _seedIfEmpty();
    } catch (e) {
      _isAvailable = false;
      stderr.writeln(
        '[Virtual_background] PostgreSQL unavailable: $e (degraded to memory)',
      );
    }
  }

  /// 空库首次启动时灌入内置种子角色
  ///
  /// 只在 characters 表为空时执行：用户已上传过角色就不再灌，
  /// 避免每次启动把已删除的 demo 数据复活。
  Future<void> _seedIfEmpty() async {
    try {
      final rows = await _conn!.execute('SELECT COUNT(*) AS c FROM characters');
      final count = rows.first.toColumnMap()['c'];
      if (count is num && count > 0) return;
      await seed.loadLibrary();
      await seed.SeedData.instance.writeToDb();
      stderr.writeln(
        '[Virtual_background] seeded characters into empty database',
      );
    } catch (e) {
      stderr.writeln('[Virtual_background] seed skipped: $e');
    }
  }

  Future<void> close() async {
    await _conn?.close();
  }

  /// characters 表的增量列脚本（`ADD COLUMN IF NOT EXISTS`，可重复执行）
  ///
  /// 对齐 `Virtual_app/lib/models/character.dart` 的角色卡字段集：
  /// 长结构化数据一律 JSONB，避免为每个字段单独建模。
  static // 说明：新列不设 DEFAULT —— 旧行即为 NULL，由 CharacterCardMapper 统一兜底为空数组/空
  // 对象，避免把默认值这类无关细节写进 SQL 字符串。
  const List<String> _characterColumnMigrations = [
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS nickname TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS personality TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS scenario TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS example_messages JSONB',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS system_prompt TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS post_history_instructions TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS creator_notes TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS creator TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS character_version TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS source TEXT',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS alternate_greetings JSONB',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS group_only_greetings JSONB',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS extensions JSONB',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS creator_notes_multilingual JSONB',
    // --- 角色发布协议 §1（docs/character-publish-design.md）---
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS character_book JSONB',
    'ALTER TABLE characters ADD COLUMN IF NOT EXISTS raw_card JSONB',
  ];

  /// 确保表存在
  Future<void> _ensureTables() async {
    final conn = _conn!;
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS characters (
        id TEXT NOT NULL,
        character_version TEXT NOT NULL DEFAULT '1.0',
        name TEXT NOT NULL,
        description TEXT,
        avatar_url TEXT,
        tags JSONB DEFAULT '[]',
        greeting TEXT,
        first_message TEXT,
        persona TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (id, character_version)
      )
    ''');
    // --- 角色卡字段扩展（幂等，适配 2026-09-08 之前的旧库） ---
    //
    // 目标：让后端能完整承载 Character Card v2/v3 的结构化人设，
    // 而不是只存一句 persona —— 参见 docs/project-analysis-2026-09-08.md R-1。
    for (final migration in _characterColumnMigrations) {
      await conn.execute(migration);
    }
    // --- 角色发布协议 §1 迁移（幂等） ---
    // 1) 旧行版本回填：复合主键对 NULL 不去重，必须先消除 NULL
    await conn.execute(
      "UPDATE characters SET character_version = '1.0' WHERE character_version IS NULL",
    );
    // 2) 旧库 PK 在 id 上 → 切到复合主键 (id, character_version)；
    //    新库（上方 CREATE TABLE）已是复合主键，跳过。
    await conn.execute(r'''
      DO $$
      DECLARE def TEXT;
      BEGIN
        SELECT pg_get_constraintdef(oid) INTO def
          FROM pg_constraint WHERE conname = 'characters_pkey';
        IF def IS NOT NULL AND def NOT LIKE '%character_version%' THEN
          ALTER TABLE characters DROP CONSTRAINT characters_pkey;
          ALTER TABLE characters ADD PRIMARY KEY (id, character_version);
        END IF;
      END $$;
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
    // --- 账号体系（邮箱注册 + 验证码，见 lib/auth/）---
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        nickname TEXT,
        avatar_url TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS email_codes (
        email TEXT NOT NULL,
        purpose TEXT NOT NULL DEFAULT 'register',
        code TEXT NOT NULL,
        attempts INT NOT NULL DEFAULT 0,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (email, purpose)
      )
    ''');
  }
}

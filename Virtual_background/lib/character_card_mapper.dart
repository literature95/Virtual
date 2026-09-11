import 'dart:convert';

import 'package:virtual_background/mes_example_parser.dart';

/// 种子角色卡 → API 输出 / 数据库行的双向映射
///
/// 单一事实来源（single source of truth）：
/// - 种子数据里统一使用 **CCv3 snake_case**（与 Character Card 规范一致，
///   便于直接导入 App 而无需二次改名）
/// - 对外 API 统一输出 **camelCase**（与 App `OnlineCharacter` 解析保持一致，
///   App 侧解析逻辑零改动）
class CharacterCardMapper {
  const CharacterCardMapper._();

  /// API 输出的角色卡字段（camelCase 顺序与现有字段保持一致，向后兼容）
  static Map<String, dynamic> toApiJson(
    Map<String, dynamic> c, {
    String? avatarUrl,
  }) {
    return {
      'id': c['id'],
      'name': c['name'],
      'description': c['description'],
      'avatarUrl': avatarUrl ?? c['avatar_url'] ?? c['avatarUrl'],
      'tags': c['tags'] ?? const <String>[],
      // 兼容旧字段
      'greeting': c['greeting'] ?? c['first_mes'],
      'persona': c['persona'],
      // 完整角色卡字段（CCv3 对齐）
      'nickname': c['nickname'],
      'firstMessage': c['first_mes'] ?? c['firstMessage'],
      'personality': c['personality'],
      'scenario': c['scenario'],
      'systemPrompt': c['system_prompt'],
      'postHistoryInstructions': c['post_history_instructions'],
      'creatorNotes': c['creator_notes'],
      'creator': c['creator'],
      'characterVersion': c['character_version'],
      'source': c['source'],
      'alternateGreetings': c['alternate_greetings'] ?? const <String>[],
      'groupOnlyGreetings': c['group_only_greetings'] ?? const <String>[],
      'exampleMessages': c['example_messages'] ?? const <dynamic>[],
      'extensions': c['extensions'] ?? const <String, dynamic>{},
      'creatorNotesMultilingual':
          c['creator_notes_multilingual'] ?? const <String, String>{},
    };
  }

  /// 列表端精简字段：只保留卡片墙需要的内容，避免 example_messages 打到面板上
  static Map<String, dynamic> toSummaryJson(
    Map<String, dynamic> c, {
    String? avatarUrl,
  }) {
    return {
      'id': c['id'],
      'name': c['name'],
      'description': c['description'],
      'avatarUrl': avatarUrl ?? c['avatar_url'] ?? c['avatarUrl'],
      'tags': c['tags'] ?? const <String>[],
      'greeting': c['greeting'] ?? c['first_mes'],
      'persona': c['persona'],
      'creator': c['creator'],
      'characterVersion': c['character_version'],
    };
  }

  /// JSON → JSONB 字符串（PostgreSQL 参数绑定用）
  static String jsonb(Object? value) => jsonEncode(value ?? const []);

  /// JSONB / JSON 字符串 → Dart 对象
  ///
  /// postgres 驱动在部分情况下返回 `Map`/`List`，另一些情况返回字符串，
  /// 这里统一兜住，路由层不再各自实现解析。
  static T decodeJson<T>(dynamic raw, T fallback) {
    if (raw == null) return fallback;
    dynamic value = raw;
    if (raw is String) {
      if (raw.isEmpty) return fallback;
      try {
        value = jsonDecode(raw);
      } catch (_) {
        return fallback;
      }
    }
    if (value is T) return value;
    if (T == List<String>) {
      if (value is List) return value.map((e) => e.toString()).toList() as T;
    }
    if (T == Map<String, String>) {
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v.toString())) as T;
      }
    }
    return fallback;
  }

  // ------------------------------------------------------------------
  // 角色卡上传/导出（round-trip），见 docs/character-publish-design.md §1/§2
  // ------------------------------------------------------------------

  /// 兼容两种上传形态：完整 spec 包 `{spec, spec_version, data}` 或裸 `data`。
  /// 返回 data map；非法输入返回 null。
  static Map<String, dynamic>? normalizeCardJson(dynamic decoded) {
    if (decoded is! Map) return null;
    final data = decoded['data'];
    if (data is Map) {
      // 完整包：spec 校验宽松（v2/v3 均收）
      return Map<String, dynamic>.from(data);
    }
    // 裸 data：必须至少有 name 才认定为卡
    if (decoded['name'] is String && (decoded['name'] as String).isNotEmpty) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  /// 卡内 avatar 字段 → 可入库的头像值。
  ///
  /// 第三方卡片常用 `"none"`（及空串）表示「无立绘」，这类占位值必须落
  /// NULL，否则会被当成相对路径透传给客户端去加载不存在的图片。
  static String? normalizeAvatar(dynamic value) {
    final s = value?.toString().trim() ?? '';
    if (s.isEmpty || s.toLowerCase() == 'none') return null;
    return s;
  }

  /// 角色身份默认值：客户端未传 character_id 时由 name 生成 slug。
  static String slugify(String name) {
    final s = name.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_\-\u4e00-\u9fff]+'),
      '-',
    );
    return s.isEmpty ? 'character' : s;
  }

  /// 文件名/路径安全：非 `[a-zA-Z0-9_-]` 一律替换为 `_`。
  static String sanitizeFilename(String part) =>
      part.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

  /// 角色 id → 文件名片段（用于立绘落盘名）。
  ///
  /// [slugify] **故意保留汉字**（id 可能就是 `希露妲`），而文件名片段要跨平台安全，
  /// 只靠 [sanitizeFilename] 会把任意纯中文 id 都净化成同一个 `___` ——
  /// 于是不同中文名、同版本的卡片会写到同一路径，**后者覆盖前者立绘**。
  /// 因此在净化确实改写了原串时，追加原串的 FNV-1a 短哈希以保唯一。
  ///
  /// 纯 ASCII 且合法的 id（如 `char-001`）净化前后相同，**不加哈希**，
  /// 保持既有文件名与 URL 不变。
  static String sanitizeIdForFile(String id) {
    final safe = sanitizeFilename(id);
    return safe == id ? safe : '${safe}_${fnv1a8(id)}';
  }

  /// FNV-1a（32 位）对 UTF-8 字节取哈希，输出 8 位小写十六进制。
  ///
  /// 选它是因为**免第三方依赖且跨进程/跨版本确定**（`String.hashCode` 不保证稳定），
  /// 用于文件名去重足够。冲突概率 2^-32，失败模式仅是立绘互相覆盖，可接受。
  static String fnv1a8(String s) {
    var hash = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// characters 表 upsert 语句（POST /api/characters 与 tool/import_cards.dart 共用）。
  ///
  /// 命名参数与 [cardToRow] 返回的行键一一对应，行 map 可直接作 parameters。
  /// 同 (id, character_version) 覆盖；avatar_url 用 COALESCE 保留旧值兜底。
  static const String characterUpsertSql = '''
INSERT INTO characters (
                id, character_version, name, nickname, description, personality,
                scenario, first_message, system_prompt, post_history_instructions,
                creator_notes, creator, source, avatar_url, tags,
                alternate_greetings, group_only_greetings, example_messages,
                creator_notes_multilingual, extensions, character_book, raw_card
            )
            VALUES (
                @id, @character_version, @name, @nickname, @description, @personality,
                @scenario, @first_message, @system_prompt, @post_history_instructions,
                @creator_notes, @creator, @source, @avatar_url, @tags::jsonb,
                @alternate_greetings::jsonb, @group_only_greetings::jsonb,
                @example_messages::jsonb, @creator_notes_multilingual::jsonb,
                @extensions::jsonb, @character_book::jsonb, @raw_card::jsonb
            )
            ON CONFLICT (id, character_version) DO UPDATE SET
              name = EXCLUDED.name, nickname = EXCLUDED.nickname,
              description = EXCLUDED.description,
              personality = EXCLUDED.personality, scenario = EXCLUDED.scenario,
              first_message = EXCLUDED.first_message,
              system_prompt = EXCLUDED.system_prompt,
              post_history_instructions = EXCLUDED.post_history_instructions,
              creator_notes = EXCLUDED.creator_notes, creator = EXCLUDED.creator,
              source = EXCLUDED.source,
              avatar_url = COALESCE(EXCLUDED.avatar_url, characters.avatar_url),
              tags = EXCLUDED.tags,
              alternate_greetings = EXCLUDED.alternate_greetings,
              group_only_greetings = EXCLUDED.group_only_greetings,
              example_messages = EXCLUDED.example_messages,
              creator_notes_multilingual = EXCLUDED.creator_notes_multilingual,
              extensions = EXCLUDED.extensions,
              character_book = EXCLUDED.character_book,
              raw_card = EXCLUDED.raw_card,
              updated_at = NOW()''';

  /// CCv2 `data` → DB 行（POST /api/characters 写入用）。
  ///
  /// - `raw_card` 键存 `data` **原样**（round-trip 单一事实来源，禁止任何转换）
  /// - 人设列是投影，服务现有 GET 输出（App OnlineCharacter 消费形态）
  /// - JSONB 列的值已用 `jsonb()` 编码为字符串，可直接参数绑定
  static Map<String, dynamic> cardToRow(
    Map<String, dynamic> data, {
    String? characterId,
    String? characterVersion,
    String? avatarUrl,
  }) {
    final name = data['name']?.toString() ?? '';
    // 版本决策优先级：请求字段 > 卡内 character_version > '1.0'
    final passedVersion = characterVersion?.trim();
    final cardVersion = data['character_version']?.toString().trim() ?? '';
    final version = (passedVersion != null && passedVersion.isNotEmpty)
        ? passedVersion
        : cardVersion.isNotEmpty
        ? cardVersion
        : '1.0';

    return <String, dynamic>{
      'id': characterId ?? slugify(name),
      'character_version': version,
      'name': name,
      'nickname': data['nickname']?.toString(),
      'description': data['description']?.toString(),
      'personality': data['personality']?.toString(),
      'scenario': data['scenario']?.toString(),
      'first_message': data['first_mes']?.toString(),
      'system_prompt': data['system_prompt']?.toString(),
      'post_history_instructions': data['post_history_instructions']
          ?.toString(),
      'creator_notes': data['creator_notes']?.toString(),
      'creator': data['creator']?.toString(),
      'source': 'Character Card upload',
      'avatar_url': avatarUrl,
      'tags': jsonb(data['tags'] ?? const []),
      'alternate_greetings': jsonb(data['alternate_greetings'] ?? const []),
      'group_only_greetings': jsonb(data['group_only_greetings'] ?? const []),
      'example_messages': jsonb(
        parseMesExample(data['mes_example'], charName: name),
      ),
      'creator_notes_multilingual': jsonb(
        data['creator_notes_multilingual'] ?? const {},
      ),
      'extensions': jsonb(data['extensions'] ?? const {}),
      'character_book': jsonb(data['character_book'] ?? const {}),
      'raw_card': jsonb(data),
    };
  }

  /// DB 行 → CCv2 `data`（导出用）。
  ///
  /// - `raw_card` 非空：**原样吐回**（唯一事实来源；avatar 保留上传时的原值）
  /// - `raw_card` 为 NULL（旧种子）：由人设列重组（语义可读，非无损承诺范围）
  static Map<String, dynamic> rowToExportData(Map<String, dynamic> row) {
    final raw = decodeJson<Map<String, dynamic>>(row['raw_card'], const {});
    if (raw.isNotEmpty) return raw;

    // 列重组路径（种子角色）
    final pairs = decodeJson<List<dynamic>>(row['example_messages'], const []);
    return <String, dynamic>{
      'name': row['name']?.toString() ?? '',
      'description': row['description']?.toString() ?? '',
      'personality': row['personality']?.toString() ?? '',
      'scenario': row['scenario']?.toString() ?? '',
      'first_mes': row['first_message']?.toString() ?? '',
      'mes_example': examplePairsToMesExample(pairs),
      'creator_notes': row['creator_notes']?.toString() ?? '',
      'system_prompt': row['system_prompt']?.toString() ?? '',
      'post_history_instructions':
          row['post_history_instructions']?.toString() ?? '',
      'creator': row['creator']?.toString() ?? '',
      'character_version': row['character_version']?.toString() ?? '1.0',
      'source': row['source']?.toString(),
      'avatar': row['avatar_url']?.toString(),
      'tags': decodeJson<List<dynamic>>(row['tags'], const []),
      'alternate_greetings': decodeJson<List<dynamic>>(
        row['alternate_greetings'],
        const [],
      ),
      'group_only_greetings': decodeJson<List<dynamic>>(
        row['group_only_greetings'],
        const [],
      ),
      'extensions': decodeJson<Map<String, dynamic>>(
        row['extensions'],
        const {},
      ),
      'character_book': decodeJson<Map<String, dynamic>>(
        row['character_book'],
        const {},
      ),
      'creator_notes_multilingual': decodeJson<Map<String, dynamic>>(
        row['creator_notes_multilingual'],
        const {},
      ),
    };
  }

  /// 导出端响应体：完整 CCv2 spec 包。
  static Map<String, dynamic> exportEnvelope(Map<String, dynamic> data) => {
    'spec': 'chara_card_v2',
    'spec_version': '2.0',
    'data': data,
  };

  /// 递归排序键后 jsonEncode —— deep-diff 用规范化形态（键序无关比较）。
  static String canonicalJson(Object? value) {
    const encoder = JsonEncoder.withIndent('', _toCanonical);
    return encoder.convert(value);
  }

  static Object? _toCanonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final k in keys) k: _toCanonical(value[k]),
      };
    }
    if (value is List) return value.map(_toCanonical).toList();
    return value;
  }
}

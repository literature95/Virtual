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

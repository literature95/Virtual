import 'dart:convert';

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
}

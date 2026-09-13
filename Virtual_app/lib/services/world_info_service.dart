import 'dart:math';

import '../models/lorebook.dart';

/// 世界书（Lorebook / World Info）激活与注入
///
/// 角色卡启用时，卡上的世界书必须**绑定**进对话 Prompt 并随**切换角色
/// 而切换**（此前 `character.lorebookId` 只在编辑页展示，从未进入 Prompt
/// 组装 —— 对「角色全在世界书里」的卡等于全部设定丢失）。
///
/// 匹配规则对齐 SillyTavern World Info 的核心语义：
/// - `constant: true` 恒注入，不做关键词匹配
/// - 其余条目：主关键词命中最近 [scanDepth] 条消息即触发
/// - `selective: true`（AND_ALL）：次要关键词需**全部**命中
/// - `probability` < 100 时按概率掷骰（每条独立）
/// - 预算 `tokenBudget` > 0 时按优先级截断（1 token ≈ 2 字符的粗估）
///
/// 本服务是**纯函数**：不读库、不碰 dart:io，输入条目与消息文本，输出
/// 注入块，便于测试与未来接入递归扫描（recursive scanning）。
class WorldInfoService {
  /// 未设置 scan_depth 时的默认扫描深度（对齐 SillyTavern 默认）
  static const int defaultScanDepth = 4;

  /// 从最近消息文本中选出应注入的条目
  ///
  /// [recentTexts] 按时间正序的消息文本（调用方保证已过滤隐藏/系统消息）；
  /// 只取最后 [Lorebook.scanDepth] 条参与匹配（0/未设置用 [defaultScanDepth]）。
  static List<LorebookEntry> selectEntries(
    Lorebook book,
    List<String> recentTexts,
  ) {
    if (!book.enabled) return const [];

    final depth = book.scanDepth > 0 ? book.scanDepth : defaultScanDepth;
    final window = recentTexts.length <= depth
        ? recentTexts
        : recentTexts.sublist(recentTexts.length - depth);
    final haystack = window.join('\n');

    final selected = <LorebookEntry>[];
    for (final entry in book.entries) {
      if (!entry.enabled) continue;
      if (entry.content.trim().isEmpty) continue;
      if (!entry.constant && !_matches(entry, haystack, window)) continue;
      if (entry.probability < 100 && Random().nextInt(100) >= entry.probability) {
        continue;
      }
      selected.add(entry);
    }

    // 冲突排序：优先级高者在前；同级按插入序（与 ST 的 order 语义一致）
    selected.sort((a, b) {
      final pa = a.priority.compareTo(b.priority);
      if (pa != 0) return -pa; // priority desc
      return a.order.compareTo(b.order); // insertion_order asc
    });

    return _applyBudget(selected, book.tokenBudget);
  }

  /// 渲染为四个注入块（各块内部已换行拼接、保持选择时的排序）
  static WorldInfoBlocks renderBlocks(List<LorebookEntry> entries) {
    final beforeSystem = <String>[];
    final afterSystem = <String>[];
    final beforeUser = <String>[];
    final afterUser = <String>[];

    for (final e in entries) {
      switch (e.position) {
        case LorebookEntryPosition.beforeSystem:
        case LorebookEntryPosition.top:
          beforeSystem.add(e.content.trim());
        case LorebookEntryPosition.beforeUser:
        case LorebookEntryPosition.beforeAssistant:
          beforeUser.add(e.content.trim());
        case LorebookEntryPosition.afterUser:
        case LorebookEntryPosition.afterAssistant:
          afterUser.add(e.content.trim());
        case LorebookEntryPosition.afterSystem:
        case LorebookEntryPosition.bottom:
          afterSystem.add(e.content.trim());
      }
    }

    return WorldInfoBlocks(
      beforeSystem: beforeSystem.join('\n'),
      afterSystem: afterSystem.join('\n'),
      beforeUser: beforeUser.join('\n'),
      afterUser: afterUser.join('\n'),
    );
  }

  /// 单条目的关键词匹配
  static bool _matches(LorebookEntry entry, String haystack, List<String> window) {
    final primary = _hitAny(entry.matchKeys, haystack, window, entry);
    if (!primary) return false;

    // selective（AND_ALL）：次要关键词须全部命中
    if (entry.secondaryKeys.isNotEmpty) {
      for (final k in entry.secondaryKeys) {
        if (!_hitKey(k, haystack, window, entry)) return false;
      }
    }
    return true;
  }

  /// 主关键词：任一命中即触发
  static bool _hitAny(
    List<String> keys,
    String haystack,
    List<String> window,
    LorebookEntry entry,
  ) {
    for (final k in keys) {
      final key = k.trim();
      if (key.isEmpty) continue;
      if (_hitKey(key, haystack, window, entry)) return true;
    }
    return false;
  }

  static bool _hitKey(
    String key,
    String haystack,
    List<String> window,
    LorebookEntry entry,
  ) {
    final needle = entry.caseSensitive ? key : key.toLowerCase();
    if (needle.isEmpty) return false;

    switch (entry.matchStrategy) {
      case LorebookEntryMatchStrategy.regex:
        try {
          return RegExp(needle, caseSensitive: entry.caseSensitive)
              .hasMatch(haystack);
        } on FormatException {
          // 真实世界书里常见残缺正则：静默跳过而不是让整次生成失败
          return false;
        }
      case LorebookEntryMatchStrategy.exact:
        final target = window
            .map((m) => entry.caseSensitive ? m.trim() : m.trim().toLowerCase());
        return target.contains(needle);
      case LorebookEntryMatchStrategy.partial:
        final text = entry.caseSensitive ? haystack : haystack.toLowerCase();
        return text.contains(needle);
    }
  }

  /// token 预算截断（粗估：1 token ≈ 2 字符；预算 ≤ 0 视为不限）
  static List<LorebookEntry> _applyBudget(
    List<LorebookEntry> entries,
    int tokenBudget,
  ) {
    if (tokenBudget <= 0) return entries;
    var used = 0;
    final kept = <LorebookEntry>[];
    for (final e in entries) {
      final cost = (e.content.runes.length / 2).ceil();
      if (used + cost > tokenBudget) continue;
      used += cost;
      kept.add(e);
    }
    return kept;
  }
}

/// 世界书渲染结果：四个注入位置的内容块（空串表示该位置无内容）
class WorldInfoBlocks {
  final String beforeSystem;
  final String afterSystem;
  final String beforeUser;
  final String afterUser;

  const WorldInfoBlocks({
    this.beforeSystem = '',
    this.afterSystem = '',
    this.beforeUser = '',
    this.afterUser = '',
  });
}

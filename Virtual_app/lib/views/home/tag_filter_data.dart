import '../../services/online_character_service.dart';

/// 标签筛选页的**词表与分组规则**（集中维护，改词只改这个文件）
///
/// 数据来源（按优先级）：
/// 1. 角色卡真实 `tags` 字段（后端 `/api/characters` 下发，含种子卡）；
/// 2. 若某组在真实数据里找不到词，则用下面词表里**在数据中出现**的词兜底；
/// 3. 仍然为空时退回真实标签的剩余项 / 角色名，保证页面不会出现空组。
///
/// 词表只负责「候选词」，不会凭空造出数据里不存在的标签 —— 否则点选后
/// 必然命不中任何卡片，用户看到的是永远空结果。
class TagFilterVocabulary {
  TagFilterVocabulary._();

  /// 主题（对应现有分类体系：首页按 `tags.first` 分区的那些词）
  static const List<String> theme = [
    '治愈',
    '日常',
    '科幻',
    '古风',
    '奇幻',
    '赛博',
    '悬疑',
    '都市',
    '玄幻',
    '架空历史',
    '冒险',
    '恋爱',
  ];

  /// 角色（身份 / 职业 / 类型关键词）
  static const List<String> role = [
    '店员',
    '文人',
    '学者',
    '舰长',
    'AI',
    '旅人',
    '侦探',
    '少女',
    '医生',
    '教师',
  ];

  /// 情节（场景 / 关系 / 情绪关键词）
  static const List<String> plot = [
    '深夜',
    '探索',
    '相遇',
    '旅途',
    '告白',
    '危机',
    '雨夜',
    '重逢',
    '告别',
    '秘密',
  ];
}

/// 分组标题（与页面左侧竖排顺序一致）
const List<String> kTagGroupTitles = ['热门标签', '主题', '角色', '情节'];

/// 一组标签
class TagFilterGroup {
  final String title;
  final List<String> tags;

  const TagFilterGroup({required this.title, required this.tags});
}

/// 单张卡是否命中某个标签
///
/// 标签字段命中优先（精确匹配）；没有该 tag 的卡允许按名称 / 描述关键词命中，
/// 这样「角色 / 情节」这类抽取词也能筛到没有对应 tag 的卡。
bool characterMatchesTag(OnlineCharacter c, String tag) {
  final needle = tag.trim();
  if (needle.isEmpty) return false;
  if (c.tags.contains(needle)) return true;
  if (c.name.contains(needle)) return true;
  return c.description.contains(needle);
}

/// 多组标签筛选：**同组并集、跨组交集**
///
/// [selected] 的 key 为组标题，value 为该组选中的标签集合；空集合视为该组未启用。
bool characterMatchesGroups(
  OnlineCharacter c,
  Map<String, Set<String>> selected,
) {
  for (final entry in selected.entries) {
    if (entry.value.isEmpty) continue;
    final hit = entry.value.any((tag) => characterMatchesTag(c, tag));
    if (!hit) return false;
  }
  return true;
}

/// 基于真实角色卡构建四组标签
///
/// [limit] 为每组最多展示的 chip 数，避免某一组把右栏撑得过长。
List<TagFilterGroup> buildTagFilterGroups(
  List<OnlineCharacter> characters, {
  int limit = 12,
}) {
  // 真实 tags 的频次（保持首次出现顺序，便于稳定展示）
  final freq = <String, int>{};
  final tagOrder = <String>[];
  final primaryTags = <String>[];
  for (final c in characters) {
    for (final t in c.tags) {
      if (freq.containsKey(t)) {
        freq[t] = freq[t]! + 1;
      } else {
        freq[t] = 1;
        tagOrder.add(t);
      }
    }
    if (c.tags.isNotEmpty && !primaryTags.contains(c.tags.first)) {
      primaryTags.add(c.tags.first);
    }
  }

  // 热门：按真实频次降序（同频保持首次出现顺序）
  final hot = tagOrder.toList()
    ..sort((a, b) {
      final diff = (freq[b] ?? 0) - (freq[a] ?? 0);
      return diff != 0 ? diff : tagOrder.indexOf(a) - tagOrder.indexOf(b);
    });

  // 主题：首页按 `tags.first` 分区，这里直接沿用同一套主分类
  final theme = <String>[];
  for (final t in [...primaryTags, ...TagFilterVocabulary.theme]) {
    if (theme.contains(t)) continue;
    if (tagOrder.contains(t)) theme.add(t);
  }

  final role = _presentVocabulary(characters, TagFilterVocabulary.role);
  final plot = _presentVocabulary(characters, TagFilterVocabulary.plot);

  // 兜底：某组一个都命中不了时，用「未被前几组占用」的真实标签补齐，
  // 至少保证点选后能筛出内容。
  final used = {...hot, ...theme, ...role, ...plot};
  List<String> fill(List<String> primary) {
    if (primary.isNotEmpty) return primary;
    return tagOrder.where((t) => !used.contains(t)).toList();
  }

  final roleFinal = fill(role);
  final plotFinal = fill(plot);

  List<String> cap(List<String> list) =>
      list.length > limit ? list.sublist(0, limit) : list;

  return [
    TagFilterGroup(title: kTagGroupTitles[0], tags: cap(hot)),
    TagFilterGroup(title: kTagGroupTitles[1], tags: cap(theme)),
    TagFilterGroup(title: kTagGroupTitles[2], tags: cap(roleFinal)),
    TagFilterGroup(title: kTagGroupTitles[3], tags: cap(plotFinal)),
  ];
}

/// 词表中**确实出现在数据里**的词（tag 精确命中，或名称 / 描述包含）
List<String> _presentVocabulary(
  List<OnlineCharacter> characters,
  List<String> vocabulary,
) {
  final hits = <String>[];
  for (final word in vocabulary) {
    final present = characters.any((c) => characterMatchesTag(c, word));
    if (present) hits.add(word);
  }
  return hits;
}

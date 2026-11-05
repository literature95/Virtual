import 'package:flutter/material.dart';

import '../../theme/tavo_brand.dart';
import 'cached_app_image.dart';

/// 封面卡简介预处理
///
/// 角色卡的 description 普遍是「字段名：值」的结构化文本，例如种子角色开头是
/// 「姓名 / 年龄 / 身份 / 外貌 / 性格关键词 / 背景」连续 6 行。整段显示会让封面
/// 变成简历表格，只剔首行也不够——第二行还是「年龄：24」。
///
/// 规则：`字段名：` 的值**不足 20 字**视为元信息直接丢弃（`姓名：晓夜` /
/// `年龄：24`）；达到 20 字的才是真正的叙述段落，取其中最长的一段作为简介。
/// 没有字段结构的自然书写则退化为「折叠换行的连贯文本」。
///
/// 字段名限定 ≤4 个字符（覆盖 `姓名` / `本名` / `代号` / `型号` / `背景` 等）。
/// 放宽到 6 字会把「这件事很重要：…」这类正常长句误判成字段行。
final RegExp _fieldLine = RegExp(r'^[^：:\n]{1,4}[：:]\s*(.+)$');

/// 简介最短阈值：低于此长度的值视为元信息而非简介
const int _minParagraphLength = 20;

String coverSummaryOf(String description) {
  final text = description.trim();
  if (text.isEmpty) return '';

  final paragraphs = <String>[];
  final prose = <String>[];

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final match = _fieldLine.firstMatch(line);
    if (match == null) {
      prose.add(line);
      continue;
    }
    final value = match.group(1)!.trim();
    if (value.length >= _minParagraphLength) {
      paragraphs.add(value);
    }
  }

  if (paragraphs.isNotEmpty) {
    final longest = paragraphs.reduce((a, b) => b.length > a.length ? b : a);
    return _flatten(longest);
  }
  if (prose.isNotEmpty) return _flatten(prose.join(' '));
  // 只剩零散元信息（如「姓名：晓夜」）时宁可不显示，也不把简历标签摆上封面
  return '';
}

String _flatten(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// 封面卡排版风格
///
/// - [overlay]：照片铺满整卡 + 底部压暗渐变 + 白字（首页/搜索/发现列表使用）；
/// - [below]：照片在上、标题与描述在图下方（角色页「角色 / 历史」两段统一使用）。
enum CharacterCoverCardStyle { overlay, below }

/// 竖版封面角色卡 —— 「小说封面」式信息流卡片：
///
/// 照片铺满整卡（而非旧版左置右虚化），顶部左角分类胶囊，
/// 下 1/3 压暗渐变上叠居中文字块（名字 / 简介 / 作者元信息）。
/// 由首页 [SliverGrid] 以 0.62 宽高比成 2~3 列网格展示，
/// 比例不随屏宽失真——这是相对旧横版卡（固定 190 高）的核心改进。
class CharacterCoverCard extends StatelessWidget {
  final String name;
  final String description;
  final List<String> tags;
  final String? avatarUrl;

  /// 卡片排版风格（默认 [CharacterCoverCardStyle.overlay]）
  final CharacterCoverCardStyle style;

  /// 多选模式：卡片右上角显示勾选圈，点击由外层切换选中
  final bool selectionMode;
  final bool selected;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 正在拉取详情 / 导入 —— 转圈并屏蔽点击
  final bool busy;

  const CharacterCoverCard({
    super.key,
    required this.name,
    required this.description,
    this.tags = const [],
    this.avatarUrl,
    this.style = CharacterCoverCardStyle.overlay,
    this.selectionMode = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.busy = false,
  });

  bool get _hasImage => avatarUrl != null && avatarUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = coverSummaryOf(description);
    return GestureDetector(
      onTap: busy ? null : onTap,
      onLongPress: onLongPress,
      // 每张卡独立重绘边界：网格滚动/别的卡变化时不连带重绘本卡
      child: RepaintBoundary(
        child: style == CharacterCoverCardStyle.below
            ? _buildBelow(context, scheme, summary)
            : _buildOverlay(context, scheme, summary),
      ),
    );
  }

  /// 多选勾选圈（右上角，选中态明显）
  Widget _selectionBadge(ColorScheme scheme) {
    return Positioned(
      top: 8,
      right: 8,
      child: IgnorePointer(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.primary : Colors.black.withValues(alpha: 0.38),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  /// 图 5 风格：图片在上，标题 / 描述在图下方（无深色渐变遮罩）
  Widget _buildBelow(BuildContext context, ColorScheme scheme, String summary) {
    final desc = summary.isNotEmpty ? summary : '点按开始对话';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: TavoColors.cosmosElev,
                  child: _hasImage
                      ? CachedAppImage(
                          path: avatarUrl,
                          fit: BoxFit.cover,
                          placeholderColor: TavoColors.cosmosElev,
                        )
                      : _fallbackCover(),
                ),
                if (selectionMode) _selectionBadge(scheme),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context, ColorScheme scheme, String summary) {
    return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
          color: TavoColors.cosmosElev,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 照片铺满整卡 ──
            // CachedAppImage 统一走磁盘缓存 + 按显示宽解码（~180dp × DPR），
            // 避免 1368×768 原图整张解码后上传纹理 —— 列表卡顿的主要来源。
            // 加载中给浅色骨架、成功后 150ms 淡入，不再「一张张蹦」。
            if (_hasImage)
              CachedAppImage(
                path: avatarUrl,
                fit: BoxFit.cover,
                placeholderColor: TavoColors.cosmosElev,
              )
            else
              _fallbackCover(),

            // ── 底部压暗渐变（文字可读性）──
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.32, 0.62, 1.0],
                    colors: [
                      Color(0x000E0E0E),
                      Color(0x990E0E0E),
                      Color(0xF20E0E0E),
                    ],
                  ),
                ),
              ),
            ),

            // ── 左上角：分类标签 ──
            if (tags.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: _glassChip(tags.first),
              ),

            // ── 右上角：多选勾选圈 ──
            if (selectionMode) _selectionBadge(scheme),

            // ── 底部文字块（居中）──
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: TavoColors.cosmosTextDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── 忙碌遮罩（导入中）──
            if (busy)
              ColoredBox(
                color: const Color(0x990E0E0E),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '正在导入…',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }

  /// 无图兜底：品牌渐变底 + 超大首字
  Widget _fallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x4D7E4DF1), // violet 30%
            Color(0x29E3756E), // coral 16%
            Color(0xFF161519), // cosmosElev
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.characters.first,
        style: TextStyle(
          fontSize: 46,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  /// 黑玻璃分类胶囊（左上角）
  Widget _glassChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0x66161519),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

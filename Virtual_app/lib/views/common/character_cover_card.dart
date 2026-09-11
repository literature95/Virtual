import 'dart:convert';
import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../theme/tavo_brand.dart';
import '../../utils/image_data.dart';

/// 按头像路径形态返回对应的 [ImageProvider]，供 [CircleAvatar.backgroundImage]
/// 等使用。
///
/// `avatarPath` 有三种来源，混用过会直接崩：
/// - **在线卡导入**：`http(s)://…` 外链（如 charhub 立绘）→ 必须走
///   [NetworkImage]；用 `FileImage(File(url))` 在 Web 上会抛
///   `Unsupported operation: _Namespace`（dart:io 在 Web 不可用）。
/// - **data URL**（`data:image/…;base64,…`）→ [MemoryImage]。
/// - **本地选图**（原生端文件路径）→ [FileImage]；Web 端无文件系统能力，
///   返回 null 由调用方回退到首字占位。
///
/// 空值 / 无法识别时返回 null。
ImageProvider? resolveAvatarImage(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (path.startsWith('data:')) {
    final parsed = parseDataUrl(path);
    if (parsed != null) {
      try {
        return MemoryImage(base64Decode(parsed.$2));
      } catch (_) {
        return null;
      }
    }
    return null;
  }
  // 本地文件路径：Web 端 dart:io File 不可用，直接回退占位
  if (kIsWeb) return null;
  return FileImage(File(path));
}

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

  final VoidCallback? onTap;

  /// 正在拉取详情 / 导入 —— 转圈并屏蔽点击
  final bool busy;

  const CharacterCoverCard({
    super.key,
    required this.name,
    required this.description,
    this.tags = const [],
    this.avatarUrl,
    this.onTap,
    this.busy = false,
  });

  bool get _hasImage => avatarUrl != null && avatarUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = coverSummaryOf(description);
    return GestureDetector(
      onTap: busy ? null : onTap,
      // 每张卡独立重绘边界：网格滚动/别的卡变化时不连带重绘本卡
      child: RepaintBoundary(
        child: Container(
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
            // memCacheWidth：按卡片实际显示宽（~180px × 2 dpr ≈ 360）解码，
            // 避免 1368×768 原图整张解码上传纹理 —— Web/低端设备的主要卡顿源。
            // 淡入压到 120ms：默认 500ms 在慢加载时观感像「渲染不出来」。
            if (_hasImage)
              CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
      ),
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

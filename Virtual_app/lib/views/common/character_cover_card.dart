import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/tavo_brand.dart';

/// 竖版封面角色卡 —— 「小说封面」式信息流卡片：
///
/// 照片铺满整卡（而非旧版左置右虚化），顶部左角分类胶囊、右上角导入角标，
/// 下 1/3 压暗渐变上叠居中文字块（名字 / 简介 / 作者元信息）。
/// 由首页 [SliverGrid] 以 0.62 宽高比成 2~3 列网格展示，
/// 比例不随屏宽失真——这是相对旧横版卡（固定 190 高）的核心改进。
class CharacterCoverCard extends StatelessWidget {
  final String name;
  final String description;
  final List<String> tags;
  final String? avatarUrl;

  /// 作者（列表接口下发，来自 CCv3 `creator`）
  final String? creator;

  /// 角色卡版本（来自 CCv3 `character_version`）
  final String? characterVersion;

  /// 已导入本地 —— 显示右上角角标，重复点击也不会再建副本
  final bool imported;

  final VoidCallback? onTap;

  /// 正在拉取详情 / 导入 —— 转圈并屏蔽点击
  final bool busy;

  const CharacterCoverCard({
    super.key,
    required this.name,
    required this.description,
    this.tags = const [],
    this.avatarUrl,
    this.creator,
    this.characterVersion,
    this.imported = false,
    this.onTap,
    this.busy = false,
  });

  bool get _hasImage => avatarUrl != null && avatarUrl!.isNotEmpty;

  bool get _hasCreator => creator != null && creator!.trim().isNotEmpty;

  bool get _hasVersion =>
      characterVersion != null && characterVersion!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: busy ? null : onTap,
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
            if (_hasImage)
              CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
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

            // ── 顶部行：分类胶囊 + 导入角标 ──
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  if (tags.isNotEmpty) Flexible(child: _glassChip(tags.first)),
                  const Spacer(),
                  if (imported) _importedBadge(),
                ],
              ),
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
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      description,
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
                  if (_hasCreator || _hasVersion) ...[
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_hasCreator) ...[
                          const Icon(Icons.person_outline,
                              size: 12, color: TavoColors.cosmosTextFaint),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              creator!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: TavoColors.cosmosTextFaint,
                              ),
                            ),
                          ),
                        ],
                        if (_hasCreator && _hasVersion)
                          const SizedBox(width: 10),
                        if (_hasVersion) ...[
                          const Icon(Icons.sell_outlined,
                              size: 12, color: TavoColors.cosmosTextFaint),
                          const SizedBox(width: 3),
                          Text(
                            characterVersion!,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: TavoColors.cosmosTextFaint,
                            ),
                          ),
                        ],
                      ],
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

  /// 「已导入」角标（右上角，签名渐变）
  Widget _importedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: TavoColors.signGradient,
      ),
      child: const Text(
        '已导入',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/tavo_brand.dart';

/// 沉浸式角色图片卡 —— 与 Virtual_web 端 .char-card.photo 统一：
/// 照片铺满左侧，向右虚化渐隐，文字叠加在图上；宽高比 1.58:1。
class CharacterPhotoCard extends StatelessWidget {
  final String name;
  final String description;
  final List<String> tags;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final double height;

  /// 正在为该卡片执行异步操作（拉取详情 / 导入）——显示转圈并屏蔽点击，
  /// 避免用户连点触发多次导入。
  final bool busy;

  const CharacterPhotoCard({
    super.key,
    required this.name,
    required this.description,
    this.tags = const [],
    this.avatarUrl,
    this.onTap,
    this.height = 190,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = height * 1.58;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
          // 图片加载失败时的品牌渐变兜底
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              TavoColors.violet.withValues(alpha: 0.3),
              TavoColors.coral.withValues(alpha: 0.16),
              scheme.surfaceContainerLow,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 角色照片（左置，object-position 22% 向右虚化）──
            if (avatarUrl != null && avatarUrl!.isNotEmpty)
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.30, 0.62, 0.94],
                  colors: [
                    Color(0xFF000000),
                    Color(0x6B000000),
                    Color(0x00000000),
                  ],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  fit: BoxFit.cover,
                  alignment: const Alignment(-0.56, 0),
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              )
            else
              Center(
                child: Text(
                  name.characters.first,
                  style: TextStyle(
                    fontSize: height * 0.42,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),

            // ── 右侧压暗渐变（保证文字可读）──
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.30, 0.62, 0.92],
                    colors: [
                      Color(0x000E0E0E),
                      Color(0x8C0E0E0E),
                      Color(0xEB0E0E0E),
                    ],
                  ),
                ),
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

            // ── 文字叠加（右侧底部）──
            Positioned(
              left: width * 0.38,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        TavoColors.signGradient.createShader(bounds),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: TavoColors.cosmosTextDim,
                      ),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.take(3).map(_tagChip).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: TavoColors.violet.withValues(alpha: 0.12),
        border: Border.all(color: TavoColors.violet.withValues(alpha: 0.35)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 10.5,
          color: Color(0xFFC7B0FC),
        ),
      ),
    );
  }
}

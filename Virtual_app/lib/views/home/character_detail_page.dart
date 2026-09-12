import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../providers/character_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/online_character_service.dart';
import '../../theme/tavo_brand.dart';
import '../common/cosmos_background.dart';

/// 在线角色卡详情页
///
/// 沉浸式布局：立绘作为视觉主角固定不滚动，立绘上直接叠 CTA「开始对话」，
/// 下方依次为互动条（点赞/转发/收藏/评分）、创作人区、详情卡片（描述/人设/场景/
/// 创作者备注/开场白）。导入闭环与原详情页一致：拉详情→建本地卡→建会话→跳聊天。
class CharacterDetailPage extends StatefulWidget {
  final String characterId;
  final OnlineCharacter? preview;

  const CharacterDetailPage({
    super.key,
    required this.characterId,
    this.preview,
  });

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage> {
  final OnlineCharacterService _service = OnlineCharacterService();
  OnlineCharacter? _character;
  bool _loading = true;
  bool _importing = false;
  /// 角色库切换中（导入 + 入库是异步链路，防连点）
  bool _shelfBusy = false;
  String? _error;

  // ── 互动数据（mock，后续接后端 API）──
  bool _liked = false;
  bool _saved = false;
  int _likeCount = 0;
  int _shareCount = 0;
  int _saveCount = 0;
  double _rating = 0.0;
  int _ratingCount = 0;
  bool _followingCreator = false;

  @override
  void initState() {
    super.initState();
    if (widget.preview != null) {
      _character = widget.preview;
      _loading = false;
      _seedMockInteractions(widget.preview!);
    }
    _loadDetail();
  }

  /// 根据 characterId 生成稳定的 mock 互动数据
  /// （后端暂无该字段，先做 UI 占位，避免每次打开数字跳动）
  void _seedMockInteractions(OnlineCharacter c) {
    final hash = c.id.hashCode.abs();
    _likeCount = 120 + (hash % 5) * 87; // 120 ~ 468
    _shareCount = 18 + (hash % 3) * 14; // 18 ~ 46
    _saveCount = 56 + (hash % 7) * 23; // 56 ~ 218
    _rating = 4.0 + (hash % 10) / 10.0; // 4.0 ~ 4.9
    _ratingCount = 34 + (hash % 11) * 9; // 34 ~ 133
  }

  Future<void> _loadDetail() async {
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    try {
      final full = await _service.fetchCharacter(backend, widget.characterId);
      if (!mounted) return;
      setState(() {
        _character = full;
        _loading = false;
        _error = null;
        _seedMockInteractions(full);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // 有 preview 数据时静默回退：保留 preview 展示，不打扰用户
        // 仅在无任何数据兜底时才进入错误视图
        if (_character == null) {
          _error = _friendlyError(e);
        }
      });
    }
  }

  /// 把底层异常翻译成用户能看懂的提示
  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused') ||
        s.contains('Connection timed out')) {
      return '无法连接到后端，请检查网络或后端地址设置';
    }
    if (s.contains('404')) return '角色卡不存在或已下架';
    if (s.contains('401') || s.contains('403')) {
      return '没有权限访问该角色卡';
    }
    // 5xx 服务端错误
    if (s.contains('500') ||
        s.contains('502') ||
        s.contains('503') ||
        s.contains('504')) {
      return '后端服务暂时不可用，请稍后重试';
    }
    return '加载失败，请稍后重试';
  }

  Future<void> _startChat() async {
    if (_importing || _character == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    final characters = context.read<CharacterProvider>();
    final chats = context.read<ChatProvider>();

    setState(() => _importing = true);
    try {
      final c = _character!;
      final local = characters.findBySourceId(c.id) ??
          await _importCharacter(characters, backend, c);
      if (!mounted) return;

      final conv = chats.latestConversationOf(local.id) ??
          await chats.createConversation(
            characterId: local.id,
            title: local.name,
          );
      if (!mounted) return;
      context.go('/chat/${conv.id}');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<Character> _importCharacter(
    CharacterProvider characters,
    String backend,
    OnlineCharacter c,
  ) async {
    final full =
        c.isFullCard ? c : await _service.fetchCharacter(backend, c.id);
    return characters.createCharacter(
      name: full.name,
      nickname: full.nickname,
      description: full.description,
      personality: full.personality,
      scenario: full.scenario,
      firstMessage: full.firstMessage,
      avatarPath: full.avatarUrl,
      creatorNotes: full.creatorNotes,
      systemPrompt: full.systemPrompt,
      postHistoryInstructions: full.postHistoryInstructions,
      creator: full.creator,
      characterVersion: full.characterVersion,
      source: full.source,
      tags: full.tags,
      alternateGreetings: full.alternateGreetings,
      exampleMessages: full.exampleMessages,
      groupOnlyGreetings: full.groupOnlyGreetings,
      creatorNotesMultilingual: full.creatorNotesMultilingual,
      extensions: full.importExtensions,
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 「加入角色库 / 已加入」切换按钮（叠在立绘上的次级 CTA）
  ///
  /// 角色库是「角色」Tab 首段的内容来源：只有加入角色库的卡才出现在库里，
  /// 因此这里是角色库的唯一入口（用户设计要求）。
  ///
  /// 关键点：列表接口给的是**后端卡 ID**（如「希露妲」），而角色库存的是
  /// **本地角色 UUID**。在线卡未导入本地库时二者对不上 → 必须先把卡导入本地
  /// （复用 [_importCharacter] / `findBySourceId` 查重），再用本地 id 入库存档，
  /// 否则库里永远查不到这张卡（历史 bug 根因）。
  Widget _shelfToggle(BuildContext context, ColorScheme scheme) {
    final chars = context.watch<CharacterProvider>();
    // 用本地 id 判定「已加入」，没有本地副本时自然为 false
    final local = chars.findBySourceId(widget.characterId);
    final inShelf = local != null && chars.isInShelf(local.id);
    return Material(
      color: inShelf
          ? TavoColors.violet.withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _shelfBusy ? null : () => _toggleShelf(chars),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: inShelf ? 0.0 : 0.34),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_shelfBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  inShelf
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                  size: 20,
                  color: Colors.white,
                ),
              const SizedBox(width: 6),
              Text(
                inShelf ? '已加入' : '加入角色库',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切换角色库：先确保本地存在该卡（必要时从后端导入），再入库/出库
  Future<void> _toggleShelf(CharacterProvider chars) async {
    final c = _character;
    if (c == null || _shelfBusy) return;

    final backend = context.read<SettingsProvider>().backendBaseUrl;

    // 已在库 → 直接移出（用本地 id）
    final existing = chars.findBySourceId(widget.characterId);
    if (existing != null && chars.isInShelf(existing.id)) {
      await chars.removeFromShelf(existing.id);
      if (!mounted) return;
      _toast('已移出角色库');
      return;
    }

    setState(() => _shelfBusy = true);
    try {
      final local =
          existing ?? await _importCharacter(chars, backend, c);
      await chars.addToShelf(local.id);
      if (!mounted) return;
      _toast('已加入角色库');
    } catch (e) {
      if (!mounted) return;
      _toast('加入失败：$e');
    } finally {
      if (mounted) setState(() => _shelfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Hero 区高度：竖版立绘原图比例约 2:3 (0.667)，取屏宽 × 1.25
    // 让立绘作为视觉主角占满首屏主体；clamp [420, 580] 控制窄/宽屏边界。
    final heroHeight =
        (MediaQuery.of(context).size.width * 1.25).clamp(420.0, 580.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? TavoColors.cosmosBg : scheme.surface,
      body: CosmosBackground(
        child: _loading && _character == null
            ? const Center(
                child: CircularProgressIndicator(color: TavoColors.violet),
              )
            : _error != null
                ? _buildErrorView(scheme)
                : CustomScrollView(
                    slivers: [
                      _buildHeroSection(scheme, heroHeight: heroHeight),
                      _buildInteractionBar(scheme),
                      _buildCreatorCard(scheme),
                      _buildDetailsSection(scheme),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 立绘区（固定不滚动，底部叠 CTA）
  // ════════════════════════════════════════════════════

  Widget _buildHeroSection(ColorScheme scheme, {required double heroHeight}) {
    final c = _character!;
    final hasImage = c.avatarUrl != null && c.avatarUrl!.isNotEmpty;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 立绘铺满 + contain 保留完整主体（cover 会切掉人脸）──
            if (hasImage)
              CachedNetworkImage(
                imageUrl: c.avatarUrl!,
                fit: BoxFit.cover,
                // 按显示宽解码（≤560 逻辑宽 × 2 dpr），原图更小时不受影响
                memCacheWidth: 1120,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => Container(
                  decoration: const BoxDecoration(
                    gradient: TavoColors.signGradientDiagonal,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => _buildFallbackHero(c.name),
              )
            else
              _buildFallbackHero(c.name),

            // ── 底部渐变遮罩：从透明到深，承载文字与 CTA ──
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 0.72, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),

            // ── 返回按钮（左上） ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),

            // ── 立绘底部信息块 + CTA ──
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 角色名（大号）
                  Text(
                    c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  if (c.nickname != null && c.nickname!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.nickname!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                  // 标签 chips
                  if (c.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: c.tags
                          .take(4)
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '#$t',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // 「加入书架」+「开始对话」CTA（用户要求：立绘上加按钮）
                  Row(
                    children: [
                      // 加入书架（次级按钮，切换态）
                      _shelfToggle(context, scheme),
                      const SizedBox(width: 10),
                      // 开始对话（主按钮）
                      Expanded(
                        child: TavoBrand.gradientButton(
                          onPressed: _importing ? null : _startChat,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: _importing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.chat_bubble_rounded,
                                        size: 20, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      '开始对话',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackHero(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x4D7E4DF1),
            Color(0x29E3756E),
            Color(0xFF161519),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.characters.first : '?',
        style: TextStyle(
          fontSize: 96,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 互动条：点赞 / 转发 / 收藏 / 评分
  // ════════════════════════════════════════════════════

  Widget _buildInteractionBar(ColorScheme scheme) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            // 评分（左）
            Expanded(
              child: _RatingPill(
                rating: _rating,
                count: _ratingCount,
                scheme: scheme,
              ),
            ),
            // 分隔线
            Container(
              width: 1,
              height: 30,
              color: scheme.outlineVariant,
            ),
            // 点赞
            _InteractionButton(
              icon: _liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _liked ? const Color(0xFFE3756E) : scheme.onSurfaceVariant,
              count: _likeCount + (_liked ? 1 : 0),
              active: _liked,
              onTap: () {
                setState(() => _liked = !_liked);
              },
              scheme: scheme,
            ),
            // 转发
            _InteractionButton(
              icon: Icons.repeat_rounded,
              color: scheme.onSurfaceVariant,
              count: _shareCount,
              onTap: () => _toast('转发功能开发中'),
              scheme: scheme,
            ),
            // 收藏
            _InteractionButton(
              icon: _saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color:
                  _saved ? TavoColors.violet : scheme.onSurfaceVariant,
              count: _saveCount + (_saved ? 1 : 0),
              active: _saved,
              onTap: () {
                setState(() => _saved = !_saved);
              },
              scheme: scheme,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 创作人区
  // ════════════════════════════════════════════════════

  Widget _buildCreatorCard(ColorScheme scheme) {
    final c = _character;
    final creatorName = (c?.creator != null && c!.creator!.isNotEmpty)
        ? c.creator!
        : '匿名创作者';
    final creatorId = c?.id ?? '';

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            // 头像（首字母占位）
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: TavoColors.signGradient,
              ),
              alignment: Alignment.center,
              child: Text(
                creatorName.characters.first,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 名字 + ID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    creatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (creatorId.isNotEmpty)
                    Text(
                      'ID: $creatorId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 关注按钮
            TextButton(
              onPressed: () {
                setState(() => _followingCreator = !_followingCreator);
                _toast(_followingCreator ? '已关注' : '已取消关注');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _followingCreator
                    ? scheme.outlineVariant
                    : TavoColors.violet,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(_followingCreator ? '已关注' : '+ 关注'),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 详情卡片（描述 / 人设 / 场景 / 创作者备注 / 开场白）
  // ════════════════════════════════════════════════════

  Widget _buildDetailsSection(ColorScheme scheme) {
    final c = _character!;
    final sections = <_DetailSection>[];

    if (c.description.isNotEmpty) {
      sections.add(_DetailSection(
        title: '角色描述',
        content: c.description,
        icon: Icons.description_outlined,
      ));
    }
    // 局部变量使 Dart 能做类型提升（字段访问不会提升）
    final personality = c.personality;
    if (personality != null && personality.isNotEmpty) {
      sections.add(_DetailSection(
        title: '人设',
        content: personality,
        icon: Icons.psychology_outlined,
      ));
    }
    final scenario = c.scenario;
    if (scenario != null && scenario.isNotEmpty) {
      sections.add(_DetailSection(
        title: '场景',
        content: scenario,
        icon: Icons.movie_outlined,
      ));
    }
    final creatorNotes = c.creatorNotes;
    if (creatorNotes != null && creatorNotes.isNotEmpty) {
      sections.add(_DetailSection(
        title: '创作者备注',
        content: creatorNotes,
        icon: Icons.edit_note,
      ));
    }
    final firstMessage = c.firstMessage;
    if (firstMessage != null && firstMessage.isNotEmpty) {
      sections.add(_DetailSection(
        title: '开场白',
        content: firstMessage,
        icon: Icons.chat_bubble_outline,
      ));
    }

    return SliverList.separated(
      itemCount: sections.length,
      itemBuilder: (context, i) => _buildDetailCard(scheme, sections[i]),
      separatorBuilder: (context, i) => const SizedBox(height: 14),
    );
  }

  Widget _buildDetailCard(ColorScheme scheme, _DetailSection section) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：图标 + 标题 + 渐变下划线
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: TavoColors.signGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(section.icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 内容文本
          SelectableText(
            section.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.85,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // 错误视图
  // ════════════════════════════════════════════════════

  Widget _buildErrorView(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TavoBrand.emptyIllustration(Icons.cloud_off_outlined, size: 64),
            const SizedBox(height: 18),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            TavoBrand.gradientButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadDetail();
              },
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              child: const Text('重新加载', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// 私有子组件
// ════════════════════════════════════════════════════

class _DetailSection {
  final String title;
  final String content;
  final IconData icon;
  const _DetailSection({
    required this.title,
    required this.content,
    required this.icon,
  });
}

/// 互动按钮（点赞/转发/收藏）：图标 + 计数
class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _InteractionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
    required this.scheme,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              _formatCount(count),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

/// 评分胶囊：星 + 分数 + 评分数
class _RatingPill extends StatelessWidget {
  final double rating;
  final int count;
  final ColorScheme scheme;

  const _RatingPill({
    required this.rating,
    required this.count,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded,
                  size: 20, color: const Color(0xFFFFB300)),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$count 人评分',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

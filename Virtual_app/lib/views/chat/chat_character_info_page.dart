import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../providers/character_provider.dart';
import '../../theme/design_tokens.dart';
import '../common/character_cover_card.dart' show resolveAvatarImage;

/// 「角色信息」只读页
///
/// 从对话页右上角菜单进入，展示当前对话所用角色的**完整本地档案**
/// （立绘 / 简介 / 性格 / 场景 / 开场白 / 备选开场白 / 示例对话 / 系统提示 / 元信息）。
///
/// 与角色卡详情页（`/home/character/:id`，面向**在线**卡）的区别：
/// 这一页读的是**本地库**里的角色，即真正参与 prompt 组装的那一份；
/// 因此这里展示的内容就是「模型看到的设定」，可用于排查 OOC。
class ChatCharacterInfoPage extends StatelessWidget {
  /// 本地角色 id（非后端卡 id）
  final String characterId;

  const ChatCharacterInfoPage({super.key, required this.characterId});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final character = provider.getCharacter(characterId);
        if (character == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('角色信息')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 40),
                    const SizedBox(height: AppSpacing.md),
                    const Text('本地库中找不到这个角色'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '可能角色卡已被删除，或这条对话引用的角色尚未下载到本地',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _CharacterInfoBody(character: character);
      },
    );
  }
}

class _CharacterInfoBody extends StatelessWidget {
  final Character character;

  const _CharacterInfoBody({required this.character});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = resolveAvatarImage(character.avatarPath);

    return Scaffold(
      appBar: AppBar(
        title: Text(character.name),
        actions: [
          IconButton(
            tooltip: '编辑角色卡',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context
                .push('/character/${Uri.encodeComponent(character.id)}/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── 头部：立绘 + 名称 + 创作者 + 标签 ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 76,
                  height: 76,
                  color: scheme.surfaceContainerHighest,
                  child: avatar != null
                      ? Image(image: avatar, fit: BoxFit.cover)
                      : Icon(Icons.person_outline,
                          size: 32, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.name,
                      style: const TextStyle(
                        fontSize: AppFontSize.headline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((character.nickname ?? '').isNotEmpty)
                      Text(
                        '昵称：${character.nickname}',
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        if ((character.creator ?? '').isNotEmpty)
                          'by ${character.creator}',
                        if ((character.characterVersion ?? '').isNotEmpty)
                          'v${character.characterVersion}',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (character.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tag in character.tags)
                  Chip(
                    label: Text(tag, style: const TextStyle(fontSize: AppFontSize.caption)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],

          if (character.isFavorite || character.isPinned) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (character.isFavorite)
                  const _FlagChip(icon: Icons.favorite, label: '已收藏'),
                if (character.isPinned) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const _FlagChip(icon: Icons.push_pin, label: '已置顶'),
                ],
              ],
            ),
          ],

          _textSection(context, '简介', character.description),
          _textSection(context, '性格', character.personality),
          _textSection(context, '场景', character.scenario),
          _textSection(context, '开场白', character.firstMessage),

          if (character.alternateGreetings.isNotEmpty)
            _listSection(context, '备选开场白', character.alternateGreetings),

          if (character.exampleMessages.isNotEmpty)
            _exampleSection(context),

          _textSection(context, '系统提示', character.systemPrompt),
          _textSection(context, '历史后指令', character.postHistoryInstructions),

          if (character.groupOnlyGreetings.isNotEmpty)
            _listSection(context, '群聊专属开场白', character.groupOnlyGreetings),

          _textSection(context, '创作者备注（不进入 prompt）', character.creatorNotes),

          _sectionTitle(context, '元信息'),
          _metaCard(context),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _textSection(BuildContext context, String title, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, title),
        _card(
          context,
          SelectableText(value.trim(), style: const TextStyle(fontSize: AppFontSize.body, height: 1.5)),
        ),
      ],
    );
  }

  Widget _listSection(BuildContext context, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, title),
        for (int i = 0; i < items.length; i++)
          _card(
            context,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${i + 1}.',
                      style: TextStyle(
                          fontSize: AppFontSize.caption,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  child: SelectableText(items[i].trim(),
                      style: const TextStyle(fontSize: AppFontSize.body, height: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _exampleSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, '示例对话（${character.exampleMessages.length} 组）'),
        for (final ex in character.exampleMessages)
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((ex.note ?? '').isNotEmpty) ...[
                  Text(
                    ex.note!,
                    style: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                _roleLine(context, '{{user}}', ex.userMessage),
                const SizedBox(height: AppSpacing.sm),
                _roleLine(context, character.name, ex.assistantMessage),
              ],
            ),
          ),
      ],
    );
  }

  Widget _roleLine(BuildContext context, String who, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          who,
          style: TextStyle(
            fontSize: AppFontSize.caption,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
        SelectableText(text.trim(),
            style: const TextStyle(fontSize: AppFontSize.body, height: 1.5)),
      ],
    );
  }

  Widget _metaCard(BuildContext context) {
    final rows = <(String, String)>[
      ('角色 ID', character.id),
      if ((character.sourceId ?? '').isNotEmpty)
        ('来源卡 ID', character.sourceId!),
      if ((character.source ?? '').isNotEmpty) ('导入来源', character.source!),
      if ((character.lorebookId ?? '').isNotEmpty)
        ('绑定世界书', character.lorebookId!),
      if ((character.personaId ?? '').isNotEmpty) ('绑定 Persona', character.personaId!),
      ('使用次数', '${character.usageCount}'),
      ('创建时间', _fmt(character.createdAt)),
      ('更新时间', _fmt(character.updatedAt)),
    ];
    return _card(
      context,
      Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(label,
                        style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  Expanded(
                    child: SelectableText(value,
                        style: const TextStyle(fontSize: AppFontSize.caption)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.sm),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppFontSize.label,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _FlagChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FlagChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.primary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: AppFontSize.caption, color: scheme.primary)),
        ],
      ),
    );
  }
}

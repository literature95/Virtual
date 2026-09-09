import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../providers/chat_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/online_character_service.dart';
import '../../theme/tavo_brand.dart';
import '../common/character_cover_card.dart';

/// 单个分类下的全部角色列表
///
/// 从后端拉取全量角色，本地按 [category] tag 过滤后网格展示。
/// 后端目前没有 tag 筛选端点，因此复用 /api/characters 全列表。
class CategoryCharactersPage extends StatefulWidget {
  final String category;

  const CategoryCharactersPage({super.key, required this.category});

  @override
  State<CategoryCharactersPage> createState() => _CategoryCharactersPageState();
}

class _CategoryCharactersPageState extends State<CategoryCharactersPage> {
  final OnlineCharacterService _service = OnlineCharacterService();
  List<OnlineCharacter>? _characters;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    try {
      final list = await _service.fetchCharacters(backend);
      if (!mounted) return;
      setState(() {
        _characters = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法连接后端 $backend');
    }
  }

  List<OnlineCharacter> get _filtered {
    final all = _characters ?? const <OnlineCharacter>[];
    return all.where((c) => c.tags.contains(widget.category)).toList();
  }

  /// 竖版封面卡列数：宽屏（内容限宽 560）3 列，否则 2 列
  int get _gridColumns =>
      MediaQuery.of(context).size.width >= 720 ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.category,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: () async => _load(),
        child: CustomScrollView(
          slivers: [
            if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _errorView(context),
              )
            else if (_characters == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: TavoColors.violet),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyView(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridColumns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final c = _filtered[i];
                      return CharacterCoverCard(
                        name: c.name,
                        description: c.description,
                        tags: c.tags,
                        avatarUrl: c.avatarUrl,
                        busy: _busyId == c.id,
                        onTap: () => _openCharacter(context, c),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              onPressed: _load,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              child: const Text('重新加载', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TavoBrand.emptyIllustration(Icons.auto_awesome_outlined, size: 64),
          const SizedBox(height: 18),
          Text(
            '「${widget.category}」下暂无角色',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _openCharacter(BuildContext context, OnlineCharacter c) async {
    if (_busyId != null) return;

    final messenger = ScaffoldMessenger.of(context);
    final backend = context.read<SettingsProvider>().backendBaseUrl;
    final characters = context.read<CharacterProvider>();
    final chats = context.read<ChatProvider>();

    setState(() => _busyId = c.id);
    try {
      final local = await _ensureLocalCharacter(characters, backend, c);
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
        SnackBar(content: Text('导入「${c.name}」失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<Character> _ensureLocalCharacter(
    CharacterProvider characters,
    String backend,
    OnlineCharacter c,
  ) async {
    final existing = characters.findBySourceId(c.id);
    if (existing != null) return existing;

    final full = await _service.fetchCharacter(backend, c.id);
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
}

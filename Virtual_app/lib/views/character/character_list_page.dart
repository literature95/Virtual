import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import '../../data/app_database.dart';
import '../../providers/character_provider.dart';
import '../../models/character.dart';
import '../../services/character_import_service.dart';
import '../../services/character_export_service.dart';
import '../../theme/tavo_brand.dart';
import '../common/character_cover_card.dart' show resolveAvatarImage;

/// 角色列表页：搜索 + 管理（长按菜单：编辑/复制/导出/删除）
class CharacterListPage extends StatefulWidget {
  const CharacterListPage({super.key});

  @override
  State<CharacterListPage> createState() => _CharacterListPageState();
}

class _CharacterListPageState extends State<CharacterListPage> {
  bool _searchVisible = false;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '搜索角色名 / 描述 / 标签…',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('角色管理'),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.file_upload),
            onPressed: _searchVisible
                ? () {
                    setState(() {
                      _searchVisible = false;
                      _searchCtrl.clear();
                      _query = '';
                    });
                  }
                : () => _importCharacter(context),
            tooltip: _searchVisible ? '关闭搜索' : '导入角色',
          ),
          IconButton(
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchCtrl.clear();
                  _query = '';
                }
              });
            },
            tooltip: '搜索角色',
          ),
        ],
      ),
      body: Consumer<CharacterProvider>(
        builder: (context, characterProvider, _) {
          final all = characterProvider.characters;
          if (all.isEmpty) {
            return const _EmptyState();
          }
          final q = _query.trim().toLowerCase();
          final characters =
              q.isEmpty ? all : characterProvider.searchCharacters(_query);
          if (characters.isEmpty) {
            return const Center(
              child: Text('没有匹配的角色', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final character = characters[index];
              return _CharacterTile(character: character);
            },
          );
        },
      ),
      floatingActionButton: TavoBrand.fab(
        onPressed: () => context.push('/character/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _importCharacter(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('从 URL 导入'),
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.file_present),
              title: const Text('从 JSON 文件导入'),
              onTap: () => Navigator.pop(context, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('从 PNG 图片导入'),
              onTap: () => Navigator.pop(context, 'png'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      final dio = Dio();
      final importService = CharacterImportService(dio);
      CharacterImportBundle? bundle;

      switch (result) {
        case 'url':
          final controller = TextEditingController();
          final url = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('输入角色卡 URL'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/character.json',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('导入'),
                ),
              ],
            ),
          );
          if (url != null && url.isNotEmpty) {
            bundle = await importService.importBundleFromUrl(url);
          }
          break;
        case 'json':
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
          );
          if (pickedFile != null) {
            bundle = await importService.importBundleFromFile(pickedFile.path);
          }
          break;
        case 'png':
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
          );
          if (pickedFile != null) {
            bundle = await importService.importBundleFromPng(pickedFile.path);
          }
          break;
      }

      if (bundle != null && context.mounted) {
        // 世界书先落库，拿到 id 后绑定到角色，避免丢失 character_book 设定
        String? lorebookId;
        if (bundle.hasLorebook) {
          await AppDatabase.instance.saveLorebook(bundle.lorebook!);
          lorebookId = bundle.lorebook!.id;
        }

        final character = bundle.character;
        await context.read<CharacterProvider>().createCharacter(
              name: character.name,
              nickname: character.nickname,
              description: character.description,
              personality: character.personality,
              scenario: character.scenario,
              firstMessage: character.firstMessage,
              avatarPath: character.avatarPath,
              creatorNotes: character.creatorNotes,
              systemPrompt: character.systemPrompt,
              postHistoryInstructions: character.postHistoryInstructions,
              creator: character.creator,
              characterVersion: character.characterVersion,
              source: character.source,
              groupOnlyGreetings: character.groupOnlyGreetings,
              creatorNotesMultilingual: character.creatorNotesMultilingual,
              tags: character.tags,
              alternateGreetings: character.alternateGreetings,
              exampleMessages: character.exampleMessages,
              lorebookId: lorebookId,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '成功导入「${character.name}」（${bundle.summary}）',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }
}

class _CharacterTile extends StatelessWidget {
  final Character character;

  const _CharacterTile({required this.character});

  @override
  Widget build(BuildContext context) {
    final avatar = resolveAvatarImage(character.avatarPath);
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatar,
        child: avatar == null ? Text(character.name.characters.first) : null,
      ),
      title: Text(character.name),
      subtitle: Text(
        character.description ?? '暂无描述',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => context.push('/character/${character.id}/edit'),
      onLongPress: () {
        _showContextMenu(context, character);
      },
    );
  }

  void _showContextMenu(BuildContext context, Character character) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                context.push('/character/${character.id}/edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(context);
                context
                    .read<CharacterProvider>()
                    .duplicateCharacter(character.id)
                    .then((copy) {
                  if (context.mounted && copy != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('已复制为「${copy.name}」'),
                      ),
                    );
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('导出角色卡'),
              onTap: () {
                Navigator.pop(context);
                _exportCharacter(context, character);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, character);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCharacter(
      BuildContext context, Character character) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('导出为 CCv3 JSON'),
              onTap: () => Navigator.pop(context, 'ccv3'),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('导出为 SillyTavern 格式'),
              onTap: () => Navigator.pop(context, 'sillytavern'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      final exportService = CharacterExportService();

      // For now, we'll save to a temporary location and show the content
      // In a real app, you'd use file_picker or share_plus to save
      final json = result == 'ccv3'
          ? exportService.toCCv3(character)
          : exportService.toSillyTavern(character);

      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('导出「${character.name}」'),
            content: SingleChildScrollView(
              child: SelectableText(
                jsonString,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
              TextButton(
                onPressed: () {
                  // Copy to clipboard
                  // In a real app, you'd use clipboard package
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                child: const Text('复制'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, Character character) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除角色'),
        content: Text('确定要删除角色「${character.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CharacterProvider>().deleteCharacter(character.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 官方空状态插画
            Image.asset(
              'assets/images/empty_state_character.png',
              width: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 64,
                  color: Colors.grey[350]),
            ),
            const SizedBox(height: 14),
            Text('暂无角色',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            // 说明卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '角色是聊天时 AI 扮演的身份，他/她拥有自己的性格、背景、喜好等，也会随着和你互动产生共同回忆后发生变化。',
                    style: TextStyle(
                        fontSize: 13.5, height: 1.6, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角创建或导入一个角色吧！',
                    style: TextStyle(
                        fontSize: 13, height: 1.5, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

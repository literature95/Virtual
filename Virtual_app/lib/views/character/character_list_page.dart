import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../providers/character_provider.dart';
import '../../models/character.dart';
import '../../models/lorebook.dart';
import '../../services/character_import_service.dart';
import '../../services/character_export_service.dart';
import '../../theme/tavo_brand.dart';
import '../../utils/file_saver.dart';
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

  /// 从 PNG 导入时暂存的立绘（data URL），随角色一并落库
  String? _pendingAvatar;

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
              leading: const Icon(Icons.image),
              title: const Text('从 PNG 卡片导入'),
              subtitle: const Text('角色卡唯一支持的格式（内嵌 CCv3 数据）'),
              onTap: () => Navigator.pop(context, 'png'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    _pendingAvatar = null;

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
        case 'png':
          final bytes = await _pickCardBytes(const ['png']);
          if (bytes != null) {
            bundle = importService.importBundleFromBytes(
              bytes,
              sourceName: '角色卡 PNG',
            );
            // 卡片图本身就是立绘：转 data URL 落库，Web 与原生都能显示
            _pendingAvatar = 'data:image/png;base64,${base64Encode(bytes)}';
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
              avatarPath: _pendingAvatar ?? character.avatarPath,
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

  /// 选取角色卡 PNG 并直接取出字节
  ///
  /// 为什么不复用「相册选图」：桌面端 `image_picker` 按后缀白名单过滤，
  /// 且 Web 端它固定渲染 `accept="image/*"`，无法按需求限定单个扩展名。
  /// 用 `file_picker` 才能明确限定为 `.png`。
  ///
  /// 为什么取字节而不是路径：Web 上没有文件系统，`dart:io File` 会抛
  /// `Unsupported operation: _Namespace`。`withData: true` 让各端都回填
  /// `bytes`，极端情况下再用跨平台的 `xFile` 兜底，全程不碰 `dart:io`。
  Future<Uint8List?> _pickCardBytes(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    final files = result?.files;
    if (files == null || files.isEmpty) return null;
    final file = files.first;
    return file.bytes ?? await file.xFile.readAsBytes();
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

  /// 导出角色卡 —— **仅 PNG**
  ///
  /// 项目约定角色卡以 PNG 为唯一分发格式：产物是「底图 + 内嵌
  /// base64(CCv3 JSON) 的 tEXt 块」，与导入路径构成往返闭环。
  /// 世界书作为 `character_book` 一并写入卡内。
  Future<void> _exportCharacter(
      BuildContext context, Character character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导出「${character.name}」'),
        content: const Text(
          '将导出为 PNG 角色卡：卡片图内嵌完整 CCv3 数据（含世界书），'
          '可直接分享或导入其他前端。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final exportService = CharacterExportService();
      final bytes = await exportService.exportPngBytes(
        character,
        lorebook: _findLorebook(context, character.lorebookId),
      );
      final fileName = exportService.pngFileName(character);
      final path = await saveBytesToFile(
        bytes,
        fileName: fileName,
        mimeType: 'image/png',
        allowedExtensions: const ['png'],
        dialogTitle: '导出角色卡',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null
                ? '已取消导出'
                : '已导出 PNG 角色卡（${bytes.length ~/ 1024} KB）→ $path',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 取角色绑定的世界书，随卡一并导出为 `character_book`
  ///
  /// [AppDatabase] 没有按 id 取单本的接口，只有全量列表，这里就地过滤。
  Lorebook? _findLorebook(BuildContext context, String? lorebookId) {
    if (lorebookId == null) return null;
    for (final lb in context.read<AppDatabase>().getLorebooks()) {
      if (lb.id == lorebookId) return lb;
    }
    return null;
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

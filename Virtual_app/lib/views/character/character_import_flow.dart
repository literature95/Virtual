import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/character.dart';
import '../../providers/character_provider.dart';
import '../../services/character_import_service.dart';
import '../../utils/png_card_extractor.dart' show hasPngSignature;

/// 角色卡导入流程（文件 / URL → **本地**角色库，不上传后端）
///
/// 角色库「+」菜单与旧角色管理页共用的落库链路：
/// 1. 世界书先 `saveLorebook` 拿到 id（`character_book` 不丢——
///    「角色全在世界书里」的卡只存人设壳等于丢了核心内容）；
/// 2. 再 `createCharacter` 绑定 `lorebookId`，全字段落库。
class CharacterImportFlow {
  CharacterImportFlow._();

  /// 选取角色卡文件并取出字节（PNG / JSON 均可）
  ///
  /// 为什么取字节而不是路径：Web 上没有文件系统，`dart:io File` 会抛
  /// `Unsupported operation: _Namespace`。`withData: true` 让各端都回填
  /// `bytes`，极端情况下再用跨平台的 `xFile` 兜底，全程不碰 `dart:io`。
  static Future<Uint8List?> pickCardBytes(List<String> extensions) async {
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

  /// 把解析好的 bundle 落入本地角色库，返回创建的角色
  ///
  /// [avatarOverride]：PNG 卡导入时把整张卡图转成 data URL 作为立绘
  /// （卡片图本身就是立绘，Web 与原生都能显示）。
  static Future<Character> persistBundle(
    BuildContext context,
    CharacterImportBundle bundle, {
    String? avatarOverride,
  }) async {
    String? lorebookId;
    if (bundle.hasLorebook) {
      await AppDatabase.instance.saveLorebook(bundle.lorebook!);
      lorebookId = bundle.lorebook!.id;
    }

    final c = bundle.character;
    final created =
        await context.read<CharacterProvider>().createCharacter(
              name: c.name,
              nickname: c.nickname,
              description: c.description,
              personality: c.personality,
              scenario: c.scenario,
              firstMessage: c.firstMessage,
              avatarPath: avatarOverride ?? c.avatarPath,
              creatorNotes: c.creatorNotes,
              systemPrompt: c.systemPrompt,
              postHistoryInstructions: c.postHistoryInstructions,
              creator: c.creator,
              characterVersion: c.characterVersion,
              source: c.source,
              groupOnlyGreetings: c.groupOnlyGreetings,
              creatorNotesMultilingual: c.creatorNotesMultilingual,
              tags: c.tags,
              alternateGreetings: c.alternateGreetings,
              exampleMessages: c.exampleMessages,
              extensions: c.extensions,
              lorebookId: lorebookId,
            );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导入「${created.name}」到本地角色库（${bundle.summary}）'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    return created;
  }

  /// 从文件导入（JSON 或 PNG，自动识别）→ 本地角色库
  static Future<void> importFromFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await pickCardBytes(const ['png', 'json']);
      if (bytes == null) return; // 用户取消

      final service = CharacterImportService(_dio());
      final bundle = service.importBundleFromBytes(bytes, sourceName: '角色卡文件');

      // PNG 卡：整张卡图就是立绘，转 data URL 随角色落库
      String? avatar;
      if (hasPngSignature(bytes)) {
        avatar = 'data:image/png;base64,${base64Encode(bytes)}';
      }

      if (!context.mounted) return;
      await persistBundle(context, bundle, avatarOverride: avatar);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  /// 从 URL 导入（自动识别 JSON / PNG 直链）→ 本地角色库
  static Future<void> importFromUrl(BuildContext context) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从 URL 导入角色卡'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'https://…/character.json 或 …/card.png',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            const Text(
              '支持角色卡 JSON / PNG 直链，自动识别格式；'
              '社区站点请先点 Download 拿到文件直链。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = CharacterImportService(_dio());
      final bundle = await service.importBundleFromUrl(url);
      if (!context.mounted) return;
      await persistBundle(context, bundle);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  static Dio _dio() {
    final d = Dio();
    d.options.connectTimeout = const Duration(seconds: 30);
    d.options.receiveTimeout = const Duration(seconds: 30);
    return d;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/character.dart';
import '../models/lorebook.dart';
import '../utils/image_data.dart' show parseDataUrl;
import '../utils/png_card_writer.dart';

/// 角色卡导出
///
/// **项目约定：角色卡以 PNG 为唯一分发格式。**
/// 导出产物 = 底图 + 内嵌 `base64(CCv3 JSON)` 的 `tEXt` 块（`chara` / `ccv3`），
/// 与 [CharacterImportService] 的 PNG 解析路径构成往返闭环。
///
/// [toCCv3] / [toSillyTavern] 仍保留：前者是 PNG 的载荷来源，也是后端
/// 发布协议（`POST /api/characters` 的 `card` 字段）的输入；它们**不再作为
/// 面向用户的导出选项**暴露。
class CharacterExportService {
  /// Export as CCv3 JSON
  ///
  /// 覆盖 Character Card v3 全部核心字段，并可回写 [lorebook] 为
  /// `character_book` 节点 —— 与 `CharacterImportService` 形成无损闭环。
  Map<String, dynamic> toCCv3(Character character, {Lorebook? lorebook}) {
    final extensions = <String, dynamic>{
      ...character.extensions,
    };
    final data = <String, dynamic>{
      'name': character.name,
      'description': character.description ?? '',
      'personality': character.personality ?? '',
      'scenario': character.scenario ?? '',
      'first_mes': character.firstMessage ?? '',
      'mes_example': _renderMesExample(character),
      'creator_notes': character.creatorNotes ?? '',
      'system_prompt': character.systemPrompt ?? '',
      'post_history_instructions': character.postHistoryInstructions ?? '',
      'alternate_greetings': character.alternateGreetings,
      'group_only_greetings': character.groupOnlyGreetings,
      'tags': character.tags,
      'creator': character.creator ?? '',
      'character_version': character.characterVersion ?? '',
      'nickname': character.nickname ?? '',
      'avatar': character.avatarPath ?? '',
      'extensions': extensions,
      if (character.creatorNotesMultilingual.isNotEmpty)
        'creator_notes_multilingual': character.creatorNotesMultilingual,
      if (lorebook != null) 'character_book': lorebook.toCharacterBook(),
    };
    if (character.source?.isNotEmpty ?? false) {
      extensions['source'] = character.source;
    }
    return {
      'spec': 'chara_card_v3',
      'spec_version': '3.0',
      'data': _dropNulls(data),
    };
  }

  /// Export as SillyTavern format
  ///
  /// 保留供后端发布协议与调试使用，**不作为面向用户的导出选项**
  /// （角色卡对外分发统一走 PNG）。
  Map<String, dynamic> toSillyTavern(Character character, {Lorebook? lorebook}) {
    return _dropNulls({
      'name': character.name,
      'description': character.description,
      'personality': character.personality,
      'scenario': character.scenario,
      'first_mes': character.firstMessage,
      'mes_example': _renderMesExample(character),
      'creator_notes': character.creatorNotes,
      'system_prompt': character.systemPrompt,
      'post_history_instructions': character.postHistoryInstructions,
      'alternate_greetings': character.alternateGreetings,
      'tags': character.tags,
      'creator': character.creator,
      'character_version': character.characterVersion,
      'avatar': character.avatarPath,
      if (lorebook != null) 'character_book': lorebook.toCharacterBook(),
    });
  }

  /// 导出为 **PNG 角色卡**字节 —— 面向用户的唯一导出形态
  ///
  /// 底图来源优先级：
  /// 1. 显式传入的 [baseImage]；
  /// 2. 角色 `avatarPath`：`data:` URL 就地解码；`http(s)` 通过 [dio] 拉取
  ///    （失败不致命，回落到占位图 —— 卡片的主体是内嵌 JSON，不该因为
  ///    一张立绘拉不到就让整个导出失败）；
  /// 3. 品牌色渐变占位图。
  Future<Uint8List> exportPngBytes(
    Character character, {
    Lorebook? lorebook,
    Uint8List? baseImage,
    Dio? dio,
  }) async {
    final card = toCCv3(character, lorebook: lorebook);
    _stripInlineAvatar(card);
    final json = const JsonEncoder.withIndent('  ').convert(card);
    final base =
        baseImage ?? await _resolveAvatarBytes(character.avatarPath, dio);
    return buildCardPng(json, baseImage: base);
  }

  /// 导出文件名（PNG）
  String pngFileName(Character character) =>
      '${_sanitize(character.name)}.png';

  /// 去掉 CCv3 载荷里的内嵌头像
  ///
  /// 导入 PNG 角色卡时会把卡片图本身写成 `data:image/png;base64,…` 存进
  /// `avatarPath`。若原样导出，这份几十到几百 KB 的 base64 会被再编码一次
  /// 塞回 tEXt 块 —— 体积翻倍，且语义上重复：PNG 自身就是立绘。
  /// 真实卡片此处写 `"none"` 或文件名，因此统一归为 `none`。
  void _stripInlineAvatar(Map<String, dynamic> card) {
    final data = card['data'];
    if (data is! Map) return;
    final avatar = data['avatar'];
    if (avatar is String && (avatar.startsWith('data:') || avatar.length > 512)) {
      data['avatar'] = 'none';
    }
  }

  Future<Uint8List?> _resolveAvatarBytes(String? path, Dio? dio) async {
    if (path == null || path.isEmpty) return null;

    if (path.startsWith('data:')) {
      final parsed = parseDataUrl(path);
      if (parsed == null) return null;
      try {
        final data = parsed.$2;
        final padded = data.padRight((data.length + 3) & ~3, '=');
        return base64Decode(padded.replaceAll('-', '+').replaceAll('_', '/'));
      } catch (_) {
        return null;
      }
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      final client = dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );
      try {
        final res = await client.get<List<int>>(
          path,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = res.data;
        if (bytes == null || bytes.isEmpty) return null;
        return Uint8List.fromList(bytes);
      } catch (_) {
        return null;
      }
    }

    // 本地文件路径：Web 无文件系统；原生端可由调用方读好后经 [baseImage] 传入
    return null;
  }

  /// 将结构化示例消息渲染回 CCv3 的 `<START>` 文本形式
  ///
  /// 若角色没有任何示例对话，返回空串（避免导出 `"mes_example": ""` 噪音）。
  String _renderMesExample(Character character) {
    final examples = character.exampleMessages;
    if (examples.isEmpty) return '';
    final buf = StringBuffer();
    for (final e in examples) {
      if (e.userMessage.trim().isNotEmpty) {
        buf.writeln('{{user}}: ${e.userMessage}');
      }
      if (e.assistantMessage.trim().isNotEmpty) {
        buf.writeln('{{char}}: ${e.assistantMessage}');
      }
      buf.writeln('<START>');
    }
    return buf.toString().trim();
  }

  Map<String, dynamic> _dropNulls(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      if (v is List && v.isEmpty) return;
      if (v is Map && v.isEmpty) return;
      out[k] = v;
    });
    return out;
  }

  /// 文件名安全化：去掉路径分隔符与 Windows 保留字符
  String _sanitize(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'character';
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }
}

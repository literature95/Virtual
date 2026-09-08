import 'dart:convert';
import 'dart:io';
import '../models/character.dart';
import '../models/lorebook.dart';

class CharacterExportService {
  /// Export as CCv3 JSON
  ///
  /// 覆盖 Character Card v3 全部核心字段，并可回写 [lorebook] 为
  /// `character_book` 节点 —— 与 [CharacterImportService] 形成无损闭环。
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

  /// Save to JSON file
  Future<void> saveToFile(Character character, String path, {String format = 'ccv3', Lorebook? lorebook}) async {
    final Map<String, dynamic> data;
    switch (format) {
      case 'ccv3':
        data = toCCv3(character, lorebook: lorebook);
        break;
      case 'sillytavern':
        data = toSillyTavern(character, lorebook: lorebook);
        break;
      default:
        data = toCCv3(character, lorebook: lorebook);
    }
    final file = File(path);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
}

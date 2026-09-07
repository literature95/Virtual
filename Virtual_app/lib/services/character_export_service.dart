import 'dart:convert';
import 'dart:io';
import '../models/character.dart';

class CharacterExportService {
  /// Export as CCv3 JSON
  Map<String, dynamic> toCCv3(Character character) {
    return {
      'spec': 'chara_card_v3',
      'data': {
        'name': character.name,
        'description': character.description,
        'personality': character.personality,
        'scenario': character.scenario,
        'first_mes': character.firstMessage,
        'system_prompt': character.systemPrompt,
        'post_history_instructions': character.postHistoryInstructions,
        'creator_notes': character.creatorNotes,
        'creator': character.creator,
        'character_version': character.characterVersion,
        'nickname': character.nickname,
        'tags': character.tags,
        'extensions': character.extensions,
      },
    };
  }

  /// Export as SillyTavern format
  Map<String, dynamic> toSillyTavern(Character character) {
    return {
      'name': character.name,
      'description': character.description,
      'personality': character.personality,
      'scenario': character.scenario,
      'first_mes': character.firstMessage,
      'system_prompt': character.systemPrompt,
      'post_history_instructions': character.postHistoryInstructions,
      'creator_notes': character.creatorNotes,
      'tags': character.tags,
    };
  }

  /// Save to JSON file
  Future<void> saveToFile(Character character, String path, {String format = 'ccv3'}) async {
    final Map<String, dynamic> data;
    switch (format) {
      case 'ccv3':
        data = toCCv3(character);
        break;
      case 'sillytavern':
        data = toSillyTavern(character);
        break;
      default:
        data = toCCv3(character);
    }
    final file = File(path);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
}
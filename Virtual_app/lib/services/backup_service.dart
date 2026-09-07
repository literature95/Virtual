import 'dart:convert';
import 'dart:io';

import '../data/app_database.dart';
import '../models/character.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/endpoint.dart';
import '../models/lorebook.dart';
import '../models/preset.dart';
import '../models/regex_rule.dart';
import '../models/chat_theme.dart';
import '../models/persona.dart';
import '../models/plugin.dart';

class BackupService {
  final AppDatabase _database;

  BackupService(this._database);

  static const _version = '1.0.0';

  /// Export all data to a JSON-compatible map
  Future<Map<String, dynamic>> exportAll() async {
    final characters = _database.getCharacters();
    final conversations = _database.getConversations();
    final endpoints = _database.getLlmEndpoints();
    final lorebooks = _database.getLorebooks();
    final presets = _database.getPresets();
    final regexRules = _database.getRegexRules();
    final themes = _database.getThemes();
    final personas = _database.getPersonas();
    final plugins = _database.getPlugins();

    // Messages keyed by conversationId
    final Map<String, List<Map<String, dynamic>>> messages = {};
    for (final conv in conversations) {
      final msgs = _database.getMessages(conv.id);
      if (msgs.isNotEmpty) {
        messages[conv.id] = msgs.map((m) => m.toJson()).toList();
      }
    }

    return {
      'backup_version': _version,
      'created_at': DateTime.now().toIso8601String(),
      'characters': characters.map((c) => c.toJson()).toList(),
      'conversations': conversations.map((c) => c.toJson()).toList(),
      'messages': messages,
      'endpoints': endpoints.map((e) => e.toJson()).toList(),
      'lorebooks': lorebooks.map((l) => l.toJson()).toList(),
      'presets': presets.map((p) => p.toJson()).toList(),
      'regex_rules': regexRules.map((r) => r.toJson()).toList(),
      'themes': themes.map((t) => t.toJson()).toList(),
      'personas': personas.map((p) => p.toJson()).toList(),
      'plugins': plugins.map((p) => p.toJson()).toList(),
    };
  }

  /// Get data statistics
  Map<String, int> getDataStats(Map<String, dynamic> data) {
    return {
      'characters': (data['characters'] as List?)?.length ?? 0,
      'conversations': (data['conversations'] as List?)?.length ?? 0,
      'endpoints': (data['endpoints'] as List?)?.length ?? 0,
      'lorebooks': (data['lorebooks'] as List?)?.length ?? 0,
      'presets': (data['presets'] as List?)?.length ?? 0,
      'regex_rules': (data['regex_rules'] as List?)?.length ?? 0,
      'themes': (data['themes'] as List?)?.length ?? 0,
      'personas': (data['personas'] as List?)?.length ?? 0,
      'plugins': (data['plugins'] as List?)?.length ?? 0,
    };
  }

  /// Import all data from a JSON map
  Future<void> importAll(Map<String, dynamic> data) async {
    final characters = data['characters'];
    if (characters is List) {
      for (final item in characters) {
        await _database.saveCharacter(
          Character.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final conversations = data['conversations'];
    if (conversations is List) {
      for (final item in conversations) {
        await _database.saveConversation(
          Conversation.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final messages = data['messages'];
    if (messages is Map) {
      for (final entry in messages.entries) {
        final convId = entry.key;
        final msgs = entry.value;
        if (msgs is List) {
          for (final item in msgs) {
            await _database.saveMessage(
              convId,
              ChatMessage.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    }

    final endpoints = data['endpoints'];
    if (endpoints is List) {
      for (final item in endpoints) {
        await _database.saveEndpoint(
          LlmEndpoint.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final lorebooks = data['lorebooks'];
    if (lorebooks is List) {
      for (final item in lorebooks) {
        await _database.saveLorebook(
          Lorebook.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final presets = data['presets'];
    if (presets is List) {
      for (final item in presets) {
        await _database.savePreset(
          Preset.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final regexRules = data['regex_rules'];
    if (regexRules is List) {
      for (final item in regexRules) {
        await _database.saveRegexRule(
          RegexRule.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final themes = data['themes'];
    if (themes is List) {
      for (final item in themes) {
        await _database.saveTheme(
          ChatTheme.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final personas = data['personas'];
    if (personas is List) {
      for (final item in personas) {
        await _database.savePersona(
          Persona.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final plugins = data['plugins'];
    if (plugins is List) {
      for (final item in plugins) {
        await _database.savePlugin(
          InstalledPlugin.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
  }

  /// Export to file and return the file path
  Future<String> exportToFile(String path) async {
    final data = await exportAll();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final file = File(path);
    await file.writeAsString(json);
    return path;
  }

  /// Import from file
  Future<void> importFromFile(String path) async {
    final file = File(path);
    final json = await file.readAsString();
    final data = jsonDecode(json) as Map<String, dynamic>;
    await importAll(data);
  }

  /// Calculate backup size in bytes
  Future<int> getBackupSize() async {
    final data = await exportAll();
    final json = jsonEncode(data);
    return utf8.encode(json).length;
  }

  /// Parse backup file and return data without importing
  Future<Map<String, dynamic>> parseBackupFile(String path) async {
    final file = File(path);
    final json = await file.readAsString();
    return jsonDecode(json) as Map<String, dynamic>;
  }
}

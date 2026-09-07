import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

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

/// 本地数据库（基于 SharedPreferences + JSON）
/// 确保项目开箱即用，后续可平滑迁移到 ObjectBox / Hive
class AppDatabase extends ChangeNotifier {
  static AppDatabase? _instance;
  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  AppDatabase._(this._prefs);

  static Future<AppDatabase> init() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = AppDatabase._(prefs);
    return _instance!;
  }

  // ---------- 存储键 ----------
  static const _kCharacters = 'db_characters';
  static const _kConversations = 'db_conversations';
  static const _kMessages = 'db_messages_';
  static const _kEndpoints = 'db_endpoints';
  static const _kLorebooks = 'db_lorebooks';
  static const _kPresets = 'db_presets';
  static const _kRegexRules = 'db_regex';
  static const _kThemes = 'db_themes';
  static const _kPersonas = 'db_personas';
  static const _kPlugins = 'db_plugins';

  // ---------- 通用读写 ----------
  List<Map<String, dynamic>> _readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  void _writeList(String key, List<Map<String, dynamic>> list) {
    _prefs.setString(key, jsonEncode(list));
  }

  String newUuid() => _uuid.v4();

  // ========== 角色 ==========
  List<Character> getCharacters() {
    return _readList(_kCharacters).map((m) => Character.fromJson(m)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Character? getCharacter(String uuid) {
    try {
      return getCharacters().firstWhere((c) => c.id == uuid);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCharacter(Character character) async {
    final list = _readList(_kCharacters);
    final index = list.indexWhere((m) => m['id'] == character.id);
    if (index >= 0) {
      list[index] = character.toJson();
    } else {
      list.add(character.toJson());
    }
    _writeList(_kCharacters, list);
    notifyListeners();
  }

  Future<void> deleteCharacter(String uuid) async {
    final list = _readList(_kCharacters);
    list.removeWhere((m) => m['id'] == uuid);
    _writeList(_kCharacters, list);
    notifyListeners();
  }

  // ========== 对话 ==========
  List<Conversation> getConversations() {
    return _readList(_kConversations)
        .map((m) => Conversation.fromJson(m))
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return b.isPinned ? 1 : -1;
        return (b.lastMessageAt ?? b.updatedAt)
            .compareTo(a.lastMessageAt ?? a.updatedAt);
      });
  }

  Conversation? getConversation(String uuid) {
    try {
      return getConversations().firstWhere((c) => c.id == uuid);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConversation(Conversation conv) async {
    final list = _readList(_kConversations);
    final index = list.indexWhere((m) => m['id'] == conv.id);
    if (index >= 0) {
      list[index] = conv.toJson();
    } else {
      list.add(conv.toJson());
    }
    _writeList(_kConversations, list);
    notifyListeners();
  }

  Future<void> deleteConversation(String uuid) async {
    final list = _readList(_kConversations);
    list.removeWhere((m) => m['id'] == uuid);
    _writeList(_kConversations, list);
    _prefs.remove('$_kMessages$uuid');
    notifyListeners();
  }

  // ========== 消息 ==========
  List<ChatMessage> getMessages(String conversationId) {
    final all = _readList('$_kMessages$conversationId');
    return all.map((m) => ChatMessage.fromJson(m)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> saveMessage(String conversationId, ChatMessage msg) async {
    final key = '$_kMessages$conversationId';
    final list = _readList(key);
    final index = list.indexWhere((m) => m['id'] == msg.id);
    if (index >= 0) {
      list[index] = msg.toJson();
    } else {
      list.add(msg.toJson());
    }
    _writeList(key, list);
    notifyListeners();
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    final key = '$_kMessages$conversationId';
    final list = _readList(key);
    list.removeWhere((m) => m['id'] == messageId);
    _writeList(key, list);
    notifyListeners();
  }

  // ========== 端点 ==========
  List<LlmEndpoint> getLlmEndpoints() {
    return _readList(_kEndpoints)
        .map((m) => LlmEndpoint.fromJson(m))
        .toList()
      ..sort((a, b) {
        if (a.isDefault != b.isDefault) return b.isDefault ? 1 : -1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  LlmEndpoint? getDefaultLlmEndpoint() {
    final endpoints = getLlmEndpoints();
    try {
      return endpoints.firstWhere((e) => e.isDefault);
    } catch (_) {
      return endpoints.isNotEmpty ? endpoints.first : null;
    }
  }

  Future<void> saveEndpoint(LlmEndpoint endpoint) async {
    final list = _readList(_kEndpoints);
    if (endpoint.isDefault) {
      for (int i = 0; i < list.length; i++) {
        if (list[i]['id'] != endpoint.id) {
          list[i]['isDefault'] = false;
        }
      }
    }
    final index = list.indexWhere((m) => m['id'] == endpoint.id);
    if (index >= 0) {
      list[index] = endpoint.toJson();
    } else {
      list.add(endpoint.toJson());
    }
    _writeList(_kEndpoints, list);
    notifyListeners();
  }

  Future<void> deleteEndpoint(String uuid) async {
    final list = _readList(_kEndpoints);
    list.removeWhere((m) => m['id'] == uuid);
    _writeList(_kEndpoints, list);
    notifyListeners();
  }

  // ========== Lorebook ==========
  List<Lorebook> getLorebooks() {
    return _readList(_kLorebooks).map((m) => Lorebook.fromJson(m)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveLorebook(Lorebook lorebook) async {
    final list = _readList(_kLorebooks);
    final index = list.indexWhere((m) => m['id'] == lorebook.id);
    if (index >= 0) {
      list[index] = lorebook.toJson();
    } else {
      list.add(lorebook.toJson());
    }
    _writeList(_kLorebooks, list);
    notifyListeners();
  }

  Future<void> deleteLorebook(String id) async {
    final list = _readList(_kLorebooks);
    list.removeWhere((m) => m['id'] == id);
    _writeList(_kLorebooks, list);
    notifyListeners();
  }

  // ========== 预设 ==========
  List<Preset> getPresets() {
    return _readList(_kPresets).map((m) => Preset.fromJson(m)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Preset? getActivePreset() {
    try {
      return getPresets().firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePreset(Preset preset) async {
    final list = _readList(_kPresets);
    if (preset.isActive) {
      for (int i = 0; i < list.length; i++) {
        if (list[i]['id'] != preset.id) {
          list[i]['isActive'] = false;
        }
      }
    }
    final index = list.indexWhere((m) => m['id'] == preset.id);
    if (index >= 0) {
      list[index] = preset.toJson();
    } else {
      list.add(preset.toJson());
    }
    _writeList(_kPresets, list);
    notifyListeners();
  }

  Future<void> deletePreset(String id) async {
    final list = _readList(_kPresets);
    list.removeWhere((m) => m['id'] == id);
    _writeList(_kPresets, list);
    notifyListeners();
  }

  // ========== 正则规则 ==========
  List<RegexRule> getRegexRules() {
    return _readList(_kRegexRules).map((m) => RegexRule.fromJson(m)).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> saveRegexRule(RegexRule rule) async {
    final list = _readList(_kRegexRules);
    final index = list.indexWhere((m) => m['id'] == rule.id);
    if (index >= 0) {
      list[index] = rule.toJson();
    } else {
      list.add(rule.toJson());
    }
    _writeList(_kRegexRules, list);
    notifyListeners();
  }

  Future<void> deleteRegexRule(String id) async {
    final list = _readList(_kRegexRules);
    list.removeWhere((m) => m['id'] == id);
    _writeList(_kRegexRules, list);
    notifyListeners();
  }

  // ========== 主题 ==========
  List<ChatTheme> getThemes() {
    return _readList(_kThemes).map((m) => ChatTheme.fromJson(m)).toList()
      ..sort((a, b) {
        if (a.isActive != b.isActive) return b.isActive ? 1 : -1;
        return b.name.compareTo(a.name);
      });
  }

  ChatTheme? getActiveTheme() {
    try {
      return getThemes().firstWhere((t) => t.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTheme(ChatTheme theme) async {
    final list = _readList(_kThemes);
    if (theme.isActive) {
      for (int i = 0; i < list.length; i++) {
        if (list[i]['id'] != theme.id) {
          list[i]['isActive'] = false;
        }
      }
    }
    final index = list.indexWhere((m) => m['id'] == theme.id);
    if (index >= 0) {
      list[index] = theme.toJson();
    } else {
      list.add(theme.toJson());
    }
    _writeList(_kThemes, list);
    notifyListeners();
  }

  Future<void> deleteTheme(String id) async {
    final list = _readList(_kThemes);
    list.removeWhere((m) => m['id'] == id);
    _writeList(_kThemes, list);
    notifyListeners();
  }

  // ========== Persona ==========
  List<Persona> getPersonas() {
    return _readList(_kPersonas).map((m) => Persona.fromJson(m)).toList()
      ..sort((a, b) {
        if (a.isActive != b.isActive) return b.isActive ? 1 : -1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  Persona? getActivePersona() {
    try {
      return getPersonas().firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePersona(Persona persona) async {
    final list = _readList(_kPersonas);
    if (persona.isActive) {
      for (int i = 0; i < list.length; i++) {
        if (list[i]['id'] != persona.id) {
          list[i]['isActive'] = false;
        }
      }
    }
    final index = list.indexWhere((m) => m['id'] == persona.id);
    if (index >= 0) {
      list[index] = persona.toJson();
    } else {
      list.add(persona.toJson());
    }
    _writeList(_kPersonas, list);
    notifyListeners();
  }

  Future<void> deletePersona(String id) async {
    final list = _readList(_kPersonas);
    list.removeWhere((m) => m['id'] == id);
    _writeList(_kPersonas, list);
    notifyListeners();
  }

  // ========== 插件 ==========
  List<InstalledPlugin> getPlugins() {
    return _readList(_kPlugins)
        .map((m) => InstalledPlugin.fromJson(m))
        .toList()
      ..sort((a, b) {
        if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
        return a.name.compareTo(b.name);
      });
  }

  Future<void> savePlugin(InstalledPlugin plugin) async {
    final list = _readList(_kPlugins);
    final index = list.indexWhere((m) => m['id'] == plugin.id);
    if (index >= 0) {
      list[index] = plugin.toJson();
    } else {
      list.add(plugin.toJson());
    }
    _writeList(_kPlugins, list);
    notifyListeners();
  }

  Future<void> deletePlugin(String id) async {
    final list = _readList(_kPlugins);
    list.removeWhere((m) => m['id'] == id);
    _writeList(_kPlugins, list);
    notifyListeners();
  }
}

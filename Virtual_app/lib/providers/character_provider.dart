import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../models/character.dart';

class CharacterProvider extends ChangeNotifier {
  final AppDatabase _db;
  final _uuid = const Uuid();

  List<Character> _characters = [];
  List<Character> get characters => _characters;

  Character? _currentCharacter;
  Character? get currentCharacter => _currentCharacter;

  CharacterProvider(this._db) {
    loadCharacters();
  }

  Future<void> loadCharacters() async {
    _characters = _db.getCharacters();
    notifyListeners();
  }

  Future<Character> createCharacter({
    required String name,
    String? nickname,
    String? description,
    String? personality,
    String? scenario,
    String? firstMessage,
    String? avatarPath,
    String? creatorNotes,
    String? systemPrompt,
    String? postHistoryInstructions,
    String? creator,
    String? characterVersion,
    String? source,
    List<String> tags = const [],
    List<String> alternateGreetings = const [],
    List<CharacterExampleMessage> exampleMessages = const [],
    List<String> groupOnlyGreetings = const [],
    Map<String, dynamic> extensions = const {},
    Map<String, String> creatorNotesMultilingual = const {},
    String? lorebookId,
    String? personaId,
    CharacterAvatarStyle avatarStyle = CharacterAvatarStyle.circle,
    CharacterBubbleStyle bubbleStyle = CharacterBubbleStyle.standard,
    CharacterBubbleFontStyle bubbleFontStyle = CharacterBubbleFontStyle.normal,
  }) async {
    final now = DateTime.now();
    final character = Character(
      id: _uuid.v4(),
      name: name,
      nickname: nickname,
      description: description,
      personality: personality,
      scenario: scenario,
      firstMessage: firstMessage,
      avatarPath: avatarPath,
      avatarStyle: avatarStyle,
      bubbleStyle: bubbleStyle,
      bubbleFontStyle: bubbleFontStyle,
      creatorNotes: creatorNotes,
      systemPrompt: systemPrompt,
      postHistoryInstructions: postHistoryInstructions,
      creator: creator,
      characterVersion: characterVersion,
      source: source,
      tags: tags,
      alternateGreetings: alternateGreetings,
      exampleMessages: exampleMessages,
      groupOnlyGreetings: groupOnlyGreetings,
      extensions: extensions,
      creatorNotesMultilingual: creatorNotesMultilingual,
      lorebookId: lorebookId,
      personaId: personaId,
      createdAt: now,
      updatedAt: now,
    );
    await _db.saveCharacter(character);
    await loadCharacters();
    return character;
  }

  Future<void> updateCharacter(Character character) async {
    final updated = character.copyWith(updatedAt: DateTime.now());
    await _db.saveCharacter(updated);
    await loadCharacters();
  }

  Future<void> deleteCharacter(String id) async {
    await _db.deleteCharacter(id);
    if (_currentCharacter?.id == id) {
      _currentCharacter = null;
    }
    await loadCharacters();
  }

  Character? getCharacter(String id) {
    try {
      return _characters.firstWhere((c) => c.id == id);
    } catch (_) {
      return _db.getCharacter(id);
    }
  }

  /// 按 ID 查找角色（同 getCharacter，语义别名）
  Character? findById(String id) => getCharacter(id);

  void setCurrentCharacter(Character? character) {
    _currentCharacter = character;
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final char = getCharacter(id);
    if (char != null) {
      await updateCharacter(char.copyWith(isFavorite: !char.isFavorite));
    }
  }

  Future<void> incrementUsage(String id) async {
    final char = getCharacter(id);
    if (char != null) {
      await updateCharacter(char.copyWith(usageCount: char.usageCount + 1));
    }
  }

  List<Character> searchCharacters(String query) {
    if (query.isEmpty) return _characters;
    final lower = query.toLowerCase();
    return _characters.where((c) {
      return c.name.toLowerCase().contains(lower) ||
          (c.description?.toLowerCase().contains(lower) ?? false) ||
          c.tags.any((t) => t.toLowerCase().contains(lower));
    }).toList();
  }

  List<Character> get favorites =>
      _characters.where((c) => c.isFavorite).toList();

  /// 复制角色（生成新 id，名称加"副本"，重置收藏与使用计数）
  Future<Character?> duplicateCharacter(String id) async {
    final source = getCharacter(id);
    if (source == null) return null;
    final copy = source.copyWith(
      id: _uuid.v4(),
      name: '${source.name} 副本',
      isFavorite: false,
      usageCount: 0,
    );
    await _db.saveCharacter(copy);
    await loadCharacters();
    return copy;
  }
}

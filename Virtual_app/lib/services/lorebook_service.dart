import '../models/lorebook.dart';
import '../models/chat_message.dart';

class LorebookMatchResult {
  final LorebookEntry entry;
  final int order;

  const LorebookMatchResult({
    required this.entry,
    required this.order,
  });
}

class LorebookService {
  final List<Lorebook> _lorebooks = [];

  List<Lorebook> get lorebooks => List.unmodifiable(_lorebooks);

  void setLorebooks(List<Lorebook> lorebooks) {
    _lorebooks
      ..clear()
      ..addAll(lorebooks);
  }

  List<LorebookMatchResult> matchEntries({
    required List<ChatMessage> messages,
    int scanDepth = 10,
    String? overrideString,
  }) {
    final results = <LorebookMatchResult>[];
    final scanMessages = messages.length > scanDepth
        ? messages.sublist(messages.length - scanDepth)
        : messages;

    final scanText =
        overrideString ?? scanMessages.map((m) => m.content).join('\n');

    for (final lorebook in _lorebooks) {
      if (!lorebook.enabled) continue;
      for (final entry in lorebook.entries) {
        if (!entry.enabled) continue;
        if (_entryMatches(entry, scanText)) {
          results.add(LorebookMatchResult(
            entry: entry,
            order: entry.order,
          ));
        }
      }
    }

    results.sort((a, b) => a.order.compareTo(b.order));
    return results;
  }

  bool _entryMatches(LorebookEntry entry, String text) {
    final sourceText = entry.caseSensitive ? text : text.toLowerCase();
    final key = entry.caseSensitive ? entry.key : entry.key.toLowerCase();

    switch (entry.matchStrategy) {
      case LorebookEntryMatchStrategy.exact:
        if (sourceText.contains(key)) {
          if (entry.secondaryKeys.isEmpty) return true;
          return entry.secondaryKeys.every((sk) {
            final skLower = entry.caseSensitive ? sk : sk.toLowerCase();
            return sourceText.contains(skLower);
          });
        }
        return false;

      case LorebookEntryMatchStrategy.partial:
        if (sourceText.contains(key)) {
          if (entry.secondaryKeys.isEmpty) return true;
          return entry.secondaryKeys.every((sk) {
            final skLower = entry.caseSensitive ? sk : sk.toLowerCase();
            return sourceText.contains(skLower);
          });
        }
        return false;

      case LorebookEntryMatchStrategy.regex:
        try {
          final regex = RegExp(key, caseSensitive: entry.caseSensitive);
          if (!regex.hasMatch(sourceText)) return false;
          if (entry.secondaryKeys.isEmpty) return true;
          return entry.secondaryKeys.every((sk) {
            final skRegex = RegExp(sk, caseSensitive: entry.caseSensitive);
            return skRegex.hasMatch(sourceText);
          });
        } catch (_) {
          return false;
        }
    }
  }

  String injectEntries({
    required List<LorebookMatchResult> matches,
    required String systemPrompt,
  }) {
    final beforeSystem = <String>[];
    final afterSystem = <String>[];
    final beforeUser = <String>[];
    final afterUser = <String>[];
    final beforeAssistant = <String>[];
    final afterAssistant = <String>[];
    final top = <String>[];
    final bottom = <String>[];

    for (final match in matches) {
      final content = match.entry.content;
      switch (match.entry.position) {
        case LorebookEntryPosition.beforeSystem:
          beforeSystem.add(content);
          break;
        case LorebookEntryPosition.afterSystem:
          afterSystem.add(content);
          break;
        case LorebookEntryPosition.beforeUser:
          beforeUser.add(content);
          break;
        case LorebookEntryPosition.afterUser:
          afterUser.add(content);
          break;
        case LorebookEntryPosition.beforeAssistant:
          beforeAssistant.add(content);
          break;
        case LorebookEntryPosition.afterAssistant:
          afterAssistant.add(content);
          break;
        case LorebookEntryPosition.top:
          top.add(content);
          break;
        case LorebookEntryPosition.bottom:
          bottom.add(content);
          break;
      }
    }

    final parts = <String>[];
    if (top.isNotEmpty) parts.add(top.join('\n\n'));
    if (beforeSystem.isNotEmpty) parts.add(beforeSystem.join('\n\n'));
    parts.add(systemPrompt);
    if (afterSystem.isNotEmpty) parts.add(afterSystem.join('\n\n'));
    if (beforeUser.isNotEmpty) parts.add(beforeUser.join('\n\n'));
    if (afterUser.isNotEmpty) parts.add(afterUser.join('\n\n'));
    if (beforeAssistant.isNotEmpty) parts.add(beforeAssistant.join('\n\n'));
    if (afterAssistant.isNotEmpty) parts.add(afterAssistant.join('\n\n'));
    if (bottom.isNotEmpty) parts.add(bottom.join('\n\n'));

    return parts.join('\n\n');
  }
}

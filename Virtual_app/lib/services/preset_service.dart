import 'package:uuid/uuid.dart';

import '../models/preset.dart';

class PresetService {
  final _uuid = const Uuid();

  /// Build a merged prompt list from a preset, ordered by position priority.
  List<PresetEntry> buildOrderedEntries(Preset preset) {
    final enabled = preset.entries.where((e) => e.enabled).toList()
      ..sort((a, b) {
        final pa = _positionIndex(a.position);
        final pb = _positionIndex(b.position);
        if (pa != pb) return pa.compareTo(pb);
        return a.order.compareTo(b.order);
      });
    return enabled;
  }

  /// Merge all enabled entries into a single system prompt string.
  String mergePrompt(Preset preset) {
    final ordered = buildOrderedEntries(preset);
    final buffer = StringBuffer();
    for (final entry in ordered) {
      if (entry.role != PresetEntryRole.system) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(entry.content);
    }
    // Also collect non-system entries as separate role messages
    final parts = <String>[];
    for (final entry in ordered) {
      if (entry.role == PresetEntryRole.system) continue;
      parts.add('[${entry.role.name}] ${entry.label}:\n${entry.content}');
    }
    if (parts.isNotEmpty) {
      buffer.writeln();
      buffer.write(parts.join('\n\n'));
    }
    return buffer.toString();
  }

  /// Resolve macro variables like {{char}}, {{user}}, {{time}} etc.
  String resolveMacros(String content, {Map<String, String> macros = const {}}) {
    var result = content;
    for (final entry in macros.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  /// Create a new preset with a default system prompt entry.
  Preset createDefaultPreset({String name = '新预设'}) {
    final now = DateTime.now();
    return Preset(
      id: _uuid.v4(),
      name: name,
      description: '',
      entries: [
        PresetEntry(
          id: _uuid.v4(),
          label: 'System Prompt',
          type: PresetEntryType.systemPrompt,
          role: PresetEntryRole.system,
          position: PresetEntryPosition.top,
          content: '',
          order: 0,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Duplicate a preset with new IDs.
  Preset duplicatePreset(Preset source) {
    final now = DateTime.now();
    return Preset(
      id: _uuid.v4(),
      name: '${source.name} (副本)',
      description: source.description,
      entries: source.entries
          .map((e) => PresetEntry(
                id: _uuid.v4(),
                label: e.label,
                type: e.type,
                role: e.role,
                position: e.position,
                content: e.content,
                enabled: e.enabled,
                order: e.order,
                insertOnce: e.insertOnce,
                condition: e.condition,
              ))
          .toList(),
      createdAt: now,
      updatedAt: now,
    );
  }

  int _positionIndex(PresetEntryPosition position) {
    switch (position) {
      case PresetEntryPosition.top:
        return 0;
      case PresetEntryPosition.beforeSystem:
        return 1;
      case PresetEntryPosition.afterSystem:
        return 2;
      case PresetEntryPosition.beforeFirstUser:
        return 3;
      case PresetEntryPosition.beforeLastUser:
        return 4;
      case PresetEntryPosition.afterLastUser:
        return 5;
      case PresetEntryPosition.beforeAssistant:
        return 6;
      case PresetEntryPosition.afterAssistant:
        return 7;
      case PresetEntryPosition.bottom:
        return 8;
    }
  }
}

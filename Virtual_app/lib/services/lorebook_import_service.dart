import 'dart:convert';
import 'dart:typed_data';

import '../models/lorebook.dart';

/// 一次世界书导入的产物
class LorebookImportResult {
  /// 解析出的世界书
  final Lorebook lorebook;

  /// 识别出的来源形态：`SillyTavern World Info` / `Character Card v3
  /// character_book` / `Virtual Lorebook`
  final String sourceFormat;

  /// 导入过程中产生的提示（字段降级、被跳过的条目等）
  final List<String> warnings;

  const LorebookImportResult({
    required this.lorebook,
    required this.sourceFormat,
    this.warnings = const [],
  });

  /// 人类可读的导入摘要，用于 UI 提示
  String get summary {
    final b = StringBuffer()
      ..write(sourceFormat)
      ..write(' · ${lorebook.entries.length} 个条目');
    final enabled = lorebook.entries.where((e) => e.enabled).length;
    b.write('（$enabled 个启用）');
    if (warnings.isNotEmpty) b.write(' · ${warnings.length} 条提示');
    return b.toString();
  }
}

/// 世界书（Lorebook）导入
///
/// 承担一件事：把**各种世界书 JSON 形态**归一化成 [Lorebook]。
///
/// 与角色卡的关系：按项目约定，**角色卡用 PNG、世界书用 JSON**。
/// 角色卡内嵌的 `character_book` 仍由 [CharacterImportService] 随卡解析；
/// 本服务只处理独立的世界书文件。
class LorebookImportService {
  /// 从原始字节导入 —— 平台无关主入口
  LorebookImportResult importFromBytes(
    Uint8List bytes, {
    String? sourceName,
  }) {
    final label = sourceName ?? '文件';
    // allowMalformed：世界书里混入非法字节时不应整包失败，交给 jsonDecode 判定
    final text = utf8.decode(bytes, allowMalformed: true);
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('{')) {
      throw Exception(
        '$label 不是世界书 JSON —— 世界书必须是 JSON 对象'
        '（角色卡请用 PNG 文件导入）',
      );
    }
    return importFromJsonText(text, sourceName: sourceName);
  }

  /// 从 JSON 文本导入（容忍 BOM 与前后空白）
  LorebookImportResult importFromJsonText(
    String text, {
    String? sourceName,
  }) {
    final decoded = jsonDecode(_stripBom(text));
    if (decoded is! Map) {
      throw Exception('世界书 JSON 的顶层必须是对象');
    }
    return importFromJson(
      Map<String, dynamic>.from(decoded),
      fallbackName: _nameFromFileName(sourceName),
    );
  }

  /// 从 JSON 对象导入 —— 形态自动识别
  ///
  /// 识别顺序：
  /// 1. `entries` 是**对象** → SillyTavern World Info（真实世界书的主流形态，
  ///    实测磁盘 231 个文件中 221 个属于此类）；
  /// 2. `entries` 是**数组**且带 `createdAt` → 本 App 导出的世界书；
  /// 3. `entries` 是**数组** → CCv3 `character_book`；
  /// 4. 有 `spec` / `data` → 是角色卡，给出可操作的引导而非静默失败。
  LorebookImportResult importFromJson(
    Map<String, dynamic> json, {
    String? fallbackName,
  }) {
    final warnings = <String>[];

    // 4) 角色卡：明确告知改用角色卡入口，避免用户以为世界书文件损坏
    if (json['spec'] != null || json['data'] is Map) {
      throw Exception(
        '这是一个角色卡文件，不是世界书。请用「导入角色卡」入口'
        '（角色卡使用 PNG 格式），其中的 character_book 会随卡一并导入。',
      );
    }

    final rawEntries = json['entries'];

    if (rawEntries is Map) {
      _collectWarnings(rawEntries, warnings);
      final lorebook = Lorebook.fromWorldInfo(json, fallbackName: fallbackName);
      return LorebookImportResult(
        lorebook: lorebook,
        sourceFormat: 'SillyTavern World Info',
        warnings: warnings,
      );
    }

    if (rawEntries is List) {
      // 2) 本 App 自身导出的形态（带本地 id / createdAt）
      final isAppExport =
          json.containsKey('createdAt') && json['entries'] is List;
      if (isAppExport) {
        return LorebookImportResult(
          lorebook: Lorebook.fromJson(json),
          sourceFormat: 'Virtual Lorebook',
        );
      }
      // 3) CCv3 character_book
      final lorebook = Lorebook.fromCharacterBook(
        json,
        fallbackName: fallbackName,
      );
      if (lorebook.entries.isEmpty && rawEntries.isNotEmpty) {
        warnings.add('${rawEntries.length} 个条目均无法解析，请检查 JSON 结构');
      }
      return LorebookImportResult(
        lorebook: lorebook,
        sourceFormat: 'Character Card v3 character_book',
        warnings: warnings,
      );
    }

    throw Exception(
      '未找到世界书条目：JSON 缺少 entries 字段。'
      '支持 SillyTavern World Info（entries 为对象）与 CCv3 character_book'
      '（entries 为数组）两种形态。',
    );
  }

  /// 统计无法解析的条目，避免「导入成功但条目凭空少了几条」
  void _collectWarnings(Map<dynamic, dynamic> rawEntries, List<String> out) {
    var skipped = 0;
    for (final v in rawEntries.values) {
      if (v is! Map) skipped++;
    }
    if (skipped > 0) out.add('$skipped 个条目不是对象，已跳过');
    if (rawEntries.isEmpty) out.add('世界书没有任何条目');
  }

  String _stripBom(String text) =>
      text.startsWith('\uFEFF') ? text.substring(1) : text;

  /// 从文件名推断世界书名（去扩展名与路径）
  ///
  /// 221 个真实世界书里只有 7 个带顶层 `name`，其余靠文件名区分——
  /// 若一律落到默认名，用户会看到一屏同名「World Book」。
  String? _nameFromFileName(String? sourceName) {
    if (sourceName == null || sourceName.trim().isEmpty) return null;
    var name = sourceName.replaceAll('\\', '/').split('/').last;
    for (final ext in const ['.json', '.JSON']) {
      if (name.endsWith(ext)) {
        name = name.substring(0, name.length - ext.length);
        break;
      }
    }
    name = name.trim();
    return name.isEmpty ? null : name;
  }
}

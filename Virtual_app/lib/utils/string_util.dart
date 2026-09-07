import 'dart:convert';
import 'dart:typed_data';

class StringUtil {
  static String truncate(String text, int maxLen, {String suffix = '...'}) {
    if (text.length <= maxLen) return text;
    return text.substring(0, maxLen - suffix.length) + suffix;
  }

  static String countTokens(String text) {
    // 粗略估算：中文每字算1 token，英文每4字符算1 token
    int count = 0;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code > 127) {
        count++;
      }
    }
    final enChars = text.replaceAll(RegExp(r'[^\x00-\x7F]'), '').length;
    count += (enChars / 4).ceil();
    return count.toString();
  }

  static String base64Encode(Uint8List bytes) {
    return base64.encode(bytes);
  }

  static Uint8List base64Decode(String encoded) {
    return base64.decode(encoded);
  }

  static String removeMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')
        .replaceAll(RegExp(r'`(.*?)`'), r'$1')
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1')
        .replaceAll(RegExp(r'>\s*'), '');
  }

  static String extractFirstLine(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}

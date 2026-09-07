import '../models/regex_rule.dart';

class RegexService {
  final List<RegexRule> _rules = [];

  List<RegexRule> get rules => List.unmodifiable(_rules);

  void setRules(List<RegexRule> rules) {
    _rules
      ..clear()
      ..addAll(rules);
  }

  /// Apply all enabled regex rules to the given [input] string,
  /// filtered by [timing] and optionally by [role].
  String applyRules({
    required String input,
    required RegexEntryTiming timing,
    String? role,
  }) {
    var result = input;
    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.timing != timing) continue;
      result = rule.apply(result);
    }
    return result;
  }

  /// Apply a single rule to [input] and return the result.
  String applySingle(RegexRule rule, String input) {
    return rule.apply(input);
  }

  /// Test a rule against sample text, returns the transformed result.
  String testRule(RegexRule rule, String input) {
    return rule.apply(input);
  }

  /// Validate a regex pattern. Returns null if valid, error message otherwise.
  static String? validatePattern(
    String pattern, {
    bool caseSensitive = false,
    bool multiline = false,
    bool dotAll = false,
  }) {
    if (pattern.isEmpty) return null;
    try {
      RegExp(
        pattern,
        caseSensitive: caseSensitive,
        multiLine: multiline,
        dotAll: dotAll,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Preview capture group replacement.
  /// Returns a list of captured groups from the pattern match.
  static List<String> captureGroups({
    required String pattern,
    required String input,
    bool caseSensitive = false,
    bool multiline = false,
    bool dotAll = false,
  }) {
    try {
      final regex = RegExp(
        pattern,
        caseSensitive: caseSensitive,
        multiLine: multiline,
        dotAll: dotAll,
      );
      final match = regex.firstMatch(input);
      if (match == null) return [];
      return List.generate(
        match.groupCount,
        (i) => match.group(i + 1) ?? '',
      );
    } catch (_) {
      return [];
    }
  }
}

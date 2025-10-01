class CodePatterns {
  /// Container class for regular expression patterns used in code analysis.
  /// Regex for matching pragma annotations.
  final RegExp pragmaRegex = RegExp(
    r'''^\s*@pragma\s*\(\s*[\'"]((?:vm:entry-point)|(?:vm:external-name)|(?:vm:prefer-inline)|(?:vm:exact-result-type)|(?:vm:never-inline)|(?:vm:non-nullable-by-default)|(?:flutter:keep-to-string)|(?:flutter:keep-to-string-in-subtypes))[\'"]\s*(?:,\s*[^)]+)?\s*\)\s*$''',
    multiLine: false,
  );

  /// Patterns for matching different code entities.
  final Map<String, RegExp> patterns = {
    'class': RegExp(
      r'class\s+(\w+)(?:<[^>]*>)?(?:\s+extends\s+\w+(?:<[^>]*>)?)?(?:\s+with\s+[\w\s,<>]+)?(?:\s+implements\s+[\w\s,<>]+)?\s*\{',
    ),
    'enum': RegExp(r'enum\s+(\w+)(?:\s+with\s+[\w\s,<>]+)?\s*\{'),
    'extension': RegExp(
      r'extension\s+(\w+)(?:<[^>]*>)?\s+on\s+[\w<>\s,]+\s*\{',
    ),
    'mixin': RegExp(r'mixin\s+(\w+)(?:<[^>]*>)?(?:\s+on\s+[\w\s,<>]+)?\s*\{'),
  };
}

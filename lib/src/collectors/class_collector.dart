import 'package:dead_code_analyzer/dead_code_analyzer.dart';

/// Collects and analyzes class definitions from Dart source code
class ClassCollector {
  /// Collects class information from a specific line in the source code
  static void collectClassFromLine({
    required RegExpMatch? classMatch,
    required int lineIndex,
    required RegExp pragmaRegex,
    required List<String> lines,
    required Map<String, ClassInfo> classes,
    required String filePath,
    required bool insideStateClass,
  }) {
    final analyzer = _ClassLineAnalyzer(
      lines: lines,
      lineIndex: lineIndex,
      pragmaRegex: pragmaRegex,
      filePath: filePath,
      insideStateClass: insideStateClass,
    );

    final classInfo = analyzer.analyzeClassDefinition();
    if (classInfo != null) {
      classes[classInfo.name] = classInfo.info;
    }
  }
}

/// Analyzes a single line for class definitions
class _ClassLineAnalyzer {
  const _ClassLineAnalyzer({
    required this.lines,
    required this.lineIndex,
    required this.pragmaRegex,
    required this.filePath,
    required this.insideStateClass,
  });

  final List<String> lines;
  final int lineIndex;
  final RegExp pragmaRegex;
  final String filePath;
  final bool insideStateClass;

  String get currentLine => lines[lineIndex];
  String get trimmedLine => currentLine.trim();

  /// Analyzes the current line for class definitions
  ClassDefinitionResult? analyzeClassDefinition() {
    if (trimmedLine.isEmpty) return null;

    final patternMatcher = _ClassPatternMatcher(trimmedLine);
    final matchResult = patternMatcher.findClassDefinition();

    if (matchResult == null) return null;
    if (_isDartKeyword(matchResult.className)) return null;

    final commentAnalyzer = _CommentAnalyzer(lines, lineIndex);
    final isCommentedOut = commentAnalyzer.isLineCommented();

    final classInfo = ClassInfo(
      filePath,
      isEntryPoint: _hasEntryPointPragma(),
      commentedOut: isCommentedOut,
      type: matchResult.classType,
      lineIndex: lineIndex,
      startPosition: _calculateStartPosition(),
    );

    return ClassDefinitionResult(name: matchResult.className, info: classInfo);
  }

  /// Checks if the class has an entry point pragma annotation
  bool _hasEntryPointPragma() {
    const maxLookback = 5;

    for (int i = 1; i <= maxLookback && lineIndex - i >= 0; i++) {
      final prevLine = lines[lineIndex - i].trim();

      if (pragmaRegex.hasMatch(prevLine)) {
        return true;
      }

      // Stop if we hit actual code (not comments or annotations)
      if (_isActualCode(prevLine)) {
        break;
      }
    }

    return false;
  }

  /// Checks if a line contains actual code (not comments or annotations)
  bool _isActualCode(String line) {
    if (line.isEmpty ||
        line.startsWith('//') ||
        line.startsWith('/*') ||
        line.startsWith('*') ||
        line.startsWith('*/') ||
        line.startsWith('@') ||
        line.startsWith('///')) {
      return false;
    }

    // Check if it's a class/enum/mixin/extension/typedef declaration
    final classKeywords = ['class', 'enum', 'mixin', 'extension', 'typedef'];
    return !classKeywords.any(line.contains);
  }

  /// Calculates the start position of the class definition in the file
  int _calculateStartPosition() {
    int position = 0;

    // Sum lengths of all previous lines including newline characters
    for (int i = 0; i < lineIndex; i++) {
      position += lines[i].length + 1;
    }

    // Add leading whitespace offset
    final leadingWhitespace =
        currentLine.length - currentLine.trimLeft().length;
    return position + leadingWhitespace;
  }

  /// Checks if an identifier is a reserved Dart keyword
  bool _isDartKeyword(String identifier) {
    return Helper.keywords.contains(identifier.toLowerCase());
  }
}

/// Matches class definition patterns in source code
class _ClassPatternMatcher {
  const _ClassPatternMatcher(this.line);

  final String line;

  /// Finds class definitions using pattern matching
  ClassMatchResult? findClassDefinition() {
    // Check mixin class first (most specific)
    final mixinClassResult = _tryMatchMixinClass();
    if (mixinClassResult != null) return mixinClassResult;

    // Check other patterns
    for (final pattern in _classPatterns) {
      final match = pattern.regex.firstMatch(line);
      if (match != null) {
        final className = _extractClassName(match, pattern);
        final classType = _determineClassType(pattern.type);

        return ClassMatchResult(className: className, classType: classType);
      }
    }

    return null;
  }

  /// Attempts to match mixin class pattern specifically
  ClassMatchResult? _tryMatchMixinClass() {
    if (!line.contains('mixin class')) return null;

    final pattern = _classPatterns.firstWhere(
      (p) => p.type == PatternType.mixinClass,
    );

    final match = pattern.regex.firstMatch(line);
    if (match != null) {
      return ClassMatchResult(
        className: match.group(1)!,
        classType: 'mixin_class',
      );
    }

    return null;
  }

  /// Extracts class name from regex match based on pattern type
  String _extractClassName(RegExpMatch match, ClassPattern pattern) {
    final baseName = match.group(1)!;

    if (pattern.type == PatternType.anonymousExtension) {
      return 'ExtensionOn ${baseName.replaceAll(RegExp(r'[<>,\s]'), '')}';
    }

    return baseName;
  }

  /// Determines the specific class type from the matched line
  String _determineClassType(PatternType patternType) {
    switch (patternType) {
      case PatternType.regularClass:
        return _analyzeClassModifiers();
      case PatternType.enumType:
        return 'enum';
      case PatternType.mixinType:
        return 'mixin';
      case PatternType.namedExtension:
      case PatternType.anonymousExtension:
        return 'extension';
      case PatternType.typedef:
        return 'typedef';
      case PatternType.mixinClass:
        return 'mixin_class';
    }
  }

  /// Analyzes class modifiers and inheritance to determine specific type
  String _analyzeClassModifiers() {
    final lowerLine = line.toLowerCase();

    if (lowerLine.contains('sealed')) return 'sealed_class';
    if (lowerLine.contains('base')) return 'base_class';
    if (lowerLine.contains('final')) return 'final_class';
    if (lowerLine.contains('interface')) return 'interface_class';
    if (lowerLine.contains('abstract')) return 'abstract_class';
    if (lowerLine.contains('extends state<') || lowerLine.contains('state<')) {
      return 'state_class';
    }
    if (lowerLine.contains('extends statelesswidget')) {
      return 'stateless_widget';
    }
    if (lowerLine.contains('extends statefulwidget')) return 'stateful_widget';

    return 'class';
  }

  /// Predefined patterns for different class definition types
  static final List<ClassPattern> _classPatterns = [
    ClassPattern(
      regex:
          r'^\s*(?:\/\/+\s*|\*\s*)?(?:sealed\s+|abstract\s+|base\s+|final\s+|interface\s+)*class\s+([A-Za-z_][A-Za-z0-9_]*)',
      type: PatternType.regularClass,
    ),
    ClassPattern(
      regex: r'^\s*(?:\/\/+\s*|\*\s*)?enum\s+([A-Za-z_][A-Za-z0-9_]*)',
      type: PatternType.enumType,
    ),
    ClassPattern(
      regex: r'^\s*(?:\/\/+\s*|\*\s*)?mixin\s+([A-Za-z_][A-Za-z0-9_]*)',
      type: PatternType.mixinType,
    ),
    ClassPattern(
      regex:
          r'^\s*(?:\/\/+\s*|\*\s*)?extension\s+([A-Za-z_][A-Za-z0-9_]*(?:<[^>]*>)?)\s+on\s+',
      type: PatternType.namedExtension,
    ),
    ClassPattern(
      regex:
          r'^\s*(?:\/\/+\s*|\*\s*)?extension\s+on\s+([A-Za-z_][A-Za-z0-9_<>,\s]*)',
      type: PatternType.anonymousExtension,
    ),
    ClassPattern(
      regex: r'^\s*(?:\/\/+\s*|\*\s*)?typedef\s+([A-Za-z_][A-Za-z0-9_]*)',
      type: PatternType.typedef,
    ),
    ClassPattern(
      regex: r'^\s*(?:\/\/+\s*|\*\s*)?mixin\s+class\s+([A-Za-z_][A-Za-z0-9_]*)',
      type: PatternType.mixinClass,
    ),
  ];
}

/// Analyzes comment patterns in source code
class _CommentAnalyzer {
  const _CommentAnalyzer(this.lines, this.lineIndex);

  final List<String> lines;
  final int lineIndex;

  String get currentLine => lines[lineIndex].trim();

  /// Checks if the current line is commented out
  bool isLineCommented() {
    // Check for single-line comments
    if (currentLine.startsWith('//')) return true;

    // Check for multi-line comment markers
    if (currentLine.startsWith('*') || currentLine.startsWith('*/')) {
      return true;
    }

    // Check if we're inside a multi-line comment block
    return _isInsideMultiLineComment();
  }

  /// Checks if the current line is inside a multi-line comment
  bool _isInsideMultiLineComment() {
    bool inComment = false;

    for (int i = 0; i <= lineIndex; i++) {
      final line = lines[i];
      inComment = _processLineForComments(line, inComment);
    }

    return inComment;
  }

  /// Processes a line to track multi-line comment state
  bool _processLineForComments(String line, bool currentlyInComment) {
    bool inComment = currentlyInComment;

    for (int i = 0; i < line.length - 1; i++) {
      final twoChar = line.substring(i, i + 2);

      if (twoChar == '/*') {
        inComment = true;
        i++; // Skip next character
      } else if (twoChar == '*/') {
        inComment = false;
        i++; // Skip next character
      }
    }

    return inComment;
  }
}

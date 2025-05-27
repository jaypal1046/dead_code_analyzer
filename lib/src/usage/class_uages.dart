import 'package:dead_code_analyzer/src/model/class_info.dart';

class OptimizedClassAnalyzer {
  // Cache compiled regex patterns
  static final Map<String, RegExp> _regexCache = <String, RegExp>{};
  static final Map<String, List<String>> _routePatternCache = <String, List<String>>{};
  static final Map<String, List<String>> _stringIdentifierCache = <String, List<String>>{};
  
  // Pre-compiled common patterns
  static final RegExp _classDefPattern = RegExp(r'^\s*class\s+(\w+)');
  static final RegExp _importPattern = RegExp(r'^\s*import\s+');
  static final RegExp _exportPattern = RegExp(r'^\s*export\s+');
  static final RegExp _commentStartPattern = RegExp(r'//');
  static final RegExp _multiCommentPattern = RegExp(r'/\*.*?\*/', dotAll: true);
  
  // Trie for efficient string matching
  static final TrieNode _classNameTrie = TrieNode();

  static void initializeTrie(Map<String, ClassInfo> classes) {
    _classNameTrie.clear();
    for (final className in classes.keys) {
      _classNameTrie.insert(className);
    }
  }

  void analyzeClassUsages(
      String content, String filePath, Map<String, ClassInfo> classes) {
    
    // Initialize trie if not done
    if (_classNameTrie.isEmpty) {
      initializeTrie(classes);
    }
    
    // Pre-process content once
    final preprocessedContent = _preprocessContent(content);
    
    // Use batch processing for multiple classes
    _batchAnalyzeClasses(preprocessedContent, filePath, classes);
  }

  PreprocessedContent _preprocessContent(String content) {
    final lines = content.split('\n');
    final lineStarts = <int>[];
    final commentRanges = <Range>[];
    final stringRanges = <Range>[];
    
    int currentPos = 0;
    for (int i = 0; i < lines.length; i++) {
      lineStarts.add(currentPos);
      currentPos += lines[i].length + 1; // +1 for newline
    }
    
    // Find comment ranges
    _findCommentRanges(content, commentRanges);
    
    // Find string ranges
    _findStringRanges(content, stringRanges);
    
    return PreprocessedContent(
      content: content,
      lines: lines,
      lineStarts: lineStarts,
      commentRanges: commentRanges,
      stringRanges: stringRanges,
    );
  }

  void _batchAnalyzeClasses(
      PreprocessedContent preprocessed, 
      String filePath, 
      Map<String, ClassInfo> classes) {
    
    // Find all potential class name matches in one pass
    final allMatches = _findAllClassMatches(preprocessed.content, classes.keys);
    
    // Group matches by class name
    final matchesByClass = <String, List<Match>>{};
    for (final match in allMatches) {
      matchesByClass.putIfAbsent(match.className, () => <Match>[]).add(match);
    }
    
    // Process each class
    for (final entry in classes.entries) {
      final className = entry.key;
      final classInfo = entry.value;
      final matches = matchesByClass[className] ?? <Match>[];
      
      _processClassMatches(
        preprocessed, 
        matches, 
        className, 
        classInfo, 
        filePath
      );
    }
  }

  List<Match> _findAllClassMatches(String content, Iterable<String> classNames) {
    final matches = <Match>[];
    
    // Use a single pass with Aho-Corasick algorithm simulation
    for (int i = 0; i < content.length; i++) {
      for (final className in classNames) {
        if (_matchesAtPosition(content, i, className)) {
          matches.add(Match(className, i, i + className.length));
        }
      }
    }
    
    return matches;
  }

  bool _matchesAtPosition(String content, int position, String pattern) {
    if (position + pattern.length > content.length) return false;
    
    // Check word boundary before
    if (position > 0 && _isWordChar(content.codeUnitAt(position - 1))) {
      return false;
    }
    
    // Check pattern match
    for (int i = 0; i < pattern.length; i++) {
      if (content.codeUnitAt(position + i) != pattern.codeUnitAt(i)) {
        return false;
      }
    }
    
    // Check word boundary after
    final endPos = position + pattern.length;
    if (endPos < content.length && _isWordChar(content.codeUnitAt(endPos))) {
      return false;
    }
    
    return true;
  }

  bool _isWordChar(int codeUnit) {
    return (codeUnit >= 65 && codeUnit <= 90) ||  // A-Z
           (codeUnit >= 97 && codeUnit <= 122) ||  // a-z
           (codeUnit >= 48 && codeUnit <= 57) ||   // 0-9
           codeUnit == 95;                         // _
  }

  void _processClassMatches(
      PreprocessedContent preprocessed,
      List<Match> matches,
      String className,
      ClassInfo classInfo,
      String filePath) {
    
    var usageCount = 0;
    
    for (final match in matches) {
      if (_shouldExcludeMatch(preprocessed, match, className)) {
        continue;
      }
      usageCount++;
    }
    
    // Add indirect usage count (optimized)
    usageCount += _countIndirectUsageOptimized(preprocessed.content, className);
    
    // Update class info
    if (filePath == classInfo.definedInFile) {
      classInfo.internalUsageCount = usageCount;
    } else if (usageCount > 0) {
      classInfo.externalUsages[filePath] = usageCount;
    }
  }

  bool _shouldExcludeMatch(
      PreprocessedContent preprocessed, 
      Match match, 
      String className) {
    
    // Check if in comment or string
    if (_isInCommentOrString(preprocessed, match.start)) {
      return true;
    }
    
    // Get line info efficiently
    final lineIndex = _getLineIndex(preprocessed.lineStarts, match.start);
    final line = preprocessed.lines[lineIndex];
    
    // Use cached regex patterns for exclusion checks
    return _isDefinitionMatch(line, className, match);
  }

  bool _isInCommentOrString(PreprocessedContent preprocessed, int position) {
    // Binary search in sorted ranges
    return _isInRanges(preprocessed.commentRanges, position) ||
           _isInRanges(preprocessed.stringRanges, position);
  }

  bool _isInRanges(List<Range> ranges, int position) {
    int left = 0, right = ranges.length - 1;
    
    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final range = ranges[mid];
      
      if (position >= range.start && position <= range.end) {
        return true;
      } else if (position < range.start) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    
    return false;
  }

  int _getLineIndex(List<int> lineStarts, int position) {
    int left = 0, right = lineStarts.length - 1;
    
    while (left <= right) {
      final mid = (left + right) ~/ 2;
      
      if (mid == lineStarts.length - 1 || 
          (position >= lineStarts[mid] && position < lineStarts[mid + 1])) {
        return mid;
      } else if (position < lineStarts[mid]) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    
    return lineStarts.length - 1;
  }

  // Optimized indirect usage counting
  int _countIndirectUsageOptimized(String content, String className) {
    var count = 0;
    
    // Use cached patterns
    final routePatterns = _getRoutePatterns(className);
    final stringIdentifiers = _getStringIdentifiers(className);
    
    // Batch search for all patterns
    count += _batchPatternSearch(content, routePatterns, r'''[\'"]({pattern})[\'"]''');
    count += _batchPatternSearch(content, stringIdentifiers, r'''[\'"]({pattern})[\'"]''');
    
    // Other pattern searches (optimized)
    count += _countNavigationPatternsOptimized(content, routePatterns);
    count += _countProviderPatternsOptimized(content, className);
    count += _countGenericUsageOptimized(content, className);
    count += _countFilePathReferencesOptimized(content, className);
    
    return count;
  }

  int _batchPatternSearch(String content, List<String> patterns, String template) {
    var count = 0;
    for (final pattern in patterns) {
      final regex = _getCachedRegex(template.replaceAll('{pattern}', RegExp.escape(pattern)));
      count += regex.allMatches(content).length;
    }
    return count;
  }

  // Cached pattern generators
  List<String> _getRoutePatterns(String className) {
    return _routePatternCache.putIfAbsent(className, () => _generateRoutePatterns(className));
  }

  List<String> _getStringIdentifiers(String className) {
    return _stringIdentifierCache.putIfAbsent(className, () => _generateStringIdentifiers(className));
  }

  RegExp _getCachedRegex(String pattern) {
    return _regexCache.putIfAbsent(pattern, () => RegExp(pattern));
  }

  // Optimized helper methods
  void _findCommentRanges(String content, List<Range> ranges) {
    // Single-line comments
    final lines = content.split('\n');
    int pos = 0;
    for (final line in lines) {
      final commentIndex = line.indexOf('//');
      if (commentIndex != -1) {
        ranges.add(Range(pos + commentIndex, pos + line.length));
      }
      pos += line.length + 1;
    }
    
    // Multi-line comments
    final multiMatches = _multiCommentPattern.allMatches(content);
    for (final match in multiMatches) {
      ranges.add(Range(match.start, match.end));
    }
    
    // Sort ranges for binary search
    ranges.sort((a, b) => a.start.compareTo(b.start));
  }

  void _findStringRanges(String content, List<Range> ranges) {
    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    bool escaped = false;
    int stringStart = -1;
    
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      
      if (escaped) {
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        continue;
      }
      
      if (char == "'" && !inDoubleQuote) {
        if (!inSingleQuote) {
          inSingleQuote = true;
          stringStart = i;
        } else {
          inSingleQuote = false;
          ranges.add(Range(stringStart, i));
        }
      } else if (char == '"' && !inSingleQuote) {
        if (!inDoubleQuote) {
          inDoubleQuote = true;
          stringStart = i;
        } else {
          inDoubleQuote = false;
          ranges.add(Range(stringStart, i));
        }
      }
    }
    
    // Sort ranges for binary search
    ranges.sort((a, b) => a.start.compareTo(b.start));
  }

  // Add optimized versions of other methods...
  int _countNavigationPatternsOptimized(String content, List<String> routePatterns) {
    // Implementation similar to original but using cached regex
    var count = 0;
    for (final route in routePatterns) {
      final patterns = [
        r'''\.push(?:Replacement)?Named\s*\(\s*[\'"]''' + RegExp.escape(route) + r'''[\'"]''',
        r'''(?:context\.)?go\s*\(\s*[\'"]''' + RegExp.escape(route) + r'''[\'"]''',
        r'''[\'"]''' + RegExp.escape(route) + r'''[\'"]\s*:\s*\([^)]*\)\s*=>''',
      ];
      
      for (final pattern in patterns) {
        count += _getCachedRegex(pattern).allMatches(content).length;
      }
    }
    return count;
  }

  int _countProviderPatternsOptimized(String content, String className) {
    final patterns = [
      r'Provider\.of\s*<\s*' + RegExp.escape(className) + r'\s*>',
      r'context\.\s*(?:read|watch)\s*<\s*' + RegExp.escape(className) + r'\s*>',
      r'Consumer\s*<\s*' + RegExp.escape(className) + r'\s*>',
      r'ChangeNotifierProvider\s*<\s*' + RegExp.escape(className) + r'\s*>',
    ];
    
    var count = 0;
    for (final pattern in patterns) {
      count += _getCachedRegex(pattern).allMatches(content).length;
    }
    return count;
  }

  int _countGenericUsageOptimized(String content, String className) {
    final pattern = r'\b\w+\s*<[^<>]*\b' + RegExp.escape(className) + r'\b[^<>]*>';
    return _getCachedRegex(pattern).allMatches(content).length;
  }

  int _countFilePathReferencesOptimized(String content, String className) {
    final fileName = _toSnakeCase(className);
    final patterns = [
      r'''import\s+[\'"][^\'\"]*''' + RegExp.escape(fileName) + r'''\.dart[\'"]''',
      r'''export\s+[\'"][^\'\"]*''' + RegExp.escape(fileName) + r'''\.dart[\'"]''',
    ];
    
    var count = 0;
    for (final pattern in patterns) {
      count += _getCachedRegex(pattern).allMatches(content).length;
    }
    return count;
  }

  // Keep original helper methods for case conversion
  List<String> _generateRoutePatterns(String className) {
    final patterns = <String>[];
    var baseName = className;
    final suffixes = ['Page', 'Screen', 'View', 'Widget'];
    
    for (final suffix in suffixes) {
      if (baseName.endsWith(suffix)) {
        baseName = baseName.substring(0, baseName.length - suffix.length);
        break;
      }
    }

    final camelCase = _toCamelCase(baseName);
    final snakeCase = _toSnakeCase(baseName);
    final kebabCase = _toKebabCase(baseName);

    patterns.addAll([
      '/$camelCase', '/$snakeCase', '/$kebabCase',
      camelCase, snakeCase, kebabCase,
    ]);

    return patterns;
  }

  List<String> _generateStringIdentifiers(String className) {
    final identifiers = <String>[];
    var baseName = className;
    final suffixes = ['Page', 'Screen', 'View', 'Widget', 'Service', 'Provider'];
    
    for (final suffix in suffixes) {
      if (baseName.endsWith(suffix)) {
        baseName = baseName.substring(0, baseName.length - suffix.length);
        break;
      }
    }

    identifiers.addAll([
      _toCamelCase(baseName),
      _toSnakeCase(baseName),
      _toKebabCase(baseName),
      baseName.toLowerCase(),
    ]);

    return identifiers;
  }

  bool _isDefinitionMatch(String line, String className, Match match) {
    // Use efficient string operations instead of regex where possible
    final trimmedLine = line.trim();
    
    // Check for class declaration
    if (trimmedLine.startsWith('class $className')) return true;
    if (trimmedLine.startsWith('class _${className}State')) return true;
    if (trimmedLine.startsWith('import ')) return true;
    if (trimmedLine.startsWith('export ')) return true;
    
    return false;
  }

  String _toCamelCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toLowerCase() + input.substring(1);
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => '_${match.group(1)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  String _toKebabCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => '-${match.group(1)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^-'), '');
  }
}

// Supporting classes
class PreprocessedContent {
  final String content;
  final List<String> lines;
  final List<int> lineStarts;
  final List<Range> commentRanges;
  final List<Range> stringRanges;

  PreprocessedContent({
    required this.content,
    required this.lines,
    required this.lineStarts,
    required this.commentRanges,
    required this.stringRanges,
  });
}

class Range {
  final int start;
  final int end;

  Range(this.start, this.end);
}

class Match {
  final String className;
  final int start;
  final int end;

  Match(this.className, this.start, this.end);
}

// Trie for efficient string matching
class TrieNode {
  final Map<String, TrieNode> children = {};
  bool isEndOfWord = false;
  
  void insert(String word) {
    TrieNode current = this;
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      current.children.putIfAbsent(char, () => TrieNode());
      current = current.children[char]!;
    }
    current.isEndOfWord = true;
  }
  
  void clear() {
    children.clear();
    isEndOfWord = false;
  }
  
  bool get isEmpty => children.isEmpty && !isEndOfWord;
}

// Usage example:
void analyzeClassUsages(String content, String filePath, Map<String, ClassInfo> classes) {
  final analyzer = OptimizedClassAnalyzer();
  analyzer.analyzeClassUsages(content, filePath, classes);
}
// import 'dart:math';
// import 'package:dead_code_analyzer/src/model/class_info.dart';

// void analyzeClassUsages(
//     String content, String filePath, Map<String, ClassInfo> classes) {
//   for (final entry in classes.entries) {
//     final className = entry.key;
//     final classInfo = entry.value;

//     // Find all occurrences of the class name
//     final usageRegex = RegExp(r'\b' + RegExp.escape(className) + r'\b');
//     final allMatches = usageRegex.allMatches(content).toList();

//     if (allMatches.isEmpty) {
//       // Even if no direct matches, check for indirect usage patterns
//       _checkIndirectUsage(content, className, classInfo, filePath);
//       continue;
//     }

//     // Filter out definition-related matches
//     final validMatches = <RegExpMatch>[];

//     for (final match in allMatches) {
//       if (_shouldExcludeClassMatch(content, match, className)) {
//         continue;
//       }

//       if (_isInComment(content, match.start) ||
//           _isInString(content, match.start)) {
//         continue;
//       }

//       validMatches.add(match);
//     }

//     var usageCount = validMatches.length;

//     // Add indirect usage count
//     usageCount += _countIndirectUsage(content, className);

//     if (filePath == classInfo.definedInFile) {
//       classInfo.internalUsageCount = usageCount;
//     } else if (usageCount > 0) {
//       classInfo.externalUsages[filePath] = usageCount;
//     }
//   }
// }

// /// Check for indirect usage patterns like navigation, route references, etc.
// void _checkIndirectUsage(
//     String content, String className, ClassInfo classInfo, String filePath) {
//   var indirectCount = _countIndirectUsage(content, className);

//   if (indirectCount > 0) {
//     if (filePath == classInfo.definedInFile) {
//       classInfo.internalUsageCount = indirectCount;
//     } else {
//       classInfo.externalUsages[filePath] = indirectCount;
//     }
//   }
// }

// /// Count indirect usage patterns
// int _countIndirectUsage(String content, String className) {
//   var count = 0;

//   // Pattern 1: Route name patterns
//   // Example: '/maxProtectProposal', 'max-protect-proposal', etc.
//   final routePatterns = _generateRoutePatterns(className);
//   for (final pattern in routePatterns) {
//     final routeRegex = RegExp(r'''[\'"]' + RegExp.escape(pattern) + r'[\'"]''');
//     count += routeRegex.allMatches(content).length;
//   }

//   // Pattern 2: String identifiers derived from class name
//   // Example: 'MaxProtectProposalPage' -> 'maxProtectProposal', 'max_protect_proposal'
//   final stringIdentifiers = _generateStringIdentifiers(className);
//   for (final identifier in stringIdentifiers) {
//     final stringRegex =
//         RegExp(r'''[\'"]' + RegExp.escape(identifier) + r'[\'"]''');
//     count += stringRegex.allMatches(content).length;
//   }

//   // Pattern 3: Navigation patterns
//   // Navigator.push*, Navigator.of(context).push*, pushNamed, etc.
//   count += _countNavigationPatterns(content, className);

//   // Pattern 4: Provider patterns
//   // Provider.of<ClassName>, context.read<ClassName>, etc.
//   count += _countProviderPatterns(content, className);

//   // Pattern 5: Type parameters and generics
//   // Future<ClassName>, List<ClassName>, etc.
//   count += _countGenericUsage(content, className);

//   // Pattern 6: File path references
//   // import 'path/to/class_name.dart' or similar
//   count += _countFilePathReferences(content, className);

//   return count;
// }

// /// Generate possible route patterns from class name
// List<String> _generateRoutePatterns(String className) {
//   final patterns = <String>[];

//   // Remove common suffixes
//   var baseName = className;
//   final suffixes = ['Page', 'Screen', 'View', 'Widget'];
//   for (final suffix in suffixes) {
//     if (baseName.endsWith(suffix)) {
//       baseName = baseName.substring(0, baseName.length - suffix.length);
//       break;
//     }
//   }

//   // Convert to different route formats
//   final camelCase = _toCamelCase(baseName);
//   final snakeCase = _toSnakeCase(baseName);
//   final kebabCase = _toKebabCase(baseName);

//   patterns.addAll([
//     '/$camelCase',
//     '/$snakeCase',
//     '/$kebabCase',
//     camelCase,
//     snakeCase,
//     kebabCase,
//   ]);

//   return patterns;
// }

// /// Generate string identifiers from class name
// List<String> _generateStringIdentifiers(String className) {
//   final identifiers = <String>[];

//   // Remove common suffixes
//   var baseName = className;
//   final suffixes = ['Page', 'Screen', 'View', 'Widget', 'Service', 'Provider'];
//   for (final suffix in suffixes) {
//     if (baseName.endsWith(suffix)) {
//       baseName = baseName.substring(0, baseName.length - suffix.length);
//       break;
//     }
//   }

//   identifiers.addAll([
//     _toCamelCase(baseName),
//     _toSnakeCase(baseName),
//     _toKebabCase(baseName),
//     baseName.toLowerCase(),
//   ]);

//   return identifiers;
// }

// /// Count navigation-related usage patterns
// int _countNavigationPatterns(String content, String className) {
//   var count = 0;

//   // Generate possible route names
//   final routePatterns = _generateRoutePatterns(className);

//   for (final route in routePatterns) {
//     // pushNamed, pushReplacementNamed, etc.
//     final namedNavigation = RegExp(
//         r'''\.push(?:Replacement)?Named\s*\(\s*[\'"]' + RegExp.escape(route) + r'[\'"]''');
//     count += namedNavigation.allMatches(content).length;

//     // GoRouter patterns
//     final goRouterPattern = RegExp(
//         r'''(?:context\.)?go\s*\(\s*[\'"]' + RegExp.escape(route) + r'[\'"]''');
//     count += goRouterPattern.allMatches(content).length;

//     // Route definitions
//     final routeDefinition = RegExp(
//         r'''[\'"]' + RegExp.escape(route) + r'[\'"]\s*:\s*\([^)]*\)\s*=>''');
//     count += routeDefinition.allMatches(content).length;
//   }

//   return count;
// }

// /// Count provider-related usage patterns
// int _countProviderPatterns(String content, String className) {
//   var count = 0;

//   // Provider.of<ClassName>
//   final providerOf =
//       RegExp(r'Provider\.of\s*<\s*' + RegExp.escape(className) + r'\s*>');
//   count += providerOf.allMatches(content).length;

//   // context.read<ClassName>, context.watch<ClassName>
//   final contextRead = RegExp(r'context\.\s*(?:read|watch)\s*<\s*' +
//       RegExp.escape(className) +
//       r'\s*>');
//   count += contextRead.allMatches(content).length;

//   // Consumer<ClassName>
//   final consumer =
//       RegExp(r'Consumer\s*<\s*' + RegExp.escape(className) + r'\s*>');
//   count += consumer.allMatches(content).length;

//   // ChangeNotifierProvider<ClassName>
//   final changeNotifier = RegExp(
//       r'ChangeNotifierProvider\s*<\s*' + RegExp.escape(className) + r'\s*>');
//   count += changeNotifier.allMatches(content).length;

//   return count;
// }

// /// Count generic type usage
// int _countGenericUsage(String content, String className) {
//   var count = 0;

//   // Future<ClassName>, List<ClassName>, etc.
//   final genericPattern =
//       RegExp(r'\b\w+\s*<[^<>]*\b' + RegExp.escape(className) + r'\b[^<>]*>');
//   count += genericPattern.allMatches(content).length;

//   return count;
// }

// /// Count file path references
// int _countFilePathReferences(String content, String className) {
//   var count = 0;

//   // Convert class name to likely file names
//   final fileName = _toSnakeCase(className);

//   // import 'path/file_name.dart'
//   final importPattern = RegExp(
//       r'''import\s+[\'"][^\'\"]*' + RegExp.escape(fileName) + r'\.dart[\'"]''');
//   count += importPattern.allMatches(content).length;

//   // export 'path/file_name.dart'
//   final exportPattern = RegExp(
//       r'''export\s+[\'"][^\'\"]*' + RegExp.escape(fileName) + r'\.dart[\'"]''');
//   count += exportPattern.allMatches(content).length;

//   return count;
// }

// /// Convert PascalCase to camelCase
// String _toCamelCase(String input) {
//   if (input.isEmpty) return input;
//   return input[0].toLowerCase() + input.substring(1);
// }

// /// Convert PascalCase to snake_case
// String _toSnakeCase(String input) {
//   return input
//       .replaceAllMapped(
//           RegExp(r'([A-Z])'), (match) => '_${match.group(1)!.toLowerCase()}')
//       .replaceFirst(RegExp(r'^_'), '');
// }

// /// Convert PascalCase to kebab-case
// String _toKebabCase(String input) {
//   return input
//       .replaceAllMapped(
//           RegExp(r'([A-Z])'), (match) => '-${match.group(1)!.toLowerCase()}')
//       .replaceFirst(RegExp(r'^-'), '');
// }

// bool _shouldExcludeClassMatch(
//     String content, RegExpMatch match, String className) {
//   final matchStart = match.start;

//   final lineInfo = _getLineInfo(content, matchStart);
//   final line = lineInfo.line;

//   // 1. Class declaration: class ClassName
//   if (RegExp(r'^\s*class\s+' + RegExp.escape(className) + r'\b')
//       .hasMatch(line)) {
//     return true;
//   }

//   // 2. Constructor definition within the class
//   if (_isConstructorDefinition(content, match, className)) {
//     return true;
//   }

//   // 3. State class declaration: class _ClassNameState
//   if (RegExp(r'^\s*class\s+_' + RegExp.escape(className) + r'State\b')
//       .hasMatch(line)) {
//     return true;
//   }

//   // 4. State generic type usage in class extends only
//   if (RegExp(r'^\s*class\s+.*extends\s+State\s*<\s*' +
//           RegExp.escape(className) +
//           r'\s*>')
//       .hasMatch(line)) {
//     return true;
//   }

//   // 5. createState method returning state class
//   if (RegExp(r'\bcreateState\s*\(\s*\)\s*(?:=>\s*_' +
//           RegExp.escape(className) +
//           r'State\s*\(\s*\)|{\s*return\s+_' +
//           RegExp.escape(className) +
//           r'State\s*\(\s*\))')
//       .hasMatch(line)) {
//     return true;
//   }

//   // 6. Factory constructor definition (refined)
//   // Only exclude if this is a factory constructor definition, not a static method call
//   if (RegExp(r'^\s*factory\s+' + RegExp.escape(className) + r'\.')
//       .hasMatch(line)) {
//     return true;
//   }

//   // 7. Import statements (but not the ones we want to count)
//   if (RegExp(r'^\s*import\s+').hasMatch(line)) {
//     return true;
//   }

//   // 8. Export statements (but not the ones we want to count)
//   if (RegExp(r'^\s*export\s+').hasMatch(line)) {
//     return true;
//   }

//   // --- Do NOT exclude if line contains "ClassName." and is not a factory/constructor ---

//   return false;
// }

// bool _isConstructorDefinition(
//     String content, RegExpMatch match, String className) {
//   final matchStart = match.start;
//   final lineInfo = _getLineInfo(content, matchStart);
//   final line = lineInfo.line.trim();

//   // Check if we're inside a class definition
//   final beforeMatch = content.substring(0, matchStart);
//   final isInsideClass = _isInsideClassDefinition(beforeMatch, className);

//   if (!isInsideClass) {
//     return false; // If not inside class, it's likely a constructor call
//   }

//   // Get more context around the match
//   final contextBefore = _getContextBefore(content, matchStart, 100);
//   final contextAfter =
//       _getContextAfter(content, matchStart + className.length, 50);

//   // Check if this is clearly a constructor call (instantiation)
//   if (_isConstructorCall(contextBefore, contextAfter, className)) {
//     return false;
//   }

//   // Constructor definition patterns inside a class:

//   // 1. Constructor definition at start of line with various parameter patterns
//   // Handles: ClassName(), const ClassName(), ClassName({...}), ClassName(params)
//   final constructorDefPattern = RegExp(r'^\s*(?:const\s+|factory\s+)?' +
//       RegExp.escape(className) +
//       r'(?:\.[a-zA-Z_]\w*)?\s*\([^)]*\)\s*(?::\s*[^{;]*)?[{;]');
//   if (constructorDefPattern.hasMatch(line)) {
//     return true;
//   }

//   // 2. Check position and context for edge cases
//   final positionInLine = matchStart - lineInfo.lineStart;
//   final beforeClassName = line.substring(0, min(positionInLine, line.length));

//   // If there's only whitespace and optionally modifiers before the class name
//   if (RegExp(r'^\s*(?:const\s+|factory\s+)?$').hasMatch(beforeClassName)) {
//     final afterMatchStart = positionInLine + className.length;
//     if (afterMatchStart < line.length) {
//       final afterMatch = line.substring(afterMatchStart).trim();

//       // Constructor definition patterns after class name
//       if (RegExp(r'^(?:\.[a-zA-Z_]\w*)?\s*\([^)]*\)\s*(?::\s*[^{;]*)?[{;]')
//           .hasMatch(afterMatch)) {
//         return true;
//       }
//     }
//   }

//   // 3. Multi-line constructor with initializer lists
//   final multiLineContext = _getMultiLineContext(content, matchStart, 3);
//   final multiLinePattern = RegExp(
//       r'^\s*(?:const\s+|factory\s+)?' +
//           RegExp.escape(className) +
//           r'(?:\.[a-zA-Z_]\w*)?\s*\([^)]*\)\s*:\s*(?:super\s*\(|this\s*\(|assert\s*\(|[a-zA-Z_]\w*\s*=)',
//       multiLine: true,
//       dotAll: true);
//   if (multiLinePattern.hasMatch(multiLineContext)) {
//     return true;
//   }

//   return false;
// }

// bool _isInComment(String content, int position) {
//   // Find the line containing this position
//   final lineInfo = _getLineInfo(content, position);
//   final line = lineInfo.line;
//   final positionInLine = position - lineInfo.lineStart;

//   // Check for single-line comments
//   final singleLineComment = line.indexOf('//');
//   if (singleLineComment != -1 && singleLineComment <= positionInLine) {
//     return true;
//   }

//   // Check for multi-line comments
//   final beforePositionContent = content.substring(0, position);
//   int commentStart = -1;
//   int searchIndex = 0;

//   while (true) {
//     final start = beforePositionContent.indexOf('/*', searchIndex);
//     if (start == -1) break;

//     final end = content.indexOf('*/', start);
//     if (end == -1 || end > position) {
//       commentStart = start;
//       break;
//     }

//     searchIndex = end + 2;
//   }

//   return commentStart != -1;
// }

// _LineInfo _getLineInfo(String content, int position) {
//   final beforePosition = content.substring(0, position);
//   final lastNewlineIndex = beforePosition.lastIndexOf('\n');
//   final lineStart = lastNewlineIndex + 1;

//   final nextNewlineIndex = content.indexOf('\n', position);
//   final lineEnd = nextNewlineIndex == -1 ? content.length : nextNewlineIndex;

//   final line = content.substring(lineStart, lineEnd);

//   return _LineInfo(line, lineStart);
// }

// class _LineInfo {
//   final String line;
//   final int lineStart;

//   _LineInfo(this.line, this.lineStart);
// }

// bool _isInString(String content, int position) {
//   // Get the line containing this position
//   final lineInfo = _getLineInfo(content, position);
//   final line = lineInfo.line;
//   final positionInLine = position - lineInfo.lineStart;

//   // Simple string detection within the line
//   int singleQuotes = 0;
//   int doubleQuotes = 0;
//   bool escaped = false;

//   for (int i = 0; i < positionInLine && i < line.length; i++) {
//     final char = line[i];

//     if (escaped) {
//       escaped = false;
//       continue;
//     }

//     if (char == '\\') {
//       escaped = true;
//       continue;
//     }

//     if (char == "'") singleQuotes++;
//     if (char == '"') doubleQuotes++;
//   }

//   // If we have an odd number of quotes, we're inside a string
//   return (singleQuotes % 2 == 1) || (doubleQuotes % 2 == 1);
// }

// bool _isInsideClassDefinition(String beforeContent, String className) {
//   // Look for the class definition backwards from current position
//   final classPattern =
//       RegExp(r'\bclass\s+' + RegExp.escape(className) + r'\b[^{]*\{');
//   final matches = classPattern.allMatches(beforeContent).toList();

//   if (matches.isEmpty) return false;

//   // Get the last class definition match
//   final lastMatch = matches.last;

//   // Count braces after the class definition to see if we're still inside
//   final afterClassDef =
//       beforeContent.substring(lastMatch.end - 1); // Include opening brace
//   int braceCount = 0;

//   for (int i = 0; i < afterClassDef.length; i++) {
//     final char = afterClassDef[i];
//     if (char == '{') {
//       braceCount++;
//     } else if (char == '}') {
//       braceCount--;
//       if (braceCount == 0) {
//         return false; // We've exited the class
//       }
//     }
//   }

//   return braceCount > 0; // Still inside the class if braces are unmatched
// }

// // Helper function to get context before the match
// String _getContextBefore(String content, int position, int maxLength) {
//   final start = max(0, position - maxLength);
//   return content.substring(start, position);
// }

// // Helper function to get context after the match
// String _getContextAfter(String content, int position, int maxLength) {
//   final end = min(content.length, position + maxLength);
//   return content.substring(position, end);
// }

// // New helper function to detect constructor calls
// bool _isConstructorCall(
//     String contextBefore, String contextAfter, String className) {
//   // Clean up context by removing extra whitespace
//   final cleanBefore = contextBefore.replaceAll(RegExp(r'\s+'), ' ').trim();
//   final cleanAfter = contextAfter.replaceAll(RegExp(r'\s+'), ' ').trim();

//   // Common patterns that indicate constructor calls rather than definitions

//   // 1. Assignment patterns: var x = ClassName(), final y = const ClassName()
//   if (RegExp(
//           r'(?:^|[;\{\}])\s*(?:var|final|const|late|\w+)\s+\w*\s*=\s*(?:const\s+)?$')
//       .hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 2. Return statement: return ClassName(), return const ClassName()
//   if (RegExp(r'\breturn\s+(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 3. Function argument: someFunction(ClassName()), child: const ClassName()
//   if (RegExp(r'[,\(]\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 4. Property assignment: child: ClassName(), body: const ClassName()
//   if (RegExp(r':\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 5. List/collection items: [ClassName(), const ClassName()]
//   if (RegExp(r'[\[\{,]\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 6. Ternary operator: condition ? ClassName() : other
//   if (RegExp(r'\?\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 7. Null coalescing: something ?? ClassName()
//   if (RegExp(r'\?\?\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 8. Lambda/arrow function body: () => ClassName()
//   if (RegExp(r'=>\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 9. Builder pattern: builder: (context) => ClassName()
//   if (RegExp(
//           r'builder:\s*\([^)]*\)\s*(?:=>|\{.*return)\s*(?:[\w.]*\s*\(\s*[\w\s,:.]*\s*\)\s*\.\s*)*(?:const\s+)?$')
//       .hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 10. MaterialPageRoute and similar patterns
//   if (RegExp(
//           r'MaterialPageRoute\s*\([^)]*builder:\s*\([^)]*\)\s*\{[^}]*return\s+[^;]*child:\s*(?:const\s+)?$')
//       .hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 11. ChangeNotifierProvider and similar provider patterns
//   if (RegExp(
//           r'(?:Provider|ChangeNotifierProvider|Consumer)(?:\.\w+)?\s*\([^)]*child:\s*(?:const\s+)?$')
//       .hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 12. Generic instantiation: List<ClassName>(), Map<String, ClassName>()
//   if (RegExp(
//           r'(?:List|Set|Map|Iterable|Future|Stream)<[^>]*>\s*\(\s*(?:const\s+)?$')
//       .hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 13. Method chaining: something.method().ClassName()
//   if (RegExp(r'\.\w+\([^)]*\)\s*\.\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 14. Cascade operator: object..property = ClassName()
//   if (RegExp(r'\.\.[^=]*=\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
//     return true;
//   }

//   // 15. Check if followed by parentheses (constructor call)
//   if (RegExp(r'^\s*\(').hasMatch(cleanAfter)) {
//     // Additional checks to ensure it's a call, not a definition
//     // If we're in a context that suggests instantiation
//     if (RegExp(r'(?:=|return|:|,|\(|\[|\{|\?|\?\?|=>)\s*(?:const\s+)?$')
//         .hasMatch(cleanBefore)) {
//       return true;
//     }
//   }

//   return false;
// }

// String _getMultiLineContext(String content, int position, int linesBefore) {
//   final lines = content.substring(0, position).split('\n');
//   final currentLineIndex = lines.length - 1;
//   final startIndex = max(0, currentLineIndex - linesBefore);

//   final contextLines = lines.sublist(startIndex);

//   // Add some content after the position for context
//   final afterPosition = content.substring(position);
//   final nextLines = afterPosition.split('\n').take(2).toList();

//   return (contextLines + nextLines).join('\n');
// }

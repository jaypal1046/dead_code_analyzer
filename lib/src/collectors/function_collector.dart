// Enhanced function detection with better generic support and class filtering
import 'package:dead_code_analyzer/src/models/code_info.dart';
import 'package:dead_code_analyzer/src/utils/helper.dart';

/// This class provides static methods to detect function definitions while
/// filtering out class declarations, constructor calls, and other non-function
/// constructs to avoid false positives in dead code analysis.
///
/// Analyzes a line of code to detect function definitions and collect them.
///
/// Parameters:
/// - [analyzeFunctions]: Whether to perform function analysis
/// - [line]: The current line of code being analyzed
/// - [insideStateClass]: Whether the analysis is inside a State class
/// - [prebuiltFlutterMethods]: Set of known Flutter method names
/// - [lineIndex]: The index of the current line in the file
/// - [pragmaRegex]: Regular expression for detecting pragma annotations
/// - [lines]: All lines in the current file
/// - [functions]: Map to store detected function information
/// - [filePath]: Path to the file being analyzed
/// - [currentClassName]: Name of the current class being analyzed
class FunctionCollector {
  static void collectFunctions({
    required bool analyzeFunctions,
    required String line,
    required bool insideStateClass,
    required Set<String> prebuiltFlutterMethods,
    required int lineIndex,
    required RegExp pragmaRegex,
    required List<String> lines,
    required Map<String, CodeInfo> functions,
    required String filePath,
    required String currentClassName,
  }) {
    if (!analyzeFunctions) return;

    // Enhanced function detection with better generic support
    final functionRegex = RegExp(
      r'(?://\s*)?' // Optional comment prefix
      r'(?:(?:static\s+|abstract\s+|external\s+|final\s+|const\s+|override\s+|async\s+)*)' // Optional modifiers
      r'(?:' // Start return type group
      r'(?:void|int|double|String|bool|dynamic|Object|num|' // Basic types
      r'Widget|State|StatefulWidget|StatelessWidget|' // Flutter types
      r'List(?:<[^>]*>)?|Map(?:<[^>]*,[^>]*>)?|Set(?:<[^>]*>)?|' // Collections
      r'Future(?:<[^>]+>)?|Stream(?:<[^>]+>)?|' // Async types
      r'[A-Z]\w*(?:<[^>]*>)?|' // Custom types with generics
      r'[a-zA-Z_]\w*(?:<[^>]*>)?)' // Any type with generics
      r'\s+' // Required space after return type
      r'|' // OR no return type (for constructors, etc.)
      r')' // End return type group
      r'(\w+)' // Function name (capture group 1)
      r'(?:<[^>]*>)?' // Optional generic parameters on function
      r'\s*\([^)]*\)' // Parameters
      r'\s*(?:async\s*\*?|sync\s*\*?)?' // Optional async
      r'\s*(?:\{|=>|;)', // Body start or declaration end
      multiLine: true,
    );

    String currentLine = line;

    // Skip non-function lines early
    if (_shouldSkipLine(line)) {
      return;
    }

    // Better class detection - skip class declarations entirely
    if (_isClassDeclaration(line)) {
      return;
    }

    // Skip constructor calls and widget instantiations
    if (_isConstructorOrWidgetCall(line)) {
      return;
    }

    // Handle multi-line functions
    if (_isMultiLineFunction(line, lineIndex, lines)) {
      currentLine = _buildMultiLineFunction(line, lineIndex, lines);
    }

    final functionMatches = functionRegex.allMatches(currentLine);

    for (final match in functionMatches) {
      final String? functionName = match.group(1);
      if (functionName == null || functionName.isEmpty) {
        continue;
      }

      // Enhanced validation - check if this is inside a constructor call or parameter
      if (_isInsideConstructorCall(currentLine, match) ||
          _isLambdaParameter(currentLine, match)) {
        continue;
      }

      // Enhanced class detection - skip if this is actually a class name
      if (_isActuallyClass(functionName, currentLine, lines, lineIndex) ||
          currentClassName == functionName) {
        continue;
      }

      // Better function definition validation
      if (!_isValidFunctionDefinition(currentLine, match, functionName)) {
        continue;
      }

      // Check if line is commented
      final bool isCommentedOut = _isLineCommented(lines, lineIndex, line);
      bool isEntryPoint = false;
      final bool isPrebuiltFlutter =
          insideStateClass && prebuiltFlutterMethods.contains(functionName);

      // Check for @override annotation
      final bool isOverrideFunction = _hasOverrideAnnotation(lines, lineIndex);

      // Skip @override functions as they are inherently used
      if (isOverrideFunction && !isCommentedOut) {
        continue;
      }

      final bool isOverriddenFlutterMethod =
          isOverrideFunction && prebuiltFlutterMethods.contains(functionName);

      // Extract function body for emptiness check
      final String functionBody =
          _extractFunctionBody(currentLine, match.start);
      final bool isEmpty = _isFunctionEmpty(functionBody);
      final bool isThisConstructor =
          Helper.isConstructor(functionName, currentLine);

      // Check for @pragma('vm:entry-point') annotation
      if (lineIndex > 0 && !isCommentedOut) {
        isEntryPoint = _checkForPragmaAnnotation(lines, lineIndex, pragmaRegex);
      }

      final String functionKey = _buildFunctionKey(
        functionName,
        isCommentedOut,
        lineIndex,
        match.start,
        filePath,
        functions,
      );

      final bool isStaticFunction = _isStaticFunction(currentLine);

      // Skip prebuilt Flutter methods unless they're commented out or overridden
      if (!isCommentedOut &&
          !isOverriddenFlutterMethod &&
          (prebuiltFlutterMethods.contains(functionName) ||
              functionName == 'toString')) {
        continue;
      }

      functions[functionKey] = CodeInfo(
        className: currentClassName,
        filePath,
        isEntryPoint: isEntryPoint,
        type: 'function',
        isPrebuiltFlutter: isPrebuiltFlutter,
        isEmpty: isEmpty,
        isConstructor: isThisConstructor,
        commentedOut: isCommentedOut,
        lineIndex: lineIndex,
        startPosition: match.start,
        isStaticFunction: isStaticFunction,
        isPrebuiltFlutterCommentedOut: isCommentedOut &&
            (prebuiltFlutterMethods.contains(functionName) ||
                functionName == 'toString'),
      );
    }
  }

  /// Checks if this is a constructor call or widget instantiation.
  static bool _isConstructorOrWidgetCall(String line) {
    final String trimmed = line.trim();

    // Check for widget constructor calls like CounterWidget(...)
    if (RegExp(r'[A-Z]\w*\s*\([^)]*(?:\([^)]*\)[^)]*)*\)\s*[,;]?$')
        .hasMatch(trimmed)) {
      return true;
    }

    // Check for constructor calls in assignments
    if (RegExp(r'=\s*[A-Z]\w*\s*\(').hasMatch(trimmed)) {
      return true;
    }

    // Check for constructor calls in return statements
    if (RegExp(r'return\s+[A-Z]\w*\s*\(').hasMatch(trimmed)) {
      return true;
    }

    // Check for constructor calls in lists/collections
    if (RegExp(r'[\[\{,]\s*[A-Z]\w*\s*\(').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Checks if the match is inside a constructor call.
  static bool _isInsideConstructorCall(String line, RegExpMatch match) {
    final String beforeMatch = line.substring(0, match.start);
    // Count parentheses to see if we're inside a constructor call
    int openParens = 0;
    bool foundConstructor = false;

    // Look backwards for constructor pattern
    for (int i = beforeMatch.length - 1; i >= 0; i--) {
      if (beforeMatch[i] == ')') {
        openParens++;
      } else if (beforeMatch[i] == '(') {
        openParens--;
        if (openParens < 0) {
          // We found an opening paren, check if it's preceded by a constructor
          final String beforeParen = beforeMatch.substring(0, i).trim();
          if (RegExp(r'[A-Z]\w*\s*$').hasMatch(beforeParen)) {
            foundConstructor = true;
            break;
          }
          break;
        }
      }
    }

    return foundConstructor;
  }

  /// Checks if this is a lambda parameter.
  static bool _isLambdaParameter(String line, RegExpMatch match) {
    final String beforeMatch = line.substring(0, match.start);

    // Check for lambda parameter patterns like "onCountChanged: (count) =>"
    if (RegExp(r'\w+\s*:\s*$').hasMatch(beforeMatch)) {
      return true;
    }

    // Check if we're inside parentheses followed by =>
    final String afterMatch = line.substring(match.end);
    if (RegExp(r'^\s*\)\s*=>').hasMatch(afterMatch)) {
      // Count parentheses backwards to see if we're in a parameter list
      int parenCount = 0;
      for (int i = beforeMatch.length - 1; i >= 0; i--) {
        if (beforeMatch[i] == ')') {
          parenCount++;
        } else if (beforeMatch[i] == '(') {
          parenCount--;
          if (parenCount < 0) {
            // Check if this opening paren is preceded by a colon (parameter)
            final String beforeParen = beforeMatch.substring(0, i).trim();
            if (beforeParen.endsWith(':')) {
              return true;
            }
            break;
          }
        }
      }
    }

    return false;
  }

  /// Enhanced skip line logic.
  static bool _shouldSkipLine(String line) {
    final String trimmed = line.trim();

    // Skip empty lines, braces, or obvious non-function lines
    if (trimmed.isEmpty || trimmed == '{' || trimmed == '}') {
      return true;
    }

    // Skip obvious function calls
    if (_isFunctionCall(line)) {
      return true;
    }

    // Skip return statements
    if (_isReturnStatement(line)) {
      return true;
    }

    // Skip constructor calls
    if (_isConstructorCall(line)) {
      return true;
    }

    // Skip variable declarations that aren't function definitions
    if (_isVariableDeclaration(line)) {
      return true;
    }

    return false;
  }

  /// Comprehensive class declaration detection.
  static bool _isClassDeclaration(String line) {
    final String trimmed = line.trim();

    // Check for class, enum, mixin, extension declarations
    if (RegExp(r'^(?:abstract\s+)?(?:class|enum|mixin|extension)\s+\w+')
        .hasMatch(trimmed)) {
      return true;
    }

    // Check for class with generics: class MyClass<T>
    if (RegExp(r'^(?:abstract\s+)?class\s+\w+(?:<[^>]*>)?').hasMatch(trimmed)) {
      return true;
    }

    // Check for class with extends/implements/with
    if (RegExp(
            r'^(?:abstract\s+)?class\s+\w+(?:<[^>]*>)?\s+(?:extends|implements|with)')
        .hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Better class detection logic.
  static bool _isActuallyClass(
    String functionName,
    String currentLine,
    List<String> lines,
    int lineIndex,
  ) {
    final String trimmedLine = currentLine.trim();

    // Direct class declaration check
    if (RegExp(r'^(?:abstract\s+)?(?:class|enum|mixin|extension)\s+' +
            RegExp.escape(functionName) +
            r'\b')
        .hasMatch(trimmedLine)) {
      return true;
    }

    // If function name starts with uppercase (potential class name)
    if (functionName[0].toUpperCase() == functionName[0]) {
      // Check current line for class-like patterns
      if (trimmedLine.contains('extends') ||
          trimmedLine.contains('implements') ||
          trimmedLine.contains('with') ||
          trimmedLine.contains('mixin')) {
        return true;
      }

      // Look at surrounding context for class declarations
      final String context = _getContextAroundLine(lines, lineIndex, 3);

      // Check for class declaration patterns in context
      final List<String> classPatterns = [
        r'\bclass\s+' + RegExp.escape(functionName) + r'\b',
        r'\benum\s+' + RegExp.escape(functionName) + r'\b',
        r'\bmixin\s+' + RegExp.escape(functionName) + r'\b',
        r'\bextension\s+' + RegExp.escape(functionName) + r'\b',
      ];

      for (final String pattern in classPatterns) {
        if (RegExp(pattern).hasMatch(context)) {
          return true;
        }
      }

      // Additional check: look for inheritance patterns
      if (RegExp(r'\bextends\s+' + RegExp.escape(functionName) + r'\b')
              .hasMatch(context) ||
          RegExp(r'\bimplements\s+' + RegExp.escape(functionName) + r'\b')
              .hasMatch(context) ||
          RegExp(r'\bwith\s+' + RegExp.escape(functionName) + r'\b')
              .hasMatch(context)) {
        return true;
      }

      // Check if it's being used as a type declaration
      if (RegExp(r'\b' + RegExp.escape(functionName) + r'\s+\w+\s*[=;]')
          .hasMatch(context)) {
        return true;
      }
    }

    return false;
  }

  /// Gets context around a line for better analysis.
  static String _getContextAroundLine(
    List<String> lines,
    int lineIndex,
    int radius,
  ) {
    final int start = (lineIndex - radius).clamp(0, lines.length - 1);
    final int end = (lineIndex + radius + 1).clamp(0, lines.length);

    return lines.sublist(start, end).join('\n');
  }

  /// Checks if this is a multi-line function.
  static bool _isMultiLineFunction(
    String line,
    int lineIndex,
    List<String> lines,
  ) {
    return (line.contains('(') && line.contains(')')) &&
        (line.contains('{') || line.contains('=>')) &&
        !line.contains('}') &&
        lineIndex < lines.length - 1;
  }

  /// Builds complete multi-line function string.
  static String _buildMultiLineFunction(
    String line,
    int lineIndex,
    List<String> lines,
  ) {
    final StringBuffer fullFunction = StringBuffer(line);
    int braceCount = line.split('{').length - line.split('}').length;
    int nextLineIndex = lineIndex + 1;

    while (braceCount > 0 && nextLineIndex < lines.length) {
      final String nextLine = lines[nextLineIndex];
      fullFunction.writeln(nextLine);
      braceCount += nextLine.split('{').length - 1;
      braceCount -= nextLine.split('}').length - 1;
      nextLineIndex++;
    }

    return fullFunction.toString();
  }

  /// Improved function emptiness check.
  static bool _isFunctionEmpty(String functionBody) {
    if (functionBody.isEmpty || functionBody.trim() == ';') {
      return true;
    }

    final String cleaned = functionBody.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Check for empty braces
    if (cleaned == '{}' || cleaned == '{ }') {
      return true;
    }

    // Check for arrow function with no body
    if (cleaned == '=>' || cleaned == '=> ;') {
      return true;
    }

    return false;
  }

  /// Checks for pragma annotation.
  static bool _checkForPragmaAnnotation(
    List<String> lines,
    int lineIndex,
    RegExp pragmaRegex,
  ) {
    if (pragmaRegex.hasMatch(lines[lineIndex - 1])) {
      return true;
    }

    // Check up to 2 lines before
    for (int i = 2; i <= 3 && lineIndex - i >= 0; i++) {
      if (pragmaRegex.hasMatch(lines[lineIndex - i])) {
        return true;
      }
    }

    return false;
  }

  /// Builds function key for storage.
  static String _buildFunctionKey(
    String functionName,
    bool isCommentedOut,
    int lineIndex,
    int matchStart,
    String filePath,
    Map<String, CodeInfo> functions,
  ) {
    if (isCommentedOut) {
      return '$functionName _LineNo:${lineIndex}_PositionNo:$matchStart ${Helper.sanitizeFilePath(filePath)}';
    } else if (functions.containsKey(functionName)) {
      return functionName; // Will be overwritten, but that's the existing behavior
    }

    return functionName;
  }

  /// Detects @override annotation.
  static bool _hasOverrideAnnotation(
      List<String> lines, int functionLineIndex) {
    // Check up to 3 lines before the function for @override annotation
    for (int i = 1; i <= 3 && (functionLineIndex - i) >= 0; i++) {
      final String line = lines[functionLineIndex - i].trim();

      if (line == '@override') {
        return true;
      }

      // Stop if we hit something that's not an annotation, comment, or empty line
      if (line.isNotEmpty &&
          !line.startsWith('@') &&
          !line.startsWith('//') &&
          !line.startsWith('/*')) {
        break;
      }
    }

    return false;
  }

  /// Extracts function body from a line.
  static String _extractFunctionBody(String line, int matchStart) {
    final int braceIndex = line.indexOf('{', matchStart);
    final int arrowIndex = line.indexOf('=>', matchStart);
    final int semicolonIndex = line.indexOf(';', matchStart);

    final List<int> indices = [braceIndex, arrowIndex, semicolonIndex]
        .where((index) => index != -1)
        .toList();

    if (indices.isEmpty) return '';

    final int startIndex = indices.reduce((a, b) => a < b ? a : b);
    return line.substring(startIndex);
  }

  /// Checks if a function is static.
  static bool _isStaticFunction(String line) {
    return line.trim().startsWith('static ') &&
        RegExp(r'\w+\s*\([^)]*\)\s*[\{=>]').hasMatch(line);
  }

  /// More accurate comment detection.
  static bool _isLineCommented(
    List<String> lines,
    int targetLineIndex,
    String originalLine,
  ) {
    if (targetLineIndex < 0 || targetLineIndex >= lines.length) {
      return false;
    }

    final String targetLine = lines[targetLineIndex];
    final String trimmedLine = targetLine.trim();

    // Check for single-line comments
    if (trimmedLine.startsWith('//') || trimmedLine.startsWith('///')) {
      return true;
    }

    // Check if inside multi-line comment
    return _isInsideMultiLineComment(lines, targetLineIndex);
  }

  /// Multi-line comment detection.
  static bool _isInsideMultiLineComment(
      List<String> lines, int targetLineIndex) {
    bool inComment = false;

    for (int lineIdx = 0; lineIdx <= targetLineIndex; lineIdx++) {
      final String line = lines[lineIdx];

      for (int charIdx = 0; charIdx < line.length; charIdx++) {
        if (_isInsideString(line, charIdx)) {
          continue;
        }

        if (charIdx < line.length - 1 &&
            line[charIdx] == '/' &&
            line[charIdx + 1] == '*') {
          inComment = true;
          charIdx++;
        } else if (charIdx < line.length - 1 &&
            line[charIdx] == '*' &&
            line[charIdx + 1] == '/') {
          inComment = false;
          charIdx++;
        }
      }

      if (lineIdx == targetLineIndex && inComment) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a position is inside a string literal.
  static bool _isInsideString(String line, int position) {
    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    bool escaped = false;

    for (int i = 0; i < position && i < line.length; i++) {
      if (escaped) {
        escaped = false;
        continue;
      }

      if (line[i] == '\\') {
        escaped = true;
        continue;
      }

      if (line[i] == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (line[i] == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      }
    }

    return inSingleQuote || inDoubleQuote;
  }

  /// Enhanced function call detection.
  static bool _isFunctionCall(String line) {
    final String trimmed = line.trim();

    if (trimmed.isEmpty || trimmed == '{' || trimmed == '}') {
      return false;
    }

    // Method calls with dot notation
    if (RegExp(r'\w+\.\w+\s*\(').hasMatch(trimmed)) {
      return true;
    }

    // Variable assignments with function calls
    if (RegExp(r'^\s*\w+\s*=\s*\w+(?:\.\w+)?\s*\(').hasMatch(trimmed)) {
      return true;
    }

    // Other call patterns
    final List<String> callPatterns = [
      r'^\s*await\s+\w+(?:\.\w+)?\s*\(',
      r'^\s*return\s+\w+(?:\.\w+)?\s*\(',
      r'^\s*if\s*\(\s*\w+(?:\.\w+)?\s*\(',
      r'^\s*while\s*\(\s*\w+(?:\.\w+)?\s*\(',
      r'^\s*for\s*\(',
      r'^\s*switch\s*\(',
      r'^\s*print\s*\(',
      r'^\s*throw\s+',
    ];

    for (final String pattern in callPatterns) {
      if (RegExp(pattern).hasMatch(trimmed)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if this is a return statement.
  static bool _isReturnStatement(String line) {
    final String trimmed = line.trim();
    return trimmed.startsWith('return ') || trimmed == 'return;';
  }

  /// Checks if this is a constructor call or instantiation.
  static bool _isConstructorCall(String line) {
    final String trimmed = line.trim();

    if (trimmed.startsWith('new ')) {
      return true;
    }

    // Variable assignments with constructor calls
    if (RegExp(r'^\s*(?:final|var|const|\w+)\s+\w+\s*=\s*[A-Z]\w*\s*\(')
        .hasMatch(trimmed)) {
      return true;
    }

    // Direct constructor calls in return statements
    if (RegExp(r'^\s*return\s+[A-Z]\w*\s*\(').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Checks if this is a variable declaration.
  static bool _isVariableDeclaration(String line) {
    final String trimmed = line.trim();

    // Simple variable declarations
    if (RegExp(r'^\s*(?:final|var|const|late)\s+\w+').hasMatch(trimmed)) {
      return true;
    }

    // Typed variable declarations
    if (RegExp(r'^\s*(?:int|double|String|bool|List|Map|Set)\s+\w+\s*[=;]')
        .hasMatch(trimmed)) {
      return true;
    }

    // Class member variables (private or public)
    if (RegExp(
            r'^\s*(?:static\s+)?(?:final\s+|const\s+)?[A-Z]\w*\s+_?\w+\s*[=;]')
        .hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Better validation for function definitions.
  static bool _isValidFunctionDefinition(
    String line,
    RegExpMatch match,
    String functionName,
  ) {
    final String beforeMatch = line.substring(0, match.start).trim();

    // If there's a dot right before the function name, it's a method call
    if (beforeMatch.endsWith('.')) {
      return false;
    }

    // Check if this looks like a parameter in a function call
    if (RegExp(r'\w+\s*:\s*$').hasMatch(beforeMatch)) {
      return false;
    }

    // Check for assignment patterns (but allow arrow functions)
    if (RegExp(r'=\s*$').hasMatch(beforeMatch) && !line.contains('=>')) {
      return false;
    }

    // Skip if it's clearly a function call inside parentheses
    if (beforeMatch.endsWith('(') || beforeMatch.endsWith(',')) {
      return false;
    }

    // Enhanced check for class declarations
    if (_isClassDeclaration(line)) {
      return false;
    }

    // Skip if the line starts with common non-function keywords
    final String lineStart = line.trim();
    final List<String> skipPatterns = [
      'return ',
      'throw ',
      'print(',
      'debugPrint(',
      'log(',
      'if(',
      'while(',
      'for(',
      'switch(',
      'assert(',
      'class ',
      'abstract class ',
      'enum ',
      'mixin ',
      'extension ',
    ];

    for (final String pattern in skipPatterns) {
      if (lineStart.startsWith(pattern)) {
        return false;
      }
    }

    // Check if we're inside a parameter list or argument list
    final int openParenCount =
        beforeMatch.split('(').length - beforeMatch.split(')').length;
    if (openParenCount > 0) {
      return false;
    }

    // Additional validation - check if this is actually a function definition
    // Must have proper function signature: name(params) followed by { or => or ;
    if (!RegExp(r'\([^)]*\)\s*(?:\{|=>|;)')
        .hasMatch(line.substring(match.start))) {
      return false;
    }

    return true;
  }
}

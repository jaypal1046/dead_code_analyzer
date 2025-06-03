import 'dart:math';

bool shouldExcludeClassMatch(
    String content, RegExpMatch match, String className) {
  final matchStart = match.start;
  final matchEnd = match.end;

  // Check for inclusion overrides first
  // Example: Include if it's a static method call (e.g., ClassName.staticMethod())
  final afterMatch = content.substring(matchEnd);
  if (RegExp(r'^\s*\.\s*\w+\s*\(').hasMatch(afterMatch)) {
    return false; // Static method call detected, include it (not excluded)
  }

  // Get the line containing this match
  final lineInfo = getLineInfo(content, matchStart);
  final line = lineInfo.line;

  // 1. Class declaration: class ClassName
  if (RegExp(r'^\s*class\s+' + RegExp.escape(className) + r'\b')
      .hasMatch(line)) {
    return true;
  }
  // 2. Constructor definition within the class
  bool isitConstructorDefinition =
      isConstructorDefinition(content, match, className);
  if (isitConstructorDefinition == true) {
    return true;
  }

  // 3. State class declaration: class ClassNameState
  if (RegExp(r'^\s*class\s+_' + RegExp.escape(className) + r'State\b')
      .hasMatch(line)) {
    return true;
  }

  // 4. State generic type usage in class extends only
  if (RegExp(r'^\s*class\s+.*extends\s+State\s*<\s*' +
          RegExp.escape(className) +
          r'\s*>')
      .hasMatch(line)) {
    return true;
  }

  // // 5. createState method returning state class
  // if (RegExp(r'\bcreateState\s*\(\s*\)\s*(?:=>\s*_' +
  //         RegExp.escape(className) +
  //         r'State\s*\(\s*\)|{\s*return\s+_' +
  //         RegExp.escape(className) +
  //         r'State\s*\(\s*\))')
  //     .hasMatch(line)) {
  //   return true;
  // }

  // // 6. Factory constructor definition
  // if (RegExp(r'\bfactory\s+' + RegExp.escape(className) + r'\.')
  //     .hasMatch(line)) {
  //   return true;
  // }

  // 7. Import statements
  // if (RegExp(r'^\s*import\s+').hasMatch(line)) {
  //   return true;
  // }

  // // 8. Export statements
  // if (RegExp(r'^\s*export\s+').hasMatch(line)) {
  //   return true;
  // }

  return false;
}

bool isConstructorDefinition(
    String content, RegExpMatch match, String className) {
  final matchStart = match.start;
  final lineInfo = getLineInfo(content, matchStart);
  final line = lineInfo.line.trim();

  // Check if we're inside a class definition
  final beforeMatch = content.substring(0, matchStart);
  final isInsideClass = isInsideClassDefinition(beforeMatch, className);

  if (isInsideClass == false) {
    return false; // If not inside class, it's likely a constructor call
  }

  // Get more context around the match
  final contextBefore = getContextBefore(content, matchStart, 100);
  final contextAfter =
      getContextAfter(content, matchStart + className.length, 50);

  // Check if this is clearly a constructor call (instantiation)
  if (isConstructorCall(contextBefore, contextAfter, className)) {
    return false;
  }

  // Constructor definition patterns inside a class:

  // 1. Constructor definition at start of line with various parameter patterns
  // Handles: ClassName(), const ClassName(), ClassName({...}), ClassName(params)
  final constructorDefPattern = RegExp(r'^\s*(?:const\s+|factory\s+)?' +
      RegExp.escape(className) +
      r'(?:\.[a-zA-Z_]\w*)?\s*\([^)]*\)\s*(?::\s*[^{;]*)?[{;]');
  if (constructorDefPattern.hasMatch(line)) {
    return true;
  }

  // 2. Check position and context for edge cases
  final positionInLine = matchStart - lineInfo.lineStart;
  final beforeClassName = line.substring(0, min(positionInLine, line.length));
  // If there's only whitespace and optionally modifiers before the class name
  if (RegExp(r'^\s*(?:const\s+|factory\s+)?$').hasMatch(beforeClassName)) {
    final afterMatchStart = positionInLine + className.length;
    if (afterMatchStart < line.length) {
      final afterMatch = line.substring(afterMatchStart).trim();

      // Constructor definition patterns after class name
      if (RegExp(r'^(?:\.[a-zA-Z_]\w*)?\s*\([^)]*\)\s*(?::\s*[^{;]*)?[{;]')
          .hasMatch(afterMatch)) {
        return true;
      }
    }
  }

  // 3. Multi-line constructor with initializer lists
  final multiLineContext = getMultiLineContext(content, matchStart, 3);
  final multiLinePattern = RegExp(
      r'^\s*(?:const\s+|factory\s+)?' +
          RegExp.escape(className) +
          r'(?:\.[a-zA-Z_]\w*)?\s*\([^)]*\)\s*:\s*(?:super\s*\(|this\s*\(|assert\s*\(|[a-zA-Z_]\w*\s*=)',
      multiLine: true,
      dotAll: true);

  if (multiLinePattern.hasMatch(multiLineContext)) {
    return true;
  }

  return false;
}

// New helper function to detect constructor calls
bool isConstructorCall(
    String contextBefore, String contextAfter, String className) {
  // Clean up context by removing extra whitespace
  final cleanBefore = contextBefore.replaceAll(RegExp(r'\s+'), ' ').trim();
  final cleanAfter = contextAfter.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Common patterns that indicate constructor calls rather than definitions

  // 1. Assignment patterns: var x = ClassName(), final y = const ClassName()
  if (RegExp(
          r'(?:^|[;\{\}])\s*(?:var|final|const|late|\w+)\s+\w*\s*=\s*(?:const\s+)?$')
      .hasMatch(cleanBefore)) {
    return true;
  }

  // 2. Return statement: return ClassName(), return const ClassName()
  if (RegExp(r'\breturn\s+(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 3. Function argument: someFunction(ClassName()), child: const ClassName()
  if (RegExp(r'[,\(]\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 4. Property assignment: child: ClassName(), body: const ClassName()
  if (RegExp(r':\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 5. List/collection items: [ClassName(), const ClassName()]
  if (RegExp(r'[\[\{,]\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 6. Ternary operator: condition ? ClassName() : other
  if (RegExp(r'\?\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 7. Null coalescing: something ?? ClassName()
  if (RegExp(r'\?\?\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 8. Lambda/arrow function body: () => ClassName()
  if (RegExp(r'=>\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 9. Builder pattern: builder: (context) => ClassName()
  if (RegExp(
          r'builder:\s*\([^)]*\)\s*(?:=>|\{.*return)\s*(?:[\w.]*\s*\(\s*[\w\s,:.]*\s*\)\s*\.\s*)*(?:const\s+)?$')
      .hasMatch(cleanBefore)) {
    return true;
  }

  // 10. MaterialPageRoute and similar patterns
  if (RegExp(
          r'MaterialPageRoute\s*\([^)]*builder:\s*\([^)]*\)\s*\{[^}]*return\s+[^;]*child:\s*(?:const\s+)?$')
      .hasMatch(cleanBefore)) {
    return true;
  }

  // 11. ChangeNotifierProvider and similar provider patterns
  if (RegExp(
          r'(?:Provider|ChangeNotifierProvider|Consumer)(?:\.\w+)?\s*\([^)]*child:\s*(?:const\s+)?$')
      .hasMatch(cleanBefore)) {
    return true;
  }

  // 12. Generic instantiation: List<ClassName>(), Map<String, ClassName>()
  if (RegExp(
          r'(?:List|Set|Map|Iterable|Future|Stream)<[^>]*>\s*\(\s*(?:const\s+)?$')
      .hasMatch(cleanBefore)) {
    return true;
  }

  // 13. Method chaining: something.method().ClassName()
  if (RegExp(r'\.\w+\([^)]*\)\s*\.\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 14. Cascade operator: object..property = ClassName()
  if (RegExp(r'\.\.[^=]*=\s*(?:const\s+)?$').hasMatch(cleanBefore)) {
    return true;
  }

  // 15. Check if followed by parentheses (constructor call)
  if (RegExp(r'^\s*\(').hasMatch(cleanAfter)) {
    // Additional checks to ensure it's a call, not a definition
    // If we're in a context that suggests instantiation
    if (RegExp(r'(?:=|return|:|,|\(|\[|\{|\?|\?\?|=>)\s*(?:const\s+)?$')
        .hasMatch(cleanBefore)) {
      return true;
    }
  }

  return false;
}

// Helper function to get context before the match
String getContextBefore(String content, int position, int maxLength) {
  final start = max(0, position - maxLength);
  return content.substring(start, position);
}

// Helper function to get context after the match
String getContextAfter(String content, int position, int maxLength) {
  final end = min(content.length, position + maxLength);
  return content.substring(position, end);
}

bool isInsideClassDefinition(String beforeContent, String className) {
  // Look for the class definition backwards from current position
  final classPattern =
      RegExp(r'\bclass\s+' + RegExp.escape(className) + r'\b[^{]*\{');
  final matches = classPattern.allMatches(beforeContent).toList();

  if (matches.isEmpty) return false;

  // Get the last class definition match
  final lastMatch = matches.last;

  // Count braces after the class definition to see if we're still inside
  final afterClassDef =
      beforeContent.substring(lastMatch.end - 1); // Include opening brace
  int braceCount = 0;

  for (int i = 0; i < afterClassDef.length; i++) {
    final char = afterClassDef[i];
    if (char == '{') {
      braceCount++;
    } else if (char == '}') {
      braceCount--;
      if (braceCount == 0) {
        return false; // We've exited the class
      }
    }
  }

  return braceCount > 0; // Still inside the class if braces are unmatched
}

String getMultiLineContext(String content, int position, int linesBefore) {
  final lines = content.substring(0, position).split('\n');
  final currentLineIndex = lines.length - 1;
  final startIndex = max(0, currentLineIndex - linesBefore);

  final contextLines = lines.sublist(startIndex);

  // Add some content after the position for context
  final afterPosition = content.substring(position);
  final nextLines = afterPosition.split('\n').take(2).toList();

  return (contextLines + nextLines).join('\n');
}

bool shouldExcludeFunctionMatch(
    String content, RegExpMatch match, String functionName) {
  final matchStart = match.start;

  // Get the line containing this match
  final lineInfo = getLineInfo(content, matchStart);
  final line = lineInfo.line;

  // 1. Function declaration/definition
  final functionDefPattern = RegExp(
    r'(?:^|\s)(?:static\s+)?(?:(?:void|int|double|String|bool|dynamic|List(?:<[^>]*>)?|Map(?:<[^,>]*,\s*[^>]*>)?|Set(?:<[^>]*>)?|Future(?:<[^>]*>)?|Stream(?:<[^>]*>)?|[A-Z][a-zA-Z0-9_]*(?:<[^>]*>)?)\s+)?' +
        RegExp.escape(functionName) +
        r'\s*\([^)]*\)\s*(?:async\s*)?(?:\{|=>|;)',
  );

  if (functionDefPattern.hasMatch(line)) {
    return true;
  }

  // 2. Getter/Setter definition
  if (RegExp(r'(?:get|set)\s+' +
          RegExp.escape(functionName) +
          r'\s*(?:\([^)]*\))?\s*(?:=>|{)')
      .hasMatch(line)) {
    return true;
  }

  // 3. Import/Export statements
  if (RegExp(r'^\s*(?:import|export)\s+').hasMatch(line)) {
    return true;
  }

  return false;
}

LineInfo getLineInfo(String content, int position) {
  final beforePosition = content.substring(0, position);
  final lastNewlineIndex = beforePosition.lastIndexOf('\n');
  final lineStart = lastNewlineIndex + 1;

  final nextNewlineIndex = content.indexOf('\n', position);
  final lineEnd = nextNewlineIndex == -1 ? content.length : nextNewlineIndex;

  final line = content.substring(lineStart, lineEnd);

  return LineInfo(line, lineStart);
}

bool isInComment(String content, int position) {
  // Find the line containing this position
  final lineInfo = getLineInfo(content, position);
  final line = lineInfo.line;
  final positionInLine = position - lineInfo.lineStart;

  // Check for single-line comments
  final singleLineComment = line.indexOf('//');
  if (singleLineComment != -1 && singleLineComment <= positionInLine) {
    return true;
  }

  // Check for multi-line comments
  final beforePositionContent = content.substring(0, position);
  int commentStart = -1;
  int searchIndex = 0;

  while (true) {
    final start = beforePositionContent.indexOf('/*', searchIndex);
    if (start == -1) break;

    final end = content.indexOf('*/', start);
    if (end == -1 || end > position) {
      commentStart = start;
      break;
    }

    searchIndex = end + 2;
  }

  return commentStart != -1;
}

bool isInString(String content, int position) {
  // Get the line containing this position
  final lineInfo = getLineInfo(content, position);
  final line = lineInfo.line;
  final positionInLine = position - lineInfo.lineStart;

  // Simple string detection within the line
  int singleQuotes = 0;
  int doubleQuotes = 0;
  bool escaped = false;

  for (int i = 0; i < positionInLine && i < line.length; i++) {
    final char = line[i];

    if (escaped) {
      escaped = false;
      continue;
    }

    if (char == '\\') {
      escaped = true;
      continue;
    }

    if (char == "'") singleQuotes++;
    if (char == '"') doubleQuotes++;
  }

  // If we have an odd number of quotes, we're inside a string
  return (singleQuotes % 2 == 1) || (doubleQuotes % 2 == 1);
}

class LineInfo {
  final String line;
  final int lineStart;

  LineInfo(this.line, this.lineStart);
}

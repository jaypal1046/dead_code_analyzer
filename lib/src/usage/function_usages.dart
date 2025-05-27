
import 'package:dead_code_analyzer/src/model/code_info.dart';

void analyzeFunctionUsages(
    String content, String filePath, Map<String, CodeInfo> functions) {
  for (final entry in functions.entries) {
    final functionName = entry.key;
    final functionInfo = entry.value;

    // Find all occurrences of the function name
    final usageRegex = RegExp(r'\b' + RegExp.escape(functionName) + r'\b');
    final allMatches = usageRegex.allMatches(content).toList();

    if (allMatches.isEmpty) continue;

    // Filter out definition-related matches
    final validMatches = <RegExpMatch>[];

    for (final match in allMatches) {
      if (_shouldExcludeFunctionMatch(content, match, functionName)) {
        continue;
      }

      if (_isInComment(content, match.start) ||
          _isInString(content, match.start)) {
        continue;
      }

      validMatches.add(match);
    }

    final usageCount = validMatches.length;

    if (filePath == functionInfo.definedInFile) {
      functionInfo.internalUsageCount = usageCount;
    } else if (usageCount > 0) {
      functionInfo.externalUsages[filePath] = usageCount;
    }
  }
}


bool _isInString(String content, int position) {
  // Get the line containing this position
  final lineInfo = _getLineInfo(content, position);
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




bool _shouldExcludeFunctionMatch(
    String content, RegExpMatch match, String functionName) {
  final matchStart = match.start;

  // Get the line containing this match
  final lineInfo = _getLineInfo(content, matchStart);
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


bool _isInComment(String content, int position) {
  // Find the line containing this position
  final lineInfo = _getLineInfo(content, position);
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


_LineInfo _getLineInfo(String content, int position) {
  final beforePosition = content.substring(0, position);
  final lastNewlineIndex = beforePosition.lastIndexOf('\n');
  final lineStart = lastNewlineIndex + 1;

  final nextNewlineIndex = content.indexOf('\n', position);
  final lineEnd = nextNewlineIndex == -1 ? content.length : nextNewlineIndex;

  final line = content.substring(lineStart, lineEnd);

  return _LineInfo(line, lineStart);
}



class _LineInfo {
  final String line;
  final int lineStart;

  _LineInfo(this.line, this.lineStart);
}


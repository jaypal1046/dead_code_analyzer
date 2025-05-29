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

    final validMatches = <RegExpMatch>[];

    for (final match in allMatches) {
      // Skip if in comment or string
      if (isInComment(content, match.start) ||
          isInString(content, match.start)) {
        continue;
      }

      // Skip if it's a function definition
      if (isFunctionDefinition(content, match, functionName)) {
        continue;
      }

      // Skip if it's a variable/property declaration or reference (not a function call)
      if (!isFunctionCall(content, match)) {
        continue;
      }

      // Skip if it's a constructor or class name
      if (isConstructorOrClassName(content, match, functionName)) {
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

// New function to check if it's actually a function call
bool isFunctionCall(String content, RegExpMatch match) {
  final matchEnd = match.end;

  // Get text immediately after the match
  final afterMatch = content.substring(matchEnd);
  final afterMatchTrimmed = afterMatch.trim();

  // Must be followed by opening parenthesis for function call
  if (!afterMatchTrimmed.startsWith('(')) {
    return false;
  }

  // Additional checks to avoid false positives
  final matchStart = match.start;
  final beforeMatch = content.substring(0, matchStart);
  final lines = beforeMatch.split('\n');
  final currentLine = lines.isNotEmpty ? lines.last : '';

  // Skip if it's part of a property access chain (like object.property)
  if (currentLine.trimRight().endsWith('.')) {
    return false;
  }

  // Skip if it's a type annotation (like List<String> functionName)
  final typeAnnotationPattern = RegExp(r'[<>\w\s,]*\s*$');
  if (typeAnnotationPattern.hasMatch(currentLine) &&
      (currentLine.contains('<') || currentLine.contains('>'))) {
    return false;
  }

  return true;
}

bool isFunctionDefinition(
    String content, RegExpMatch match, String functionName) {
  final matchStart = match.start;

  // Get the line containing the match and some context before it
  final beforeMatch = content.substring(0, matchStart);
  final lines = beforeMatch.split('\n');

  // Get current line and previous line for context
  final currentLine = lines.isNotEmpty ? lines.last : '';
  final previousLine = lines.length > 1 ? lines[lines.length - 2] : '';

  // Combine current and previous line for multi-line function definitions
  final contextLine = '$previousLine $currentLine'.trim();

  // Patterns that indicate function definition
  final definitionPatterns = [
    // Standard function definition at start of line
    RegExp(r'^\s*' + RegExp.escape(functionName) + r'\s*\('),

    // Function with return type
    RegExp(r'^\s*\w+\s+' + RegExp.escape(functionName) + r'\s*\('),

    // Static function
    RegExp(r'^\s*static\s+\w*\s*' + RegExp.escape(functionName) + r'\s*\('),

    // Async function
    RegExp(
        r'^\s*\w*\s*async\s+\w*\s*' + RegExp.escape(functionName) + r'\s*\('),

    // Function with modifiers
    RegExp(r'^\s*(?:public|private|protected)?\s*\w*\s*' +
        RegExp.escape(functionName) +
        r'\s*\('),

    // Getter/Setter
    RegExp(r'^\s*(?:get|set)\s+' + RegExp.escape(functionName)),
  ];

  // Check if any definition pattern matches
  for (final pattern in definitionPatterns) {
    if (pattern.hasMatch(currentLine) || pattern.hasMatch(contextLine)) {
      return true;
    }
  }

  // Additional check: if followed by parameter list and function body
  final afterMatch = content.substring(match.end);

  // Look for function signature pattern: (...) { or (...) =>
  final functionSignaturePattern = RegExp(r'^\s*\([^)]*\)\s*(?:\{|=>)');
  if (functionSignaturePattern.hasMatch(afterMatch)) {
    // But make sure it's not a function call in return/assignment
    final beforeContext = currentLine.trim().toLowerCase();
    if (beforeContext.startsWith('return ') ||
        beforeContext.contains('= ') ||
        beforeContext.contains('=> ')) {
      return false; // It's a function call
    }
    return true; // It's a function definition
  }

  return false;
}

bool isConstructorOrClassName(
    String content, RegExpMatch match, String functionName) {
  final matchStart = match.start;
  final beforeMatch = content.substring(0, matchStart);
  final lines = beforeMatch.split('\n');
  final currentLine = lines.isNotEmpty ? lines.last : '';

  // Check if it's preceded by 'new' keyword
  if (RegExp(r'\bnew\s+$').hasMatch(currentLine)) {
    return true;
  }

  // Check if it's a class definition
  if (RegExp(r'^\s*class\s+' + RegExp.escape(functionName))
      .hasMatch(currentLine)) {
    return true;
  }

  return false;
}

bool isInComment(String content, int position) {
  final beforePosition = content.substring(0, position);
  final lines = beforePosition.split('\n');
  final currentLine = lines.last;

  // Check for single line comment
  final singleLineCommentIndex = currentLine.indexOf('//');
  if (singleLineCommentIndex != -1) {
    final positionInLine =
        position - (beforePosition.length - currentLine.length);
    if (positionInLine > singleLineCommentIndex) {
      return true;
    }
  }

  // Check for multi-line comment
  final multiLineCommentStart = beforePosition.lastIndexOf('/*');
  final multiLineCommentEnd = beforePosition.lastIndexOf('*/');

  if (multiLineCommentStart != -1 &&
      (multiLineCommentEnd == -1 ||
          multiLineCommentStart > multiLineCommentEnd)) {
    return true;
  }

  return false;
}

bool isInString(String content, int position) {
  final beforePosition = content.substring(0, position);

  // Count unescaped quotes
  int singleQuoteCount = 0;
  int doubleQuoteCount = 0;
  bool inRawString = false;

  for (int i = 0; i < beforePosition.length; i++) {
    final char = beforePosition[i];
    final prevChar = i > 0 ? beforePosition[i - 1] : '';
    final isEscaped = prevChar == '\\';

    // Check for raw strings
    if (char == 'r' &&
        i + 1 < beforePosition.length &&
        (beforePosition[i + 1] == '"' || beforePosition[i + 1] == "'")) {
      inRawString = true;
      continue;
    }

    if (!isEscaped && !inRawString) {
      if (char == "'") singleQuoteCount++;
      if (char == '"') doubleQuoteCount++;
    }

    if (inRawString && (char == '"' || char == "'")) {
      inRawString = false;
    }
  }

  return (singleQuoteCount % 2 == 1) || (doubleQuoteCount % 2 == 1);
}

// Debug version for troubleshooting specific functions
void analyzeFunctionUsagesWithDebug(
    String content, String filePath, Map<String, CodeInfo> functions,
    {String? debugFunction}) {
  for (final entry in functions.entries) {
    final functionName = entry.key;
    final functionInfo = entry.value;

    final isDebugFunction =
        debugFunction == null || functionName == debugFunction;

    if (isDebugFunction) {
      print('=== Analyzing $functionName in $filePath ===');
    }

    final usageRegex = RegExp(r'\b' + RegExp.escape(functionName) + r'\b');
    final allMatches = usageRegex.allMatches(content).toList();

    if (isDebugFunction) {
      print('Total matches found: ${allMatches.length}');
    }

    if (allMatches.isEmpty) continue;

    final validMatches = <RegExpMatch>[];

    for (int i = 0; i < allMatches.length; i++) {
      final match = allMatches[i];

      if (isDebugFunction) {
        final matchText = content.substring(match.start, match.end);
        print('\nMatch $i: "$matchText" at position ${match.start}');

        // Show context
        final contextStart = (match.start - 30).clamp(0, content.length);
        final contextEnd = (match.end + 30).clamp(0, content.length);
        final context =
            content.substring(contextStart, contextEnd).replaceAll('\n', '\\n');
        print('Context: "$context"');

        // Show what comes after
        final afterMatch = content.substring(
            match.end, (match.end + 10).clamp(0, content.length));
        print('After match: "$afterMatch"');
      }

      if (isInComment(content, match.start)) {
        if (isDebugFunction) print('  -> SKIPPED: In comment');
        continue;
      }

      if (isInString(content, match.start)) {
        if (isDebugFunction) print('  -> SKIPPED: In string');
        continue;
      }

      if (isFunctionDefinition(content, match, functionName)) {
        if (isDebugFunction) print('  -> SKIPPED: Function definition');
        continue;
      }

      if (!isFunctionCall(content, match)) {
        if (isDebugFunction) {
          print(
              '  -> SKIPPED: Not a function call (no parentheses or wrong context)');
        }
        continue;
      }

      if (isConstructorOrClassName(content, match, functionName)) {
        if (isDebugFunction) print('  -> SKIPPED: Constructor/Class name');
        continue;
      }

      if (isDebugFunction) print('  -> ✓ VALID function call usage!');
      validMatches.add(match);
    }

    final usageCount = validMatches.length;

    if (isDebugFunction) {
      print('\nFinal results:');
      print('Valid usages: $usageCount');
      print('Is same file: ${filePath == functionInfo.definedInFile}');
    }

    if (filePath == functionInfo.definedInFile) {
      functionInfo.internalUsageCount = usageCount;
    } else if (usageCount > 0) {
      functionInfo.externalUsages[filePath] = usageCount;
    }

    if (isDebugFunction) {
      print('=== End Analysis ===\n');
    }
  }
}

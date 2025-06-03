// Fixed function detection with better comment handling
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';

void functionCollecter({
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
  if (analyzeFunctions) {
    // Updated regex to better handle functions without explicit return types
    final functionRegex = RegExp(
      r'(?://\s*)?' // Optional comment prefix (for actually commented functions)
      r'(?:(?:static\s+|abstract\s+|external\s+|final\s+|const\s+|override\s+|async\s+)*)' // Optional modifiers
      r'(?:' // Start optional return type group
      r'(?:void|int|double|String|bool|dynamic|' // Basic return types
      r'List(?:<[^>]+>)?|Map(?:<[^>]+,[^>]+>)?|Set(?:<[^>]+>)?|' // Generic collections
      r'Future(?:<[^>]+>)?|Stream(?:<[^>]+>)?|' // Async types
      r'[A-Z]\w*(?:<[^>]+>)?)\s+' // Custom types with optional generics
      r'|' // OR - no return type (like your setAddons function)
      r')' // End return type group
      r'(\w+)' // Function name (capture group 1) - REQUIRED
      r'\s*\([^)]*\)' // Parameters - REQUIRED
      r'\s*(?:async\s*\*?|sync\s*\*?)?' // Optional async modifiers
      r'\s*' // Optional whitespace
      r'((?:\{(?:[^{}]|{[^{}]*})*\})|(?:=>[^;]*;))', // Function body (capture group 2)
      multiLine: true,
    );

    String currentLine = line;

    // Skip lines that are clearly function calls
    if (_isFunctionCall(line)) {
      return;
    }

    // Handle multi-line functions
    if (line.contains('{') && !line.contains('}')) {
      StringBuffer fullFunction = StringBuffer(line);
      int braceCount = 1;
      int nextLineIndex = lineIndex + 1;

      while (braceCount > 0 && nextLineIndex < lines.length) {
        String nextLine = lines[nextLineIndex];
        fullFunction.writeln(nextLine);
        braceCount += nextLine.split('{').length - 1;
        braceCount -= nextLine.split('}').length - 1;
        nextLineIndex++;
      }
      currentLine = fullFunction.toString();
    }

    final functionMatches = functionRegex.allMatches(currentLine);

    for (final match in functionMatches) {
      final functionName = match.group(1);
      final functionBody = match.group(2);

      if (functionName == null || functionName.isEmpty) {
        continue;
      }

      // Additional validation to ensure this is a function definition
      if (!_isValidFunctionDefinition(currentLine, match, functionName)) {
        continue;
      }

      // FIXED: Better comment detection
      bool isCommentedOut = _isLineCommented(lines, lineIndex, line);

      //todo:: this is debug handler // Debug for your specific function
      // if (functionName == 'setAddons') {
      //   print('DEBUG: Function $functionName at line $lineIndex');
      //   print('DEBUG: Line content: "${lines[lineIndex]}"');
      //   print('DEBUG: Original line: "$line"');
      //   print('DEBUG: Is commented: $isCommentedOut');
      //   print(
      //       'DEBUG: Line starts with //: ${lines[lineIndex].trim().startsWith('//')}');
      //   print(
      //       'DEBUG: In multi-line comment: ${_isInsideMultiLineComment(lines, lineIndex)}');
      //   print('---');
      // }

      bool isEntryPoint = false;
      bool isPrebuiltFlutter =
          insideStateClass && prebuiltFlutterMethods.contains(functionName);

      bool isEmpty = functionBody == null ||
          functionBody == ';' ||
          functionBody.replaceAll(RegExp(r'\s+'), '') == '{}';

      bool isThisConstructor = isConstructor(functionName, currentLine);

      // Check for @pragma('vm:entry-point') annotation
      if (lineIndex > 0 && !isCommentedOut) {
        if (pragmaRegex.hasMatch(lines[lineIndex - 1])) {
          isEntryPoint = true;
        } else {
          int checkIndex = lineIndex - 2;
          while (checkIndex >= 0 && checkIndex >= lineIndex - 2) {
            if (pragmaRegex.hasMatch(lines[checkIndex])) {
              isEntryPoint = true;
              break;
            }
            checkIndex--;
          }
        }
      }

      String functionKey = functionName;
      bool isStaticFunction = false;
      if (isCommentedOut) {
        functionKey =
            '$functionName _LineNo:${lineIndex}_PositionNo:${match.start} ${sanitizeFilePath(filePath)}';
      } else if (functions.containsKey(functionName)) {
        isStaticFunction = isItStaticFunction(currentLine);
        functionKey = functionName;
      }

      if (!isCommentedOut &&
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
}

bool isItStaticFunction(String line) {
  // Check if the line starts with 'static' followed by a function definition
  return line.trim().startsWith('static ') &&
      RegExp(r'\w+\s*\([^)]*\)\s*{').hasMatch(line);
}

// FIXED: More accurate comment detection
bool _isLineCommented(
    List<String> lines, int targetLineIndex, String originalLine) {
  if (targetLineIndex < 0 || targetLineIndex >= lines.length) {
    return false;
  }

  String targetLine = lines[targetLineIndex];

  // First check the actual line content from the file
  String trimmedLine = targetLine.trim();

  // Only consider it commented if it actually starts with comment markers
  if (trimmedLine.startsWith('//') || trimmedLine.startsWith('///')) {
    return true;
  }
  // // Check if we're inside a multi-line comment block
  bool inMultiLineComment = _isInsideMultiLineComment(lines, targetLineIndex);
  if (inMultiLineComment) {
    print(
        "DEBUG: Line $targetLineIndex is inside a multi-line comment block. Line content: $targetLine");
  }

  // if(){
  //     return inMultiLineComment;
  // }
  return false;
}

// FIXED: More robust multi-line comment detection
bool _isInsideMultiLineComment(List<String> lines, int targetLineIndex) {
  bool inComment = false;

  // Check from the beginning of file up to target line
  for (int lineIdx = 0; lineIdx <= targetLineIndex; lineIdx++) {
    String line = lines[lineIdx];

    // Process each character in the line
    for (int charIdx = 0; charIdx < line.length; charIdx++) {
      // Skip if we're inside a string literal
      if (_isInsideString(line, charIdx)) {
        continue;
      }

      // Check for comment start /*
      if (charIdx < line.length - 1 &&
          line[charIdx] == '/' &&
          line[charIdx + 1] == '*') {
        inComment = true;
        charIdx++; // Skip the '*'
      }
      // Check for comment end */
      else if (charIdx < line.length - 1 &&
          line[charIdx] == '*' &&
          line[charIdx + 1] == '/') {
        inComment = false;
        charIdx++; // Skip the '/'
      }
    }

    // If we've reached the target line and we're in a comment, return true
    if (lineIdx == targetLineIndex && inComment) {
      return true;
    }
  }

  return false;
}

bool _isInsideString(String line, int position) {
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

bool _isFunctionCall(String line) {
  String trimmed = line.trim();

  // Check for method calls with dot notation
  if (RegExp(r'\w+\.\w+\s*\(').hasMatch(trimmed)) {
    return true;
  }

  // Check for other call patterns
  List<String> callPatterns = [
    r'await\s+\w+(?:\.\w+)?\s*\(',
    r'\w+\s*=\s*\w+(?:\.\w+)?\s*\(',
    r'return\s+\w+(?:\.\w+)?\s*\(',
    r'if\s*\(\s*\w+(?:\.\w+)?\s*\(',
    r'while\s*\(\s*\w+(?:\.\w+)?\s*\(',
  ];

  for (String pattern in callPatterns) {
    if (RegExp(pattern).hasMatch(trimmed)) {
      return true;
    }
  }

  return false;
}

bool _isValidFunctionDefinition(
    String line, RegExpMatch match, String functionName) {
  String beforeMatch = line.substring(0, match.start).trim();

  // If there's a dot right before the function name, it's likely a method call
  if (beforeMatch.endsWith('.')) {
    return false;
  }

  // Check if this looks like a parameter in a function call
  if (RegExp(r'\w+\s*:\s*$').hasMatch(beforeMatch)) {
    return false;
  }

  // Check for assignment patterns
  if (RegExp(r'=\s*$').hasMatch(beforeMatch)) {
    return false;
  }

  return true;
}

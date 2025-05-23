import 'package:dead_code_analyzer/src/model/code_info.dart';

void functionCollecter(
    {required bool analyzeFunctions,
    required String line,
    required bool insideStateClass,
    required Set<String> prebuiltFlutterMethods,
    required int lineIndex,
    required RegExp pragmaRegex,
    required List<String> lines,
    required Map<String, CodeInfo> functions,
    required String filePath}) {
  if (analyzeFunctions) {
    // // Check if the line is commented out
    // bool isCommentedOut = _isLineCommented(line);

    // Enhanced function regex that handles various patterns
    final functionRegex = RegExp(
      r'(?://\s*)?' // Optional comment prefix
      r'(?:(?:static\s+|abstract\s+|external\s+)*)?' // Optional modifiers
      r'(?:(?:void|int|double|String|bool|dynamic|' // Return types
      r'List<[^>]+>|Map<[^>]+,[^>]+>|Set<[^>]+>|' // Generic collections
      r'Future(?:<[^>]+>)?|Stream(?:<[^>]+>)?|' // Async types
      r'[A-Z]\w*(?:<[^>]+>)?)\s+)?' // Custom types with optional generics
      r'(?:\w+\.)?' // Optional class prefix
      r'(\w+)' // Function name (capture group 1)
      r'\s*\([^)]*\)' // Parameters
      r'\s*(?:async\s*\*?|sync\s*\*?)?' // Optional async modifiers
      r'\s*' // Optional whitespace
      r'({[^{}]*(?:{[^{}]*}[^{}]*)*}|;)', // Function body (capture group 2)
      multiLine: true,
    );

    final functionMatches = functionRegex.allMatches(line);

    for (final match in functionMatches) {
      final functionName = match.group(1)!;
      final functionBody = match.group(2)!;

      // Check if this specific function is commented out
      bool isFunctionCommented =
          _isFunctionCommented(line, match, lines, lineIndex);

      bool isEntryPoint = false;
      bool isPrebuiltFlutter =
          insideStateClass && prebuiltFlutterMethods.contains(functionName);

      bool isEmpty = functionBody == ';' ||
          functionBody.replaceAll(RegExp(r'\s+'), '') == '{}';

      // Check for constructor
      bool isConstructor = _isConstructor(functionName, line);

      // Check for @pragma('vm:entry-point') annotation
      if (lineIndex > 0 && !isFunctionCommented) {
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

      // Only add to functions map if we want to track commented functions
      // or if the function is not commented out
      String functionKey = isFunctionCommented
          ? '${functionName}_commented_${lineIndex}'
          : functionName;

      functions[functionKey] = CodeInfo(
        filePath,
        isEntryPoint: isEntryPoint,
        type: 'function',
        isPrebuiltFlutter: isPrebuiltFlutter,
        isEmpty: isEmpty,
        isConstructor: isConstructor,
        commentedOut: isFunctionCommented,
      );
    }
  }
}

// Helper function to check if a line is commented out
bool _isLineCommented(String line) {
  String trimmed = line.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('/*') ||
      _isInsideBlockComment(trimmed);
}

// Helper function to check if function is inside block comment
bool _isInsideBlockComment(String line) {
  // This is a simplified check - for more robust handling,
  // you'd need to track block comment state across multiple lines
  return line.contains('/*') && !line.contains('*/');
}

// Helper function to determine if a specific function match is commented
bool _isFunctionCommented(
    String line, RegExpMatch match, List<String> lines, int lineIndex) {
  // Check if the function declaration itself starts with //
  String beforeFunction = line.substring(0, match.start);
  String functionPart = line.substring(match.start);

  // Check if there's a // before the function on the same line
  if (beforeFunction.trim().endsWith('//') ||
      functionPart.trim().startsWith('//')) {
    return true;
  }

  // Check if the entire line is commented
  if (_isLineCommented(line)) {
    return true;
  }

  // Check for multi-line comment scenarios
  return _isInMultiLineComment(lines, lineIndex, match.start);
}

// Helper function to check if position is inside multi-line comment
bool _isInMultiLineComment(
    List<String> lines, int lineIndex, int charPosition) {
  // Look backwards to find /* without matching */
  for (int i = lineIndex; i >= 0; i--) {
    String currentLine =
        i == lineIndex ? lines[i].substring(0, charPosition) : lines[i];

    // Check for */ first (end of comment)
    int endComment = currentLine.lastIndexOf('*/');
    int startComment = currentLine.lastIndexOf('/*');

    if (endComment > startComment && endComment != -1) {
      return false; // Found end of comment block
    }

    if (startComment != -1 && (endComment == -1 || startComment > endComment)) {
      return true; // Found start of comment block without end
    }
  }

  return false;
}

// Helper function to check if function is a constructor
bool _isConstructor(String functionName, String line) {
  // Basic check - constructor names typically match class names
  // or are named constructors (ClassName.namedConstructor)
  RegExp constructorPattern = RegExp(r'^\s*(?://\s*)?[A-Z]\w*(?:\.\w+)?\s*\(');
  return constructorPattern.hasMatch(line.trim()) &&
      functionName[0].toUpperCase() == functionName[0];
}

// Additional helper function to clean up commented function names
String getCleanFunctionName(String functionKey) {
  if (functionKey.contains('_commented_')) {
    return functionKey.split('_commented_')[0];
  }
  return functionKey;
}

// Helper function to get all commented functions
Map<String, CodeInfo> getCommentedFunctions(Map<String, CodeInfo> functions) {
  return Map.fromEntries(
      functions.entries.where((entry) => entry.value.commentedOut));
}

// Helper function to get all active (non-commented) functions
Map<String, CodeInfo> getActiveFunctions(Map<String, CodeInfo> functions) {
  return Map.fromEntries(
      functions.entries.where((entry) => !entry.value.commentedOut));
}

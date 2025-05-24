// Main function to collect function information
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
}) {
  if (analyzeFunctions) {
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
          isFunctionInCommented(line, match, lines, lineIndex);

      bool isEntryPoint = false;
      bool isPrebuiltFlutter =
          insideStateClass && prebuiltFlutterMethods.contains(functionName);

      bool isEmpty = functionBody == ';' ||
          functionBody.replaceAll(RegExp(r'\s+'), '') == '{}';

      // Check for constructor
      bool isThisConstructor = isConstructor(functionName, line);

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

      String functionKey = functionName;
if (isFunctionCommented) {
  // Commented functions: Include file path, line, and position
  functionKey = '${functionName}_commented_${sanitizeFilePath(filePath)}_${lineIndex}_${match.start}';
} else if (functions.containsKey(functionName)) {
  // Non-commented functions: Append file path if there's a collision
  functionKey = '${functionName}_${sanitizeFilePath(filePath)}';
}

      // String functionKey = isFunctionCommented
      //     ? '${functionName}_commented_${lineIndex}_${match.start}'
      //     : functionName;

      functions[functionKey] = CodeInfo(
        filePath,
        isEntryPoint: isEntryPoint,
        type: 'function',
        isPrebuiltFlutter: isPrebuiltFlutter,
        isEmpty: isEmpty,
        isConstructor: isThisConstructor,
        commentedOut: isFunctionCommented,
        lineIndex: lineIndex,
        startPosition: match.start,
      );
    }
  }
}

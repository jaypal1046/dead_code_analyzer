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
  final functionRegex = RegExp(
    r'(?://\s*)?' // Optional comment prefix
    r'(?:(?:static\s+|abstract\s+|external\s+|final\s+|const\s+)*)' // Optional modifiers
    r'(?:(?:void|int|double|String|bool|dynamic|' // Return types
    r'List<[^>]+>|Map<[^>]+,[^>]+>|Set<[^>]+>|' // Generic collections
    r'Future(?:<[^>]+>)?|Stream(?:<[^>]+>)?|' // Async types
    r'[A-Z]\w*(?:<[^>]+>)?)\s+)' // Return type (required)
    r'(?:\w+\.)?' // Optional class prefix
    r'(\w+)' // Function name (capture group 1)
    r'\s*\([^)]*\)' // Parameters
    r'\s*(?:async\s*\*?|sync\s*\*?)?' // Optional async modifiers
    r'\s*' // Optional whitespace
    r'({(?:[^{}]|{[^{}]*})*}|=>[^;]*;)', // Function body or fat arrow
    multiLine: true,
  );

  // Check if the line might be the start of a function
  String currentLine = line;

  // If the line contains an opening brace but no closing brace, concatenate subsequent lines
  if (line.contains('{') && !line.contains('}')) {
    StringBuffer fullFunction = StringBuffer(line);
    int braceCount = 1; // Track open braces
    int nextLineIndex = lineIndex + 1;

    while (braceCount > 0 && nextLineIndex < lines.length) {
      String nextLine = lines[nextLineIndex];
      fullFunction.writeln(nextLine);
      braceCount += nextLine.split('{').length - 1; // Count opening braces
      braceCount -= nextLine.split('}').length - 1; // Count closing braces
      nextLineIndex++;
    }
    currentLine = fullFunction.toString();
  }

  final functionMatches = functionRegex.allMatches(currentLine);

  for (final match in functionMatches) {
    final functionName = match.group(1)!;
    final functionBody = match.group(2)!;

    // Skip built-in methods or known function calls
    if (prebuiltFlutterMethods.contains(functionName) ||
        functionName == 'toString') {
      continue;
    }

    // Check if this specific function is commented out
    bool isFunctionCommented =
        isFunctionInCommented(currentLine, match, lines, lineIndex);

    bool isEntryPoint = false;
    bool isPrebuiltFlutter =
        insideStateClass && prebuiltFlutterMethods.contains(functionName);

    bool isEmpty = functionBody == ';' ||
        functionBody.replaceAll(RegExp(r'\s+'), '') == '{}';

    // Check for constructor
    bool isThisConstructor = isConstructor(functionName, currentLine);

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
      functionKey =
          '${functionName}commented_${sanitizeFilePath(filePath)}_${lineIndex}_${match.start}';
    } else if (functions.containsKey(functionName)) {
      functionKey = functionName;
    }

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

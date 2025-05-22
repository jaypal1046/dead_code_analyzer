import 'package:dead_code_analyzer/src/model/code_info.dart';

void functionCollecter(
    bool analyzeFunctions,
    String line,
    bool insideStateClass,
    Set<String> prebuiltFlutterMethods,
    int lineIndex,
    RegExp pragmaRegex,
    List<String> lines,
    Map<String, CodeInfo> functions,
    String filePath) {
  // Function detection (only if analyzeFunctions is true)
  if (analyzeFunctions) {
    // Match various function types, including prebuilt Flutter methods
    final functionRegex = RegExp(
        r'(?:(?:static\s+)?(?:void|int|double|String|bool|dynamic|List<\w+>|Map<\w+,\w+>|Future(?:<\w+>)?)\s+|)(?:\w+\.)?(\w+)\s*\([^)]*\)\s*(?:(?:async)?\s*({(?:\s*//.*)*\s*}|;))',
        multiLine: true);
    final functionMatches = functionRegex.allMatches(line);
    for (final match in functionMatches) {
      final functionName = match.group(1)!;
      final functionBody = match.group(2); // {} or ;
      bool isEntryPoint = false;
      bool isPrebuiltFlutter =
          insideStateClass && prebuiltFlutterMethods.contains(functionName);
      bool isEmpty = functionBody == ';' || functionBody!.trim() == '{}';
      if (lineIndex > 0) {
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
      functions[functionName] = CodeInfo(filePath,
          isEntryPoint: isEntryPoint,
          type: 'function',
          isPrebuiltFlutter: isPrebuiltFlutter,
          isEmpty: isEmpty);
    }
  }
}

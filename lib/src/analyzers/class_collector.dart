import 'package:dead_code_analyzer/src/model/class_info.dart';

void classCollector(
    RegExpMatch? classMatch,
    int lineIndex,
    RegExp pragmaRegex,
    List<String> lines,
    Map<String, ClassInfo> classes,
    String filePath,
    bool insideStateClass) {
  // Class detection
  if (classMatch != null) {
    final className = classMatch.group(1)!;
    bool isEntryPoint = false;
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
    classes[className] = ClassInfo(filePath,
        isEntryPoint: isEntryPoint,
        type: insideStateClass ? 'state_class' : 'class');
  }
}

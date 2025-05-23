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
    bool isCommentedOut = false;

    // Check if the class is commented out
    // Single-line comment check
    if (lines[lineIndex].trim().startsWith('//')) {
      isCommentedOut = true;
    } else {
      // Multi-line comment check
      bool inMultiLineComment = false;
      for (int i = 0; i <= lineIndex; i++) {
        String line = lines[i].trim();
        if (line.contains('/*') && !line.contains('*/')) {
          inMultiLineComment = true;
        } else if (line.contains('*/')) {
          inMultiLineComment = false;
        }
      }
      if (inMultiLineComment) {
        isCommentedOut = true;
      }
    }

    // Check for entry point (unchanged from original)
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

    // Store class information with commentedOut flag
    classes[className] = ClassInfo(
      filePath,
      isEntryPoint: isEntryPoint,
      commentedOut: isCommentedOut,
      type: insideStateClass ? 'state_class' : 'class',
    );
  }
}

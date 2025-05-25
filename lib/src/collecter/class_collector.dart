import 'package:dead_code_analyzer/src/model/class_info.dart';

void classCollector(
  RegExpMatch? classMatch,
  int lineIndex,
  RegExp pragmaRegex,
  List<String> lines,
  Map<String, ClassInfo> classes,
  String filePath,
  bool insideStateClass,
) {
  String line = lines[lineIndex].trim();
  // Strip single-line comments and multi-line comment markers for regex matching
  String cleanLine =
      line.replaceFirst(RegExp(r'^\s*(?:(?:\/\/+|\/\*|\*\/)\s*)*'), '');
  // Re-apply regex to ensure correct matching (in case classMatch is from a different regex)
  final classRegex = RegExp(
    r'^(?:\s*(?:\/\*|\*\/)?\s*(?:sealed\s+|abstract\s+|mixin\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:extends\s+[A-Za-z_][A-Za-z0-9_]*(?:<[^>]+>)?\s*)?(?:implements\s+[A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\s*)?(?:with\s+[A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\s*)?)\{\s*(?:\*\/)?\s*$',
    multiLine: true,
  );
  classMatch = classRegex.firstMatch(cleanLine);

  if (classMatch != null) {
    final className = classMatch.group(1)!;
    bool isEntryPoint = false;
    bool isCommentedOut = false;

    // Comment detection
    bool inMultiLineComment = false;
    for (int i = 0; i <= lineIndex; i++) {
      String currentLine = lines[i].trim();
      if (currentLine.isEmpty) continue;
      if (currentLine.contains('/*') && !currentLine.contains('*/')) {
        inMultiLineComment = true;
      }
      if (currentLine.contains('*/')) {
        inMultiLineComment = false;
      }
      if (i == lineIndex &&
          (currentLine.startsWith('//') ||
              currentLine.startsWith('///') ||
              currentLine.contains('/*') ||
              currentLine.contains('*/'))) {
        isCommentedOut = true;
      }
    }
    if (inMultiLineComment) {
      isCommentedOut = true;
    }

    // Entry point check
    if (lineIndex > 0) {
      if (pragmaRegex.hasMatch(lines[lineIndex - 1].trim())) {
        isEntryPoint = true;
      } else {
        int checkIndex = lineIndex - 2;
        while (checkIndex >= 0 && checkIndex >= lineIndex - 2) {
          if (pragmaRegex.hasMatch(lines[checkIndex].trim())) {
            isEntryPoint = true;
            break;
          }
          checkIndex--;
        }
      }
    }

    // Determine class type
    String classType;
    if (insideStateClass) {
      classType = 'state_class';
    } else if (cleanLine.contains('sealed class')) {
      classType = 'class';
    } else if (cleanLine.contains('abstract class')) {
      classType = 'class';
    } else if (cleanLine.contains('mixin class')) {
      classType = 'class';
    } else if (cleanLine.contains('extends State<')) {
      classType = 'state_class';
      insideStateClass = true;
    } else if (cleanLine.contains('extends StatelessWidget') ||
        cleanLine.contains('extends StatefulWidget')) {
      classType = 'class';
    } else {
      classType = 'class';
    }

    // Store class information
    classes[className] = ClassInfo(
      filePath,
      isEntryPoint: isEntryPoint,
      commentedOut: isCommentedOut,
      type: classType,
    );
  }
}

import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';

class ClassCollector {
  static void classCollector(
    RegExpMatch? classMatch,
    int lineIndex,
    RegExp pragmaRegex,
    List<String> lines,
    Map<String, ClassInfo> classes,
    String filePath,
    bool insideStateClass,
  ) {
    String line = lines[lineIndex];
    String trimmedLine = line.trim();

    // Skip empty lines
    if (trimmedLine.isEmpty) return;

    // Enhanced patterns to handle multi-line comments
    List<RegExp> classPatterns = [
      // 0. Regular class declarations (including all modifiers and commented ones)
      RegExp(
          r'^\s*(?:\/\/+\s*|\*\s*)?(?:sealed\s+|abstract\s+|base\s+|final\s+|interface\s+)*class\s+([A-Za-z_][A-Za-z0-9_]*)',
          multiLine: false),

      // 1. Enum declarations
      RegExp(r'^\s*(?:\/\/+\s*|\*\s*)?enum\s+([A-Za-z_][A-Za-z0-9_]*)',
          multiLine: false),

      // 2. Mixin declarations
      RegExp(r'^\s*(?:\/\/+\s*|\*\s*)?mixin\s+([A-Za-z_][A-Za-z0-9_]*)',
          multiLine: false),

      // 3. Extension with name
      RegExp(
          r'^\s*(?:\/\/+\s*|\*\s*)?extension\s+([A-Za-z_][A-Za-z0-9_]*(?:<[^>]*>)?)\s+on\s+',
          multiLine: false),

      // 4. Anonymous extension
      RegExp(
          r'^\s*(?:\/\/+\s*|\*\s*)?extension\s+on\s+([A-Za-z_][A-Za-z0-9_<>,\s]*)',
          multiLine: false),

      // 5. Typedef declarations
      RegExp(r'^\s*(?:\/\/+\s*|\*\s*)?typedef\s+([A-Za-z_][A-Za-z0-9_]*)',
          multiLine: false),

      // 6. Mixin class declarations (Dart 3.0+)
      RegExp(r'^\s*(?:\/\/+\s*|\*\s*)?mixin\s+class\s+([A-Za-z_][A-Za-z0-9_]*)',
          multiLine: false),
    ];

    String? className;
    String classType = 'class';
    bool isCommentedOut = false;
    if (trimmedLine.contains("enum")) {
      print('Testing line: $line');
    }

    // Check if we're inside a multi-line comment
    bool inMultiLineComment = _isInMultiLineComment(lines, lineIndex);

    // Check mixin class first (specific case before general mixin)
    if (trimmedLine.contains('mixin class') || trimmedLine.contains('mixin')) {
      for (RegExp pattern in classPatterns) {
        RegExpMatch? match = pattern.firstMatch(trimmedLine);
        if (match != null && pattern == classPatterns[6]) {
          // mixin class pattern
          className = match.group(1)!;
          classType = 'mixin_class';
          isCommentedOut = _isLineCommented(trimmedLine, inMultiLineComment);
          break;
        }
      }
    }

    // If not found yet, check other patterns
    if (className == null) {
      for (int i = 0; i < classPatterns.length; i++) {
        if (i == 6) continue; // Skip mixin class as we handled it above

        RegExp pattern = classPatterns[i];
        RegExpMatch? match = pattern.firstMatch(trimmedLine);

        if (match != null) {
          className = match.group(1)!;
          isCommentedOut = _isLineCommented(trimmedLine, inMultiLineComment);

          // Don't match mixin class with regular mixin pattern
          if (i == 2 && trimmedLine.contains('mixin class')) {
            continue;
          }

          switch (i) {
            case 0:
              classType = _determineClassType(trimmedLine, insideStateClass);
              break;
            case 1:
              classType = 'enum';
              break;
            case 2:
              classType = 'mixin';
              break;
            case 3:
              classType = 'extension';
              break;
            case 4:
              classType = 'extension';
              className =
                  'ExtensionOn ${className.replaceAll(RegExp(r'[<>,\s]'), '')}';
              break;
            case 5:
              classType = 'typedef';
              break;
          }
          break;
        }
      }
    }

    if (className != null) {
      // Skip if it's a Dart keyword or built-in type
      if (_isDartKeyword(className)) {
        return;
      }

      // Entry point check
      bool isEntryPoint = _checkEntryPoint(lines, lineIndex, pragmaRegex);

      // Calculate startPosition
      int startPosition =
          _calculateStartPosition(lines, lineIndex, trimmedLine, line);

      // Store class information
      classes[className] = ClassInfo(
        filePath,
        isEntryPoint: isEntryPoint,
        commentedOut: isCommentedOut,
        type: classType,
        lineIndex: lineIndex, // Use the provided lineIndex directly
        startPosition: startPosition, // Use the calculated startPosition
      );
    }
  }

// Helper function to calculate startPosition
  static int _calculateStartPosition(List<String> lines, int lineIndex,
      String trimmedLine, String originalLine) {
    int startPosition = 0;

    // Sum the lengths of all previous lines, including newline characters
    for (int i = 0; i < lineIndex; i++) {
      startPosition += lines[i].length + 1; // Add 1 for the newline character
    }

    // Add the offset within the current line (position where trimmedLine starts in originalLine)
    int leadingWhitespaceLength =
        originalLine.length - originalLine.trimLeft().length;
    startPosition += leadingWhitespaceLength;

    return startPosition;
  }

  /// Enhanced function to check if a line is commented out
  static bool _isLineCommented(String trimmedLine, bool inMultiLineComment) {
    // Check for single-line comments
    if (trimmedLine.startsWith('//')) {
      return true;
    }

    // Check for multi-line comment markers
    if (trimmedLine.startsWith('*') || trimmedLine.startsWith('*/')) {
      return true;
    }

    // If we're inside a multi-line comment block
    if (inMultiLineComment) {
      return true;
    }

    return false;
  }

  /// Enhanced function to check if we're inside a multi-line comment
  static bool _isInMultiLineComment(List<String> lines, int lineIndex) {
    bool inComment = false;

    for (int i = 0; i <= lineIndex; i++) {
      String line = lines[i];

      // Process line character by character to handle nested comments
      int j = 0;
      while (j < line.length - 1) {
        if (line.substring(j, j + 2) == '/*') {
          inComment = true;
          j += 2; // Skip both characters
        } else if (line.substring(j, j + 2) == '*/') {
          inComment = false;
          j += 2; // Skip both characters
        } else {
          j++;
        }
      }
    }

    return inComment;
  }

  /// Determine the specific type of class with improved detection
  static String _determineClassType(String line, bool insideStateClass) {
    String lowerLine = line.toLowerCase();

    // Check for mixin class first (Dart 3.0+)
    if (lowerLine.contains('mixin class')) {
      return 'mixin_class';
    } else if (lowerLine.contains('sealed class') ||
        lowerLine.contains('sealed')) {
      return 'sealed_class';
    } else if (lowerLine.contains('base class') || lowerLine.contains('base')) {
      return 'base_class';
    } else if (lowerLine.contains('final class') ||
        lowerLine.contains('final')) {
      return 'final_class';
    } else if (lowerLine.contains('interface class') ||
        lowerLine.contains('interface')) {
      return 'interface_class';
    } else if (lowerLine.contains('abstract class') ||
        lowerLine.contains('abstract')) {
      return 'abstract_class';
    } else if (lowerLine.contains('extends state<') ||
        lowerLine.contains('state<')) {
      return 'state_class';
    } else if (lowerLine.contains('extends statelesswidget')) {
      return 'stateless_widget';
    } else if (lowerLine.contains('extends statefulwidget')) {
      return 'stateful_widget';
    } else {
      return 'class';
    }
  }

  /// Check if the class has an entry point pragma
  static bool _checkEntryPoint(
      List<String> lines, int lineIndex, RegExp pragmaRegex) {
    // Check the previous 5 lines for pragma annotations
    for (int i = 1; i <= 5 && lineIndex - i >= 0; i++) {
      String prevLine = lines[lineIndex - i].trim();
      if (pragmaRegex.hasMatch(prevLine)) {
        return true;
      }
      // Continue checking even if we hit comments or annotations
      if (prevLine.isNotEmpty &&
          !prevLine.startsWith('//') &&
          !prevLine.startsWith('/*') &&
          !prevLine.startsWith('*') &&
          !prevLine.startsWith('*/') &&
          !prevLine.startsWith('@') &&
          !prevLine.startsWith('///')) {
        // Only stop if we hit actual code (not comments or annotations)
        if (!prevLine.contains('class') &&
            !prevLine.contains('enum') &&
            !prevLine.contains('mixin') &&
            !prevLine.contains('extension') &&
            !prevLine.contains('typedef')) {
          break;
        }
      }
    }
    return false;
  }

  /// Check if the identifier is a Dart keyword that should be ignored
  static bool _isDartKeyword(String identifier) {
    return Healper.keywords.contains(identifier.toLowerCase());
  }
}

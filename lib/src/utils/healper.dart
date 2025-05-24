import 'dart:io';

import 'package:args/args.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';

List<File> getDartFiles(Directory dir) {
  return dir
      .listSync(recursive: true)
      .where((entity) =>
          entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.contains('/.dart_tool/') &&
          !entity.path.contains('/build/'))
      .cast<File>()
      .toList();
}

void printUsage(ArgParser parser) {
  print('Usage: dart bin/dead_code_analyzer.dart [options]');
  print(parser.usage);
  print('\nExample:');
  print(
      '  dart bin/dead_code_analyzer.dart -p /path/to/flutter/project -o /path/to/save/report --analyze-functions --max-unused 20');
}

// Helper function to check if a line is commented out
bool isLineCommented(String line) {
  String trimmed = line.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('/*') && trimmed.endsWith('*/') ||
      isInsideBlockComment(trimmed);
}

// Helper function to check if function is inside block comment
bool isInsideBlockComment(String line) {
  // Simplified check for single-line block comments
  return line.contains('/*') && line.contains('*/');
}

// Helper function to determine if a specific function match is commented
bool isFunctionInCommented(
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
  if (isLineCommented(line)) {
    return true;
  }

  // Check for multi-line comment scenarios
  return isInMultiLineComment(lines, lineIndex, match.start);
}

// Helper function to check if a position is inside a multi-line comment
bool isInMultiLineComment(List<String> lines, int lineIndex, int charPosition) {
  bool insideComment = false;

  // Iterate through lines up to the current line
  for (int i = 0; i <= lineIndex; i++) {
    String lineToCheck = lines[i];
    int endPos = (i == lineIndex) ? charPosition : lineToCheck.length;

    int pos = 0;
    while (pos < endPos - 1) {
      // Skip single-line comments
      if (pos < lineToCheck.length - 1 &&
          lineToCheck[pos] == '/' &&
          lineToCheck[pos + 1] == '/') {
        break; // Ignore rest of the line
      }

      // Check for start of multi-line comment
      if (!insideComment &&
          pos < lineToCheck.length - 1 &&
          lineToCheck[pos] == '/' &&
          lineToCheck[pos + 1] == '*') {
        insideComment = true;
        pos += 2;
      }
      // Check for end of multi-line comment
      else if (insideComment &&
          pos < lineToCheck.length - 1 &&
          lineToCheck[pos] == '*' &&
          lineToCheck[pos + 1] == '/') {
        insideComment = false;
        pos += 2;
      } else {
        pos++;
      }
    }
  }

  return insideComment;
}

// Helper function to check if function is a constructor
bool isConstructor(String functionName, String line) {
  RegExp constructorPattern = RegExp(r'^\s*(?://\s*)?[A-Z]\w*(?:\.\w+)?\s*\(');
  return constructorPattern.hasMatch(line.trim()) &&
      functionName[0].toUpperCase() == functionName[0];
}

// Helper function to clean up commented function names
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

String sanitizeFilePath(String filePath) {
  // Replace slashes, dots, and other invalid characters with underscores
  return filePath.replaceAll(RegExp(r'[\/\\.]'), '_');
}

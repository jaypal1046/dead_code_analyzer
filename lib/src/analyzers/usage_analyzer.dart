import 'dart:io';
import 'dart:math';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

void findUsages({
  required Directory dir,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool showProgress,
  required bool analyzeFunctions,
}) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar =
        ProgressBar(dartFiles.length, description: 'Analyzing code usage');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = path.absolute(file.path);

    try {
      final content = File(filePath).readAsStringSync();
      final lines = content.split('\n');

      // Analyze class usages
      for (final entry in classes.entries) {
        final className = entry.key;
        final classInfo = entry.value;

        final usageRegex = RegExp(
          r'\b' + className + r'\b',
          multiLine: true,
        );
        final matches = usageRegex.allMatches(content);
        int usageCount = matches.length;

        if (filePath == classInfo.definedInFile) {
          final defRegex = RegExp(r'\bclass\s+' + className + r'\b');
          final stateRegex = RegExp(r'\b_' +
              className +
              r'State\b|State\s*<' +
              className +
              r'\s*>|\bcreateState\s*\(\s*\)\s*=>');
          final constructorDefRegex = RegExp(r'(?:const\s+)?\b' +
              className +
              r'\s*\((?:{[\s\S]*?}\s*)?\)[\s\n]*(?:[{;]|}\s*;)');
          final defMatches = defRegex.allMatches(content);
          final stateMatches = stateRegex.allMatches(content);
          final constructorMatches = constructorDefRegex.allMatches(content);

          usageCount -= (defMatches.length +
              stateMatches.length +
              constructorMatches.length);
          usageCount = _filterNonCommentMatches(
              matches, lines, content, filePath,
              className: className);
          classInfo.internalUsageCount = max(0, usageCount);

          if (usageCount > 0 ||
              className == 'Active' ||
              className == 'MyApp' ||
              className == 'MyHomePage' ||
              className == 'StateFullClass') {
            print(
                'Debug: $className in $filePath has $usageCount internal matches (raw matches: ${matches.length}, def: ${defMatches.length}, state: ${stateMatches.length}, constructor: ${constructorMatches.length}):');
            int lineNumber = 0;
            int charCount = 0;
            for (final match in matches) {
              while (lineNumber < lines.length &&
                  match.start >= charCount + lines[lineNumber].length + 1) {
                charCount += lines[lineNumber].length + 1;
                lineNumber++;
              }
              print(
                  '  Usage match at line ${lineNumber + 1}: "${content.substring(max(0, match.start - 20), min(content.length, match.end + 20))}"');
            }
            for (final cMatch in constructorMatches) {
              lineNumber = 0;
              charCount = 0;
              while (lineNumber < lines.length &&
                  cMatch.start >= charCount + lines[lineNumber].length + 1) {
                charCount += lines[lineNumber].length + 1;
                lineNumber++;
              }
              print(
                  '  Constructor match at line ${lineNumber + 1}: "${content.substring(max(0, cMatch.start - 20), min(content.length, cMatch.end + 20))}"');
            }
          }
        } else {
          usageCount = _filterNonCommentMatches(
              matches, lines, content, filePath,
              className: className);
          classInfo.externalUsages[filePath] = max(0, usageCount);

          if (usageCount > 0 &&
              (className == 'MyApp' ||
                  className == 'MyHomePage' ||
                  className == 'StateFullClass' ||
                  className == 'Active')) {
            print(
                'Debug: $className in $filePath has $usageCount external matches:');
            int lineNumber = 0;
            int charCount = 0;
            for (final match in matches) {
              while (lineNumber < lines.length &&
                  match.start >= charCount + lines[lineNumber].length + 1) {
                charCount += lines[lineNumber].length + 1;
                lineNumber++;
              }
              print(
                  '  Match at line ${lineNumber + 1}: "${content.substring(max(0, match.start - 20), min(content.length, match.end + 20))}"');
            }
          }
        }
      }

      // Analyze function usages
      if (analyzeFunctions) {
        for (final entry in functions.entries) {
          final functionName = entry.key;
          final functionInfo = entry.value;

          // Match function calls and callback references
          final usageRegex = RegExp(
            r'\b' + functionName + r'\b(?:\s*\(|(?=\s*(?:[,;}]|\)|=>)))',
            multiLine: true,
          );
          final matches = usageRegex.allMatches(content);
          int usageCount = matches.length;

          // Match function definitions
          final defRegex = RegExp(
            r'(?:void|int|double|String|bool|dynamic|List<\w+>|Map<\w+,\w+>|Future(?:<\w+>)?|[A-Z]\w*)\s+' +
                functionName +
                r'\s*\([^)]*\)\s*(?:async)?\s*[{=]',
          );
          final defMatches = defRegex.allMatches(content);
          usageCount -= defMatches.length;

          if (filePath == functionInfo.definedInFile) {
            // Filter out matches in comments, strings, or definitions
            usageCount = _filterNonCommentMatches(
                matches, lines, content, filePath,
                functionName: functionName);
            functionInfo.internalUsageCount = max(0, usageCount);

            // Enhanced debug logging
            if (functionName == 'myFunction' ||
                functionName == '_incrementCounter') {
              print(
                  'Debug: $functionName in $filePath has $usageCount internal matches (raw matches: ${matches.length}, def matches: ${defMatches.length}):');
              int lineNumber = 0;
              int charCount = 0;
              for (final match in matches) {
                while (lineNumber < lines.length &&
                    match.start >= charCount + lines[lineNumber].length + 1) {
                  charCount += lines[lineNumber].length + 1;
                  lineNumber++;
                }
                print(
                    '  Usage match at line ${lineNumber + 1}: "${content.substring(max(0, match.start - 20), min(content.length, match.end + 20))}"');
              }
              for (final defMatch in defMatches) {
                while (lineNumber < lines.length &&
                    defMatch.start >=
                        charCount + lines[lineNumber].length + 1) {
                  charCount += lines[lineNumber].length + 1;
                  lineNumber++;
                }
                print(
                    '  Def match at line ${lineNumber + 1}: "${content.substring(max(0, defMatch.start - 20), min(content.length, defMatch.end + 20))}"');
              }
            }
          } else {
            usageCount = _filterNonCommentMatches(
                matches, lines, content, filePath,
                functionName: functionName);
            functionInfo.externalUsages[filePath] = max(0, usageCount);
          }
        }
      }
    } catch (e) {
      print('\nWarning: Could not read file $filePath: $e');
    }

    count++;
    if (showProgress) {
      progressBar!.update(count);
    }
  }

  if (showProgress) {
    progressBar!.done();
  }
}

int _filterNonCommentMatches(Iterable<RegExpMatch> matches, List<String> lines,
    String content, String filePath,
    {String? className, String? functionName}) {
  int validCount = 0;
  bool inMultiLineComment = false;
  int charCount = 0;

  for (final match in matches) {
    int lineIndex = -1;
    charCount = 0;
    for (int i = 0; i < lines.length; i++) {
      charCount += lines[i].length + 1;
      if (match.start < charCount) {
        lineIndex = i;
        break;
      }
    }

    if (lineIndex == -1) continue;

    final line = lines[lineIndex];
    final matchStartInLine =
        match.start - (charCount - lines[lineIndex].length - 1);

    if (line.contains('/*') && !line.contains('*/')) {
      inMultiLineComment = true;
    } else if (line.contains('*/')) {
      inMultiLineComment = false;
    }
    if (inMultiLineComment) continue;

    if (line.trim().startsWith('//') || line.trim().startsWith('///')) continue;

    if (_isInsideString(line, matchStartInLine)) continue;

    if (className != null) {
      final defRegex = RegExp(r'\bclass\s+' + className + r'\b');
      final stateRegex = RegExp(r'\b_' +
          className +
          r'State\b|State\s*<' +
          className +
          r'\s*>|\bcreateState\s*\(\s*\)\s*=>');
      final constructorDefRegex = RegExp(r'(?:const\s+)?\b' +
          className +
          r'\s*\((?:{[\s\S]*?}\s*)?\)[\s\n]*(?:[{;]|}\s*;)');
      // Fallback: Exclude lines starting with className followed by '('
      final constructorFallback = RegExp(r'^\s*' + className + r'\s*\(');
      if (defRegex.hasMatch(line) ||
          stateRegex.hasMatch(line) ||
          constructorDefRegex.hasMatch(line) ||
          constructorFallback.hasMatch(line)) {
        continue;
      }
    }

    if (functionName != null) {
      final defRegex = RegExp(
        r'(?:void|int|double|String|bool|dynamic|List<\w+>|Map<\w+,\w+>|Future(?:<\w+>)?|[A-Z]\w*)\s+' +
            functionName +
            r'\s*\([^)]*\)\s*(?:async)?\s*[{=]',
      );
      // Additional check for callback context
      if (defRegex.hasMatch(line)) continue;
      // Ensure match is in a callback-like context (e.g., after ':', '=', or in parameters)
      final context = line.substring(0, matchStartInLine);
      if (!context.contains(RegExp(r'[:=]\s*$')) &&
          !line.contains(RegExp(r'[,;}]'))) {
        continue;
      }
    }

    validCount++;
  }

  return validCount;
}

bool _isInsideString(String line, int matchPosition) {
  bool inSingleQuote = false;
  bool inDoubleQuote = false;
  bool inRawString = false;

  for (int i = 0; i < line.length && i < matchPosition; i++) {
    if (i > 0 && line[i - 1] == '\\') continue;

    if (line[i] == "'" && !inDoubleQuote && !inRawString) {
      inSingleQuote = !inSingleQuote;
    } else if (line[i] == '"' && !inSingleQuote && !inRawString) {
      inDoubleQuote = !inDoubleQuote;
    } else if (i <= line.length - 2 &&
        (line.substring(i, i + 2) == 'r"' ||
            line.substring(i, i + 2) == "r'")) {
      inRawString = !inRawString;
      i++;
    }
  }

  return inSingleQuote || inDoubleQuote || inRawString;
}
// import 'dart:io';
// import 'dart:math';
// import 'package:dead_code_analyzer/src/model/class_info.dart';
// import 'package:dead_code_analyzer/src/model/code_info.dart';
// import 'package:dead_code_analyzer/src/utils/healper.dart';
// import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
// import 'package:path/path.dart' as path;

// void findUsages({
//   required Directory dir,
//   required Map<String, ClassInfo> classes,
//   required Map<String, CodeInfo> functions,
//   required bool showProgress,
//   required bool analyzeFunctions,
// }) {
//   final dartFiles = getDartFiles(dir);

//   ProgressBar? progressBar;
//   if (showProgress) {
//     progressBar =
//         ProgressBar(dartFiles.length, description: 'Analyzing code usage');
//   }

//   var count = 0;
//   for (final file in dartFiles) {
//     final filePath = path.absolute(file.path); // Use absolute path

//     try {
//       final content = File(filePath).readAsStringSync();
//       final lines = content.split('\n');

//       // Analyze class usages
//       for (final entry in classes.entries) {
//         final className = entry.key;
//         final classInfo = entry.value;

//         // Match class usage, allowing constructor calls
//         final usageRegex = RegExp(
//           r'\b' + className + r'\b',
//           multiLine: true,
//         );
//         final matches = usageRegex.allMatches(content);
//         int usageCount = matches.length;

//         if (filePath == classInfo.definedInFile) {
//           // Exclude class definition, state class, and createState
//           final defRegex = RegExp(r'\bclass\s+' + className + r'\b');
//           final stateRegex = RegExp(
//               r'\b_' + className + r'State\b|State\s*<' + className + r'\s*>|\bcreateState\s*\(\s*\)\s*=>');
//           final constructorDefRegex =
//               RegExp(r'(?:const\s+)?\b' + className + r'\s*\([^)]*\)\s*[{;]');
//           final defMatches = defRegex.allMatches(content);
//           final stateMatches = stateRegex.allMatches(content);
//           final constructorMatches = constructorDefRegex.allMatches(content);

//           // Subtract definition-related matches
//           usageCount -= (defMatches.length + stateMatches.length + constructorMatches.length);

//           // Filter out matches in comments, strings, or definitions
//           usageCount = _filterNonCommentMatches(matches, lines, content, filePath, className: className);
//           classInfo.internalUsageCount = max(0, usageCount);

//           // Debug logging for MyApp, MyHomePage, StateFullClass
//           if (usageCount > 0 && (className == 'MyApp' || className == 'MyHomePage' || className == 'StateFullClass')) {
//             print('Debug: $className in $filePath has $usageCount internal matches:');
//             for (final match in matches) {
//               print('  Match at ${match.start}: "${content.substring(max(0, match.start - 20), min(content.length, match.end + 20))}"');
//             }
//           }
//         } else {
//           // Filter external matches
//           usageCount = _filterNonCommentMatches(matches, lines, content, filePath, className: className);
//           classInfo.externalUsages[filePath] = max(0, usageCount);

//           // Debug logging for external matches
//           if (usageCount > 0 && (className == 'MyApp' || className == 'MyHomePage' || className == 'StateFullClass')) {
//             print('Debug: $className in $filePath has $usageCount external matches:');
//             for (final match in matches) {
//               print('  Match at ${match.start}: "${content.substring(max(0, match.start - 20), min(content.length, match.end + 20))}"');
//             }
//           }
//         }
//       }

//       // Analyze function usages (only if enabled)
//       if (analyzeFunctions) {
//         for (final entry in functions.entries) {
//           final functionName = entry.key;
//           final functionInfo = entry.value;

//           // Match function calls only
//           final usageRegex = RegExp(
//             r'\b' + functionName + r'\b\s*\(',
//             multiLine: true,
//           );
//           final matches = usageRegex.allMatches(content);
//           int usageCount = matches.length;

//           if (filePath == functionInfo.definedInFile) {
//             // Match function definition precisely
//             final defRegex = RegExp(
//               r'(?:(?:static\s+)?(?:void|int|double|String|bool|dynamic|List<\w+>|Map<\w+,\w+>|Future(?:<\w+>)?|[A-Z]\w*)\s+|)(?:\w+\.)?' +
//                   functionName +
//                   r'\s*\([^)]*\)\s*(?:async)?\s*(?:{[^{}]*}|=>[^;]*;|\s*;)',
//             );
//             final defMatches = defRegex.allMatches(content);
//             usageCount -= defMatches.length;

//             // Filter out matches in comments, strings, or definitions
//             usageCount = _filterNonCommentMatches(matches, lines, content, filePath, functionName: functionName);
//             functionInfo.internalUsageCount = max(0, usageCount);

//             // Debug logging for myFunction and _incrementCounter
//             if (usageCount > 0 && (functionName == 'myFunction' || functionName == '_incrementCounter')) {
//               print('Debug: $functionName in $filePath has $usageCount internal matches:');
//               for (final match in matches) {
//                 print('  Match at ${match.start}: "${content.substring(max(0, match.start - 20), min(content.length, match.end + 20))}"');
//               }
//             }
//           } else {
//             // Filter external matches
//             usageCount = _filterNonCommentMatches(matches, lines, content, filePath, functionName: functionName);
//             functionInfo.externalUsages[filePath] = max(0, usageCount);
//           }
//         }
//       }
//     } catch (e) {
//       print('\nWarning: Could not read file $filePath: $e');
//     }

//     count++;
//     if (showProgress) {
//       progressBar!.update(count);
//     }
//   }

//   if (showProgress) {
//     progressBar!.done();
//   }
// }

// // Helper function to filter out matches in comments, strings, or definitions
// int _filterNonCommentMatches(
//     Iterable<RegExpMatch> matches, List<String> lines, String content, String filePath,
//     {String? className, String? functionName}) {
//   int validCount = 0;
//   bool inMultiLineComment = false;
//   int charCount = 0;

//   for (final match in matches) {
//     // Find the line containing the match
//     int lineIndex = -1;
//     charCount = 0;
//     for (int i = 0; i < lines.length; i++) {
//       charCount += lines[i].length + 1; // +1 for newline
//       if (match.start < charCount) {
//         lineIndex = i;
//         break;
//       }
//     }

//     if (lineIndex == -1) continue; // Skip if line not found

//     final line = lines[lineIndex];
//     final matchStartInLine = match.start - (charCount - lines[lineIndex].length - 1);

//     // Check for multi-line comment state
//     if (line.contains('/*') && !line.contains('*/')) {
//       inMultiLineComment = true;
//     } else if (line.contains('*/')) {
//       inMultiLineComment = false;
//     }
//     if (inMultiLineComment) continue;

//     // Skip single-line comments or doc comments
//     if (line.trim().startsWith('//') || line.trim().startsWith('///')) continue;

//     // Check if the match is inside a string literal
//     if (_isInsideString(line, matchStartInLine)) continue;

//     // Additional check for class definitions and boilerplate
//     if (className != null) {
//       final defRegex = RegExp(r'\bclass\s+' + className + r'\b');
//       final stateRegex = RegExp(
//           r'\b_' + className + r'State\b|State\s*<' + className + r'\s*>|\bcreateState\s*\(\s*\)\s*=>');
//       final constructorDefRegex =
//           RegExp(r'(?:const\s+)?\b' + className + r'\s*\([^)]*\)\s*[{;]');
//       if (defRegex.hasMatch(line) || stateRegex.hasMatch(line) || constructorDefRegex.hasMatch(line)) {
//         continue;
//       }
//     }

//     // Additional check for function definitions
//     if (functionName != null) {
//       final defRegex = RegExp(
//         r'(?:(?:static\s+)?(?:void|int|double|String|bool|dynamic|List<\w+>|Map<\w+,\w+>|Future(?:<\w+>)?|[A-Z]\w*)\s+|)(?:\w+\.)?' +
//             functionName +
//             r'\s*\([^)]*\)\s*(?:async)?\s*(?:{[^{}]*}|=>[^;]*;|\s*;)',
//       );
//       if (defRegex.hasMatch(line)) continue;
//     }

//     validCount++;
//   }

//   return validCount;
// }

// // Helper function to check if a match is inside a string literal
// bool _isInsideString(String line, int matchPosition) {
//   bool inSingleQuote = false;
//   bool inDoubleQuote = false;
//   bool inRawString = false;

//   for (int i = 0; i < line.length && i < matchPosition; i++) {
//     if (i > 0 && line[i - 1] == '\\') continue; // Skip escaped characters

//     if (line[i] == "'" && !inDoubleQuote && !inRawString) {
//       inSingleQuote = !inSingleQuote;
//     } else if (line[i] == '"' && !inSingleQuote && !inRawString) {
//       inDoubleQuote = !inDoubleQuote;
//     } else if (i <= line.length - 2 && (line.substring(i, i + 2) == 'r"' || line.substring(i, i + 2) == "r'")) {
//       inRawString = !inRawString;
//       i++; // Skip the next character
//     }
//   }

//   return inSingleQuote || inDoubleQuote || inRawString;
// }

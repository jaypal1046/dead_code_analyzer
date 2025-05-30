import 'dart:io';
import 'package:dead_code_analyzer/src/collecter/class_collector.dart';
import 'package:dead_code_analyzer/src/collecter/function_collector.dart';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

void collectCodeEntities(
    {required Directory dir,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool showProgress,
    required bool analyzeFunctions}) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar = ProgressBar(dartFiles.length,
        description: 'Scanning files for code entities');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = path.absolute(file.path);

    try {
      final content = File(filePath).readAsStringSync();
      final lines = content.split('\n');

      // Regex patterns
      final classRegex = RegExp(r'class\s+(\w+)[\s{<]');
      final pragmaRegex =
          RegExp(r'''^\s*@pragma\s*\(\s*[\'"]vm:entry-point[\'"]\s*\)\s*$''');

      // Track class context
      String currentClassName = '';
      int classDepth = 0;
      List<String> classStack = []; // Stack to handle nested classes

      int lineIndex = 0;
      bool insideStateClass = false;

      for (final line in lines) {
        final trimmedLine = line.trim();

        // Count braces to track class boundaries
        final openBraces = '{'.allMatches(trimmedLine).length;
        final closeBraces = '}'.allMatches(trimmedLine).length;

        // Check for class definition
        final classMatch = classRegex.firstMatch(trimmedLine);
        if (classMatch != null) {
          final className = classMatch.group(1)!;

          // Update class context
          currentClassName = className;
          classStack.add(className);
          classDepth = 1; // Reset depth for new class

          // Track if inside a State class
          insideStateClass = className.endsWith('State') &&
              (classes.containsKey(
                      className.substring(0, className.length - 5)) ||
                  className.startsWith('_'));

          // Process class
          classCollector(classMatch, lineIndex, pragmaRegex, lines, classes,
              filePath, insideStateClass);
        }

        // Update class depth based on braces
        if (currentClassName.isNotEmpty) {
          classDepth += openBraces - closeBraces;

          // If we've closed all braces for this class, we're outside it
          if (classDepth <= 0) {
            if (classStack.isNotEmpty) {
              classStack.removeLast();
            }

            // Set current class to parent class if nested, or empty if top-level
            if (classStack.isNotEmpty) {
              currentClassName = classStack.last;
              classDepth = 1; // We're still inside the parent class
            } else {
              currentClassName = '';
              classDepth = 0;
            }

            // Update insideStateClass based on new current class
            if (currentClassName.isNotEmpty) {
              insideStateClass = currentClassName.endsWith('State') &&
                  (classes.containsKey(currentClassName.substring(
                          0, currentClassName.length - 5)) ||
                      currentClassName.startsWith('_'));
            } else {
              insideStateClass = false;
            }
          }
        }

        // Function detection (only if analyzeFunctions is true)
        if (analyzeFunctions) {
          functionCollecter(
            analyzeFunctions: analyzeFunctions,
            line: trimmedLine,
            insideStateClass: insideStateClass,
            prebuiltFlutterMethods: prebuiltFlutterMethods,
            lineIndex: lineIndex,
            pragmaRegex: pragmaRegex,
            lines: lines,
            functions: functions,
            filePath: filePath,
            currentClassName: currentClassName, // Pass current class name
          );
        }

        lineIndex++;
      }
    } catch (e) {
      print(
          '\nWarning: Could not read file $filePath: $e. Check file permissions or ensure the file exists.');
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

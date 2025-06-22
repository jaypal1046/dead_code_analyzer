import 'dart:io';
import 'package:dead_code_analyzer/src/collectors/class_collector.dart';
import 'package:dead_code_analyzer/src/collectors/function_collector.dart';
import 'package:dead_code_analyzer/src/models/class_info.dart';
import 'package:dead_code_analyzer/src/models/code_info.dart';
import 'package:dead_code_analyzer/src/utils/helper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

class CodeAnalyzer {
  static void collectCodeEntities(
      {required Directory dir,
      required Map<String, ClassInfo> classes,
      required Map<String, CodeInfo> functions,
      required bool showProgress,
      required bool analyzeFunctions}) {
    final dartFiles = Healper.getDartFiles(dir);

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

        // Enhanced regex patterns to match class, enum, extension, and mixin

        final pragmaRegex = RegExp(
            r'''^\s*@pragma\s*\(\s*[\'"]((?:vm:entry-point)|(?:vm:external-name)|(?:vm:prefer-inline)|(?:vm:exact-result-type)|(?:vm:never-inline)|(?:vm:non-nullable-by-default)|(?:flutter:keep-to-string)|(?:flutter:keep-to-string-in-subtypes))[\'"]\s*(?:,\s*[^)]+)?\s*\)\s*$''',
            multiLine: false);

        // Individual patterns for more specific handling if needed
        final specificPatterns = {
          'class': RegExp(
              r'class\s+(\w+)(?:<[^>]*>)?(?:\s+extends\s+\w+(?:<[^>]*>)?)?(?:\s+with\s+[\w\s,<>]+)?(?:\s+implements\s+[\w\s,<>]+)?\s*\{'),
          'enum': RegExp(r'enum\s+(\w+)(?:\s+with\s+[\w\s,<>]+)?\s*\{'),
          'extension':
              RegExp(r'extension\s+(\w+)(?:<[^>]*>)?\s+on\s+[\w<>\s,]+\s*\{'),
          'mixin':
              RegExp(r'mixin\s+(\w+)(?:<[^>]*>)?(?:\s+on\s+[\w\s,<>]+)?\s*\{'),
        };

        // Track class context with type information
        String currentClassName = '';
        String currentType = '';
        int classDepth = 0;
        List<Map<String, String>> classStack =
            []; // Stack to handle nested classes with type info

        int lineIndex = 0;
        bool insideStateClass = false;

        for (final line in lines) {
          final trimmedLine = line.trim();

          // Count braces to track class boundaries
          final openBraces = '{'.allMatches(trimmedLine).length;
          final closeBraces = '}'.allMatches(trimmedLine).length;

          // Check for class/enum/extension/mixin definition using specific patterns
          String? matchedType;
          RegExpMatch? match;

          for (final entry in specificPatterns.entries) {
            match = entry.value.firstMatch(trimmedLine);
            if (match != null) {
              matchedType = entry.key;
              break;
            }
          }

          if (match != null && matchedType != null) {
            final className = match.group(1)!;

            // Update class context
            currentClassName = className;
            currentType = matchedType;
            classStack.add({'name': className, 'type': matchedType});
            classDepth = 1; // Reset depth for new class

            // Track if inside a State class (only applies to classes, not enums/extensions/mixins)
            insideStateClass = matchedType == 'class' &&
                className.endsWith('State') &&
                (classes.containsKey(
                        className.substring(0, className.length - 5)) ||
                    className.startsWith('_'));

            // Process class/enum/extension/mixin
            ClassCollector.classCollector(match, lineIndex, pragmaRegex, lines,
                classes, filePath, insideStateClass);
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
                final parent = classStack.last;
                currentClassName = parent['name']!;
                currentType = parent['type']!;
                classDepth = 1; // We're still inside the parent class
              } else {
                currentClassName = '';
                currentType = '';
                classDepth = 0;
              }

              // Update insideStateClass based on new current class
              if (currentClassName.isNotEmpty && currentType == 'class') {
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
            FunctionCollector.functionCollecter(
              analyzeFunctions: analyzeFunctions,
              line: trimmedLine,
              insideStateClass: insideStateClass,
              prebuiltFlutterMethods: Healper.prebuiltFlutterMethods,
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
}

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
    final filePath = path.absolute(file.path); // Use absolute path

    try {
      final content = File(filePath).readAsStringSync();
      final lines = content.split('\n');

      // Class definitions
      final classRegex = RegExp(r'class\s+(\w+)[\s{<]');
      final pragmaRegex =
          RegExp(r'''^\s*@pragma\s*\(\s*[\'"]vm:entry-point[\'"]\s*\)\s*$''');

      int lineIndex = 0;
      bool insideStateClass = false;
      for (final line in lines) {
        // Track if inside a State class
        final classMatch = classRegex.firstMatch(line);
        if (classMatch != null) {
          final className = classMatch.group(1)!;
          insideStateClass = className.endsWith('State') &&
              (classes.containsKey(
                      className.substring(0, className.length - 5)) ||
                  className.startsWith('_'));
        } else if (insideStateClass && line.trim() == '}') {
          insideStateClass = false;
        }

        // Class detection
        classCollector(classMatch, lineIndex, pragmaRegex, lines, classes,
            filePath, insideStateClass);

        // Function detection (only if analyzeFunctions is true)
        functionCollecter(
            analyzeFunctions: analyzeFunctions,
            line: line,
            insideStateClass: insideStateClass,
            prebuiltFlutterMethods: prebuiltFlutterMethods,
            lineIndex: lineIndex,
            pragmaRegex: pragmaRegex,
            lines: lines,
            functions: functions,
            filePath: filePath);
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

import 'dart:io';
import 'package:code_clean/src/model/code_info.dart';
import '../utils/progress_bar.dart';
import 'package:path/path.dart' as path;

void collectCodeEntities(Directory dir, Map<String, CodeInfo> classes,
    Map<String, CodeInfo> functions, bool showProgress, bool analyzeFunctions) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar = ProgressBar(dartFiles.length,
        description: 'Scanning files for code entities');
  }

  // List of prebuilt Flutter State methods
  final prebuiltFlutterMethods = {
    'build',
    'initState',
    'dispose',
    'didChangeDependencies',
    'didUpdateWidget',
    'reassemble',
    'setState',
    'deactivate'
  };

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
          classes[className] = CodeInfo(filePath,
              isEntryPoint: isEntryPoint,
              type: insideStateClass ? 'state_class' : 'class');
        }

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
            bool isPrebuiltFlutter = insideStateClass &&
                prebuiltFlutterMethods.contains(functionName);
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

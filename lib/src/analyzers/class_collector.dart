// class_collector.dart
import 'dart:io';
import 'package:code_clean/src/model/class_info.dart';
import '../utils/progress_bar.dart';

void collectClassNames(
    Directory dir, Map<String, ClassInfo> classes, bool showProgress) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar = ProgressBar(dartFiles.length,
        description: 'Scanning files for classes');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = file.path;

    try {
      final content = File(filePath).readAsStringSync();
      final lines = content.split('\n');

      // Find class definitions with optional @pragma('vm:entry-point')
      final classRegex = RegExp(r'class\s+(\w+)[\s{<]');
      final pragmaRegex =
          RegExp(r'''^\s*@pragma\s*\(\s*[\'"]vm:entry-point[\'"]\s*\)\s*$''');

      int lineIndex = 0;
      for (final line in lines) {
        final classMatch = classRegex.firstMatch(line);
        if (classMatch != null) {
          final className = classMatch.group(1)!;
          // Check if the previous line (or lines) contains @pragma('vm:entry-point')
          bool isEntryPoint = false;
          if (lineIndex > 0) {
            // Check the immediately preceding line
            if (pragmaRegex.hasMatch(lines[lineIndex - 1])) {
              isEntryPoint = true;
            } else {
              // Check up to 2 lines before (to account for comments or whitespace)
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
          classes[className] = ClassInfo(filePath, isEntryPoint: isEntryPoint);
        }
        lineIndex++;
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

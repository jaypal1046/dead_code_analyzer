import 'dart:io';

import 'package:code_clean/src/model/class_info.dart';
import '../utils/progress_bar.dart';

/// Collects class names and their definition locations from all Dart files in a directory
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

      // Find class definitions using regex
      final classRegex = RegExp(r'class\s+(\w+)[\s{<]');
      final matches = classRegex.allMatches(content);

      for (final match in matches) {
        final className = match.group(1)!;
        classes[className] = ClassInfo(filePath);
      }
    } catch (e) {
      // Skip files that can't be read
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
import 'dart:io';
import 'dart:math';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import '../utils/progress_bar.dart';
import 'package:path/path.dart' as path;

void findUsages(Directory dir, Map<String, CodeInfo> classes,
    Map<String, CodeInfo> functions, bool showProgress, bool analyzeFunctions) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar =
        ProgressBar(dartFiles.length, description: 'Analyzing code usage');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = path.absolute(file.path); // Use absolute path

    try {
      final content = File(filePath).readAsStringSync();

      // Analyze class usages
      for (final entry in classes.entries) {
        final className = entry.key;
        final classInfo = entry.value;

        final usageRegex = RegExp('\\b$className\\b');
        final matches = usageRegex.allMatches(content);
        int usageCount = matches.length;

        if (filePath == classInfo.definedInFile) {
          final defRegex = RegExp('\\bclass\\s+$className\\b');
          final defMatches = defRegex.allMatches(content);
          final constructorRegex =
              RegExp('\\b$className\\s*\\([^)]*\\)\\s*[:{]');
          final constructorMatches = constructorRegex.allMatches(content);
          usageCount -= (defMatches.length + constructorMatches.length);
          classInfo.internalUsageCount = max(0, usageCount);
        } else if (usageCount > 0) {
          classInfo.externalUsages[filePath] = usageCount;
        }
      }

      // Analyze function usages (only if enabled)
      if (analyzeFunctions) {
        for (final entry in functions.entries) {
          final functionName = entry.key;
          final functionInfo = entry.value;

          final usageRegex = RegExp('\\b$functionName\\b');
          final matches = usageRegex.allMatches(content);
          int usageCount = matches.length;

          if (filePath == functionInfo.definedInFile) {
            final defRegex = RegExp(
                r'(?:(?:static\s+)?(?:void|int|double|String|bool|dynamic|List<\w+>|Map<\w+,\w+>|Future(?:<\w+>)?)\s+|)(?:\w+\.)?' +
                    functionName +
                    r'\s*\([^)]*\)\s*(?:(?:async)?\s*({(?:\s*//.*)*\s*}|;))');
            final defMatches = defRegex.allMatches(content);
            usageCount -= defMatches.length;
            functionInfo.internalUsageCount = max(0, usageCount);
          } else if (usageCount > 0) {
            functionInfo.externalUsages[filePath] = usageCount;
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

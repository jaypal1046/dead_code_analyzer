import 'dart:io';
import 'dart:math';

import 'package:code_clean/src/model/class_info.dart';

import '../utils/progress_bar.dart';
import 'class_collector.dart';

/// Finds and counts usages of each class in all Dart files
void findUsages(
    Directory dir, Map<String, ClassInfo> classes, bool showProgress) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar =
        ProgressBar(dartFiles.length, description: 'Analyzing class usage');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = file.path;

    try {
      final content = File(filePath).readAsStringSync();

      for (final entry in classes.entries) {
        final className = entry.key;
        final classInfo = entry.value;

        // More accurate usage detection with word boundaries
        final usageRegex = RegExp('\\b$className\\b');
        final matches = usageRegex.allMatches(content);
        
        // Count occurrences but exclude the definition line for the defining file
        int usageCount = matches.length;
        
        // If this is the defining file, subtract occurrences that are part of the class definition
        if (filePath == classInfo.definedInFile) {
          // Look for class definitions (may have multiple occurrences in inheritance, interfaces, etc.)
          final defRegex = RegExp('\\bclass\\s+$className\\b');
          final defMatches = defRegex.allMatches(content);
          
          // Also look for constructor definitions which repeat the class name
          final constructorRegex = RegExp('\\b$className\\s*\\([^)]*\\)\\s*[:{]');
          final constructorMatches = constructorRegex.allMatches(content);
          
          // Remove these from the count as they're not "usages"
          usageCount -= (defMatches.length + constructorMatches.length);
          
          // Store the actual usage count (may be negative if there's a bug, so ensure it's at least 0)
          classInfo.internalUsageCount = max(0, usageCount);
        } else if (usageCount > 0) {
          // External file with usages - store the usage count
          classInfo.externalUsages[filePath] = usageCount;
        }
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
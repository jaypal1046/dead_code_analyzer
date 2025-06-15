import 'dart:io';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/usage/class_uages.dart';
import 'package:dead_code_analyzer/src/usage/function_usages.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

class UsageAnalyzer {
  static void findUsages({
    required Directory dir,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool showProgress,
    required bool analyzeFunctions,
  }) {
    final dartFiles = Healper.getDartFiles(dir);

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

        // Analyze class usages
        ClassUages.analyzeClassUsages(content, filePath, classes);

        // Analyze function usages
        if (analyzeFunctions) {
          FunctionUsage.analyzeFunctionUsages(content, filePath, functions);
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
}

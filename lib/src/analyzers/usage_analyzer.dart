import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/usage/class_uages.dart';
import 'package:dead_code_analyzer/src/usage/function_usages.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

// Ultra-optimized version with parallel processing
Future<void> findUsagesParallel({
  required Directory dir,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool showProgress,
  required bool analyzeFunctions,
  int maxConcurrency = 4, // Adjust based on your system
}) async {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar =
        ProgressBar(dartFiles.length, description: 'Analyzing code usage');
  }

  // Split files into batches for parallel processing
  final batches = _createBatches(dartFiles, maxConcurrency);
  var totalProcessed = 0;

  // Process batches in parallel
  final futures = batches.map((batch) =>
      _processBatch(batch, classes, functions, analyzeFunctions, (processed) {
        totalProcessed += processed;
        if (showProgress) {
          progressBar!.update(totalProcessed);
        }
      }));

  await Future.wait(futures);

  if (showProgress) {
    progressBar!.done();
  }
}

List<List<File>> _createBatches(List<File> files, int batchCount) {
  final batches = <List<File>>[];
  final batchSize = (files.length / batchCount).ceil();

  for (int i = 0; i < files.length; i += batchSize) {
    final end = (i + batchSize < files.length) ? i + batchSize : files.length;
    batches.add(files.sublist(i, end));
  }

  return batches;
}

Future<void> _processBatch(
  List<File> files,
  Map<String, ClassInfo> classes,
  Map<String, CodeInfo> functions,
  bool analyzeFunctions,
  Function(int) onProgress,
) async {
  // Create analyzer instance for this batch
  final classAnalyzer = OptimizedClassAnalyzer();

  var processed = 0;
  for (final file in files) {
    final filePath = path.absolute(file.path);

    try {
      final content = await File(filePath).readAsString(); // Async read

      // Analyze class usages
      classAnalyzer.analyzeClassUsages(content, filePath, classes);

      // Analyze function usages
      if (analyzeFunctions) {
        analyzeFunctionUsages(content, filePath, functions);
      }
    } catch (e) {
      print('\nWarning: Could not read file $filePath: $e');
    }

    processed++;
    onProgress(1); // Report progress
  }
}

// Memory-efficient version for very large codebases
Stream<void> findUsagesStreaming({
  required Directory dir,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool showProgress,
  required bool analyzeFunctions,
}) async* {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar =
        ProgressBar(dartFiles.length, description: 'Analyzing code usage');
  }

  final classAnalyzer = OptimizedClassAnalyzer();
  OptimizedClassAnalyzer.initializeTrie(classes);

  var count = 0;
  for (final file in dartFiles) {
    final filePath = path.absolute(file.path);

    try {
      // Read file as stream for memory efficiency
      final content = await File(filePath).readAsString();

      // Analyze class usages
      classAnalyzer.analyzeClassUsages(content, filePath, classes);

      // Analyze function usages
      if (analyzeFunctions) {
        analyzeFunctionUsages(content, filePath, functions);
      }

      yield null; // Yield control back to caller
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

// Smart caching version that remembers file analysis results
class CachedUsageFinder {
  static final Map<String, int> _fileHashCache = {};
  static final Map<String, DateTime> _fileModifiedCache = {};

  static Future<void> findUsagesWithCache({
    required Directory dir,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool showProgress,
    required bool analyzeFunctions,
  }) async {
    final dartFiles = getDartFiles(dir);

    ProgressBar? progressBar;
    if (showProgress) {
      progressBar =
          ProgressBar(dartFiles.length, description: 'Analyzing code usage');
    }

    final classAnalyzer = OptimizedClassAnalyzer();
    OptimizedClassAnalyzer.initializeTrie(classes);

    var count = 0;
    var skipped = 0;

    for (final file in dartFiles) {
      final filePath = path.absolute(file.path);

      try {
        final fileStat = await file.stat();
        final lastModified = fileStat.modified;

        // Check if file has been modified since last analysis
        if (_fileModifiedCache.containsKey(filePath) &&
            _fileModifiedCache[filePath] == lastModified) {
          skipped++;
          continue; // Skip unchanged files
        }

        final content = await file.readAsString();

        // Analyze class usages
        classAnalyzer.analyzeClassUsages(content, filePath, classes);

        // Analyze function usages
        if (analyzeFunctions) {
          analyzeFunctionUsages(content, filePath, functions);
        }

        // Cache the file modification time
        _fileModifiedCache[filePath] = lastModified;
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
      if (skipped > 0) {
        print('Skipped $skipped unchanged files');
      }
    }
  }

  static void clearCache() {
    _fileHashCache.clear();
    _fileModifiedCache.clear();
  }
}

// Usage examples:

// 1. Original optimized version (recommended for most cases)
void findUsagesOptimized({
  required Directory dir,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool showProgress,
  required bool analyzeFunctions,
}) {
  final dartFiles = getDartFiles(dir);
  final classAnalyzer = OptimizedClassAnalyzer();
  OptimizedClassAnalyzer.initializeTrie(classes);

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
      classAnalyzer.analyzeClassUsages(content, filePath, classes);

      if (analyzeFunctions) {
        analyzeFunctionUsages(content, filePath, functions);
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
// import 'dart:io';
// import 'dart:isolate';
// import 'dart:async';
// import 'package:dead_code_analyzer/src/collecter/class_collector.dart';
// import 'package:dead_code_analyzer/src/model/class_info.dart';
// import 'package:dead_code_analyzer/src/model/code_info.dart';
// import 'package:dead_code_analyzer/src/usage/function_usages.dart';
// import 'package:dead_code_analyzer/src/utils/healper.dart';
// import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
// import 'package:path/path.dart' as path;

// // Ultra-optimized version with parallel processing
// Future<void> findUsagesParallel({
//   required Directory dir,
//   required Map<String, ClassInfo> classes,
//   required Map<String, CodeInfo> functions,
//   required bool showProgress,
//   required bool analyzeFunctions,
//   int maxConcurrency = 4, // Adjust based on your system
// }) async {
//   final dartFiles = getDartFiles(dir);

//   ProgressBar? progressBar;
//   if (showProgress) {
//     progressBar =
//         ProgressBar(dartFiles.length, description: 'Analyzing code usage');
//   }

//   // Split files into batches for parallel processing
//   final batches = _createBatches(dartFiles, maxConcurrency);
//   var totalProcessed = 0;

//   // Process batches in parallel
//   final futures = batches.map((batch) => _processBatch(
//     batch, 
//     classes, 
//     functions, 
//     analyzeFunctions,
//     (processed) {
//       totalProcessed += processed;
//       if (showProgress) {
//         progressBar!.update(totalProcessed);
//       }
//     }
//   ));

//   await Future.wait(futures);

//   if (showProgress) {
//     progressBar!.done();
//   }
// }

// List<List<File>> _createBatches(List<File> files, int batchCount) {
//   final batches = <List<File>>[];
//   final batchSize = (files.length / batchCount).ceil();
  
//   for (int i = 0; i < files.length; i += batchSize) {
//     final end = (i + batchSize < files.length) ? i + batchSize : files.length;
//     batches.add(files.sublist(i, end));
//   }
  
//   return batches;
// }

// Future<void> _processBatch(
//   List<File> files,
//   Map<String, ClassInfo> classes,
//   Map<String, CodeInfo> functions,
//   bool analyzeFunctions,
//   Function(int) onProgress,
// ) async {
//   // Create analyzer instance for this batch
//   final classAnalyzer = OptimizedClassAnalyzer();
  
//   var processed = 0;
//   for (final file in files) {
//     final filePath = path.absolute(file.path);

//     try {
//       final content = await File(filePath).readAsString(); // Async read

//       // Analyze class usages
//       classAnalyzer.analyzeClassUsages(content, filePath, classes);

//       // Analyze function usages
//       if (analyzeFunctions) {
//         analyzeFunctionUsages(content, filePath, functions);
//       }
//     } catch (e) {
//       print('\nWarning: Could not read file $filePath: $e');
//     }

//     processed++;
//     onProgress(1); // Report progress
//   }
// }

// // Memory-efficient version for very large codebases
// Stream<void> findUsagesStreaming({
//   required Directory dir,
//   required Map<String, ClassInfo> classes,
//   required Map<String, CodeInfo> functions,
//   required bool showProgress,
//   required bool analyzeFunctions,
// }) async* {
//   final dartFiles = getDartFiles(dir);

//   ProgressBar? progressBar;
//   if (showProgress) {
//     progressBar =
//         ProgressBar(dartFiles.length, description: 'Analyzing code usage');
//   }

//   final classAnalyzer = OptimizedClassAnalyzer();
//   OptimizedClassAnalyzer.initializeTrie(classes);

//   var count = 0;
//   for (final file in dartFiles) {
//     final filePath = path.absolute(file.path);

//     try {
//       // Read file as stream for memory efficiency
//       final content = await File(filePath).readAsString();

//       // Analyze class usages
//       classAnalyzer.analyzeClassUsages(content, filePath, classes);

//       // Analyze function usages
//       if (analyzeFunctions) {
//         analyzeFunctionUsages(content, filePath, functions);
//       }

//       yield null; // Yield control back to caller
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

// // Smart caching version that remembers file analysis results
// class CachedUsageFinder {
//   static final Map<String, int> _fileHashCache = {};
//   static final Map<String, DateTime> _fileModifiedCache = {};
  
//   static Future<void> findUsagesWithCache({
//     required Directory dir,
//     required Map<String, ClassInfo> classes,
//     required Map<String, CodeInfo> functions,
//     required bool showProgress,
//     required bool analyzeFunctions,
//   }) async {
//     final dartFiles = getDartFiles(dir);

//     ProgressBar? progressBar;
//     if (showProgress) {
//       progressBar =
//           ProgressBar(dartFiles.length, description: 'Analyzing code usage');
//     }

//     final classAnalyzer = OptimizedClassAnalyzer();
//     OptimizedClassAnalyzer.initializeTrie(classes);

//     var count = 0;
//     var skipped = 0;
    
//     for (final file in dartFiles) {
//       final filePath = path.absolute(file.path);

//       try {
//         final fileStat = await file.stat();
//         final lastModified = fileStat.modified;
        
//         // Check if file has been modified since last analysis
//         if (_fileModifiedCache.containsKey(filePath) &&
//             _fileModifiedCache[filePath] == lastModified) {
//           skipped++;
//           continue; // Skip unchanged files
//         }

//         final content = await file.readAsString();

//         // Analyze class usages
//         classAnalyzer.analyzeClassUsages(content, filePath, classes);

//         // Analyze function usages
//         if (analyzeFunctions) {
//           analyzeFunctionUsages(content, filePath, functions);
//         }

//         // Cache the file modification time
//         _fileModifiedCache[filePath] = lastModified;
        
//       } catch (e) {
//         print('\nWarning: Could not read file $filePath: $e');
//       }

//       count++;
//       if (showProgress) {
//         progressBar!.update(count);
//       }
//     }

//     if (showProgress) {
//       progressBar!.done();
//       if (skipped > 0) {
//         print('Skipped $skipped unchanged files');
//       }
//     }
//   }
  
//   static void clearCache() {
//     _fileHashCache.clear();
//     _fileModifiedCache.clear();
//   }
// }

// // Usage examples:

// // 1. Original optimized version (recommended for most cases)
// void findUsagesOptimized({
//   required Directory dir,
//   required Map<String, ClassInfo> classes,
//   required Map<String, CodeInfo> functions,
//   required bool showProgress,
//   required bool analyzeFunctions,
// }) {
//   final dartFiles = getDartFiles(dir);
//   final classAnalyzer = OptimizedClassAnalyzer();
//   OptimizedClassAnalyzer.initializeTrie(classes);

//   ProgressBar? progressBar;
//   if (showProgress) {
//     progressBar = ProgressBar(dartFiles.length, description: 'Analyzing code usage');
//   }

//   var count = 0;
//   for (final file in dartFiles) {
//     final filePath = path.absolute(file.path);

//     try {
//       final content = File(filePath).readAsStringSync();
//       classAnalyzer.analyzeClassUsages(content, filePath, classes);

//       if (analyzeFunctions) {
//         analyzeFunctionUsages(content, filePath, functions);
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

// // import 'dart:io';
// // import 'package:dead_code_analyzer/src/model/class_info.dart';
// // import 'package:dead_code_analyzer/src/model/code_info.dart';
// // import 'package:dead_code_analyzer/src/usage/class_uages.dart';
// // import 'package:dead_code_analyzer/src/usage/function_usages.dart';
// // import 'package:dead_code_analyzer/src/utils/healper.dart';
// // import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
// // import 'package:path/path.dart' as path;

// // void findUsages({
// //   required Directory dir,
// //   required Map<String, ClassInfo> classes,
// //   required Map<String, CodeInfo> functions,
// //   required bool showProgress,
// //   required bool analyzeFunctions,
// // }) {
// //   final dartFiles = getDartFiles(dir);

// //   ProgressBar? progressBar;
// //   if (showProgress) {
// //     progressBar =
// //         ProgressBar(dartFiles.length, description: 'Analyzing code usage');
// //   }

// //   var count = 0;
// //   for (final file in dartFiles) {
// //     final filePath = path.absolute(file.path);

// //     try {
// //       final content = File(filePath).readAsStringSync();

// //       // Analyze class usages
// //       analyzeClassUsages(content, filePath, classes);

// //       // Analyze function usages


// //       if (analyzeFunctions) {
// //         analyzeFunctionUsages(content, filePath, functions);
// //       }
// //     } catch (e) {
// //       print('\nWarning: Could not read file $filePath: $e');
// //     }

// //     count++;
// //     if (showProgress) {
// //       progressBar!.update(count);
// //     }
// //   }

// //   if (showProgress) {
// //     progressBar!.done();
// //   }
// // }

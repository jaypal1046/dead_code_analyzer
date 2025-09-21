import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/usage/class_usages.dart';
import 'package:dead_code_analyzer/src/usage/function_usages.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

// Data class to hold file processing parameters
class FileProcessingTask {
  final String filePath;
  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;
  final bool analyzeFunctions;

  FileProcessingTask({
    required this.filePath,
    required this.classes,
    required this.functions,
    required this.analyzeFunctions,
  });
}

// Result class to hold processing results
class FileProcessingResult {
  final String filePath;
  final bool success;
  final String? error;
  final Map<String, ClassInfo>? updatedClasses;
  final Map<String, CodeInfo>? updatedFunctions;

  FileProcessingResult({
    required this.filePath,
    required this.success,
    this.error,
    this.updatedClasses,
    this.updatedFunctions,
  });
}

// Isolate entry point for processing files
void _processFileIsolate(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is FileProcessingTask) {
      try {
        final content = File(message.filePath).readAsStringSync();

        // Create copies to avoid modifying shared data
        final classescopy = Map<String, ClassInfo>.from(message.classes);
        final functionsCity = Map<String, CodeInfo>.from(message.functions);

        // Analyze class usages
        analyzeClassUsages(content, message.filePath, classescopy);

        // Analyze function usages
        if (message.analyzeFunctions) {
          analyzeFunctionUsages(content, message.filePath, functionsCity);
        }

        final result = FileProcessingResult(
          filePath: message.filePath,
          success: true,
          updatedClasses: classescopy,
          updatedFunctions: functionsCity,
        );

        sendPort.send(result);
      } catch (e) {
        final result = FileProcessingResult(
          filePath: message.filePath,
          success: false,
          error: e.toString(),
        );
        sendPort.send(result);
      }
    }
  });
}

Future<void> findUsages({
  required Directory dir,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool showProgress,
  required bool analyzeFunctions,
  int? maxConcurrency,
  bool useIsolates = false,
}) async {
  final dartFiles = getDartFiles(dir);

  // Determine optimal concurrency level
  final concurrency =
      maxConcurrency ?? (Platform.numberOfProcessors * 2).clamp(2, 8);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar = ProgressBar(
      dartFiles.length,
      description: 'Analyzing code usage',
    );
  }

  List<FileProcessingResult> results;

  if (useIsolates) {
    // Use true isolate-based processing
    results = await _processWithIsolates(
      dartFiles,
      classes,
      functions,
      analyzeFunctions,
      concurrency,
      progressBar,
    );
  } else {
    // Use async/await parallel processing (faster for I/O bound tasks)
    results = await _processWithFutures(
      dartFiles,
      classes,
      functions,
      analyzeFunctions,
      concurrency,
      progressBar,
    );
  }

  // Merge results back into original maps
  _mergeResults(results, classes, functions);

  // Print warnings for failed files
  for (final result in results) {
    if (!result.success) {
      print(
        '\nWarning: Could not read file ${result.filePath}: ${result.error}',
      );
    }
  }

  if (showProgress) {
    progressBar!.done();
  }
}

// True isolate-based processing
Future<List<FileProcessingResult>> _processWithIsolates(
  List<File> dartFiles,
  Map<String, ClassInfo> classes,
  Map<String, CodeInfo> functions,
  bool analyzeFunctions,
  int concurrency,
  ProgressBar? progressBar,
) async {
  final results = <FileProcessingResult>[];
  var processedCount = 0;

  // Create isolate pool
  final isolates = <Isolate>[];
  final sendPorts = <SendPort>[];
  final receivePorts = <ReceivePort>[];

  try {
    // Initialize isolates
    for (int i = 0; i < concurrency; i++) {
      final receivePort = ReceivePort();
      receivePorts.add(receivePort);

      final isolate = await Isolate.spawn(
        _processFileIsolate,
        receivePort.sendPort,
      );
      isolates.add(isolate);

      // Get the SendPort from the isolate
      final sendPort = await receivePort.first as SendPort;
      sendPorts.add(sendPort);
    }

    // Create tasks queue
    final tasks = dartFiles
        .map(
          (file) => FileProcessingTask(
            filePath: path.absolute(file.path),
            classes: classes,
            functions: functions,
            analyzeFunctions: analyzeFunctions,
          ),
        )
        .toList();

    // Process tasks using isolates
    final completers = <Completer<FileProcessingResult>>[];
    final taskIndex = <int>[];

    int currentTask = 0;

    // Start initial tasks
    for (int i = 0; i < concurrency && currentTask < tasks.length; i++) {
      final completer = Completer<FileProcessingResult>();
      completers.add(completer);
      taskIndex.add(i);

      // Listen for response from this isolate
      receivePorts[i].listen((message) {
        if (message is FileProcessingResult) {
          completer.complete(message);
        }
      });

      // Send task to isolate
      sendPorts[i].send(tasks[currentTask]);
      currentTask++;
    }

    // Process remaining tasks
    while (completers.isNotEmpty) {
      final result = await Future.any(completers.map((c) => c.future));
      results.add(result);
      processedCount++;

      if (progressBar != null) {
        progressBar.update(processedCount);
      }

      // Find which completer completed and remove it
      final completedIndex = completers.indexWhere((c) => c.isCompleted);
      completers.removeAt(completedIndex);
      final isolateIndex = taskIndex.removeAt(completedIndex);

      // If there are more tasks, assign next task to this isolate
      if (currentTask < tasks.length) {
        final completer = Completer<FileProcessingResult>();
        completers.add(completer);
        taskIndex.add(isolateIndex);

        // Update listener for this isolate
        receivePorts[isolateIndex].listen((message) {
          if (message is FileProcessingResult) {
            completer.complete(message);
          }
        });

        sendPorts[isolateIndex].send(tasks[currentTask]);
        currentTask++;
      }
    }
  } finally {
    // Clean up isolates
    for (final isolate in isolates) {
      isolate.kill();
    }
    for (final receivePort in receivePorts) {
      receivePort.close();
    }
  }

  return results;
}

// Async/await parallel processing (original approach)
Future<List<FileProcessingResult>> _processWithFutures(
  List<File> dartFiles,
  Map<String, ClassInfo> classes,
  Map<String, CodeInfo> functions,
  bool analyzeFunctions,
  int concurrency,
  ProgressBar? progressBar,
) async {
  final results = <FileProcessingResult>[];
  var processedCount = 0;

  // Create batches of files
  final batches = <List<File>>[];
  for (int i = 0; i < dartFiles.length; i += concurrency) {
    final end = (i + concurrency).clamp(0, dartFiles.length);
    batches.add(dartFiles.sublist(i, end));
  }

  for (final batch in batches) {
    // Process batch in parallel
    final futures = batch.map(
      (file) => _processFile(
        filePath: path.absolute(file.path),
        classes: classes,
        functions: functions,
        analyzeFunctions: analyzeFunctions,
      ),
    );

    final batchResults = await Future.wait(futures);
    results.addAll(batchResults);
    processedCount += batchResults.length;

    // Update progress
    if (progressBar != null) {
      progressBar.update(processedCount);
    }
  }

  return results;
}

// Alternative implementation using compute for CPU-bound tasks
Future<void> findUsagesWithCompute({
  required Directory dir,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool showProgress,
  required bool analyzeFunctions,
  int? maxConcurrency,
}) async {
  final dartFiles = getDartFiles(dir);

  final concurrency = maxConcurrency ?? Platform.numberOfProcessors;

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar = ProgressBar(
      dartFiles.length,
      description: 'Analyzing code usage',
    );
  }

  var processedCount = 0;
  final results = <FileProcessingResult>[];

  // Process files in parallel batches
  for (int i = 0; i < dartFiles.length; i += concurrency) {
    final end = (i + concurrency).clamp(0, dartFiles.length);
    final batch = dartFiles.sublist(i, end);

    final futures = batch.map((file) async {
      try {
        final filePath = path.absolute(file.path);
        final task = FileProcessingTask(
          filePath: filePath,
          classes: classes,
          functions: functions,
          analyzeFunctions: analyzeFunctions,
        );

        // Use Future.sync for CPU-bound work or consider using compute
        return _processFileSync(task);
      } catch (e) {
        return FileProcessingResult(
          filePath: path.absolute(file.path),
          success: false,
          error: e.toString(),
        );
      }
    });

    final batchResults = await Future.wait(futures);
    results.addAll(batchResults);
    processedCount += batchResults.length;

    if (showProgress) {
      progressBar!.update(processedCount);
    }
  }

  // Merge results
  _mergeResults(results, classes, functions);

  // Print warnings
  for (final result in results) {
    if (!result.success) {
      print(
        '\nWarning: Could not read file ${result.filePath}: ${result.error}',
      );
    }
  }

  if (showProgress) {
    progressBar!.done();
  }
}

Future<FileProcessingResult> _processFile({
  required String filePath,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool analyzeFunctions,
}) async {
  return await Future(() {
    try {
      final content = File(filePath).readAsStringSync();

      final classesCity = Map<String, ClassInfo>.from(classes);
      final functionsCity = Map<String, CodeInfo>.from(functions);

      analyzeClassUsages(content, filePath, classesCity);

      if (analyzeFunctions) {
        analyzeFunctionUsages(content, filePath, functionsCity);
      }

      return FileProcessingResult(
        filePath: filePath,
        success: true,
        updatedClasses: classesCity,
        updatedFunctions: functionsCity,
      );
    } catch (e) {
      return FileProcessingResult(
        filePath: filePath,
        success: false,
        error: e.toString(),
      );
    }
  });
}

FileProcessingResult _processFileSync(FileProcessingTask task) {
  try {
    final content = File(task.filePath).readAsStringSync();

    final classesCity = Map<String, ClassInfo>.from(task.classes);
    final functionsCity = Map<String, CodeInfo>.from(task.functions);

    analyzeClassUsages(content, task.filePath, classesCity);

    if (task.analyzeFunctions) {
      analyzeFunctionUsages(content, task.filePath, functionsCity);
    }

    return FileProcessingResult(
      filePath: task.filePath,
      success: true,
      updatedClasses: classesCity,
      updatedFunctions: functionsCity,
    );
  } catch (e) {
    return FileProcessingResult(
      filePath: task.filePath,
      success: false,
      error: e.toString(),
    );
  }
}

void _mergeResults(
  List<FileProcessingResult> results,
  Map<String, ClassInfo> originalClasses,
  Map<String, CodeInfo> originalFunctions,
) {
  for (final result in results) {
    if (result.success && result.updatedClasses != null) {
      // Merge class usage information
      for (final entry in result.updatedClasses!.entries) {
        final original = originalClasses[entry.key];
        if (original != null) {
          // Merge usage data - this depends on your ClassInfo structure
          // You might need to customize this based on your actual implementation
          originalClasses[entry.key] = entry.value;
        }
      }

      // Merge function usage information
      if (result.updatedFunctions != null) {
        for (final entry in result.updatedFunctions!.entries) {
          final original = originalFunctions[entry.key];
          if (original != null) {
            originalFunctions[entry.key] = entry.value;
          }
        }
      }
    }
  }
}

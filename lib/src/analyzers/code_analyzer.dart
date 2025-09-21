import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:dead_code_analyzer/src/collecter/class_collector.dart';
import 'package:dead_code_analyzer/src/collecter/function_collector.dart';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

// Data class to hold file processing parameters for collection
class CodeCollectionTask {
  final String filePath;
  final bool analyzeFunctions;
  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;

  CodeCollectionTask({
    required this.filePath,
    required this.analyzeFunctions,
    required this.classes,
    required this.functions,
  });
}

// Result class to hold collection results
class CodeCollectionResult {
  final String filePath;
  final bool success;
  final String? error;
  final Map<String, ClassInfo>? collectedClasses;
  final Map<String, CodeInfo>? collectedFunctions;

  CodeCollectionResult({
    required this.filePath,
    required this.success,
    this.error,
    this.collectedClasses,
    this.collectedFunctions,
  });
}

// Isolate entry point for processing files
void _collectCodeEntitiesIsolate(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is CodeCollectionTask) {
      try {
        final result = _processFileForCollection(message);
        sendPort.send(result);
      } catch (e) {
        final result = CodeCollectionResult(
          filePath: message.filePath,
          success: false,
          error: e.toString(),
        );
        sendPort.send(result);
      }
    }
  });
}

// Core file processing logic extracted for reuse
CodeCollectionResult _processFileForCollection(CodeCollectionTask task) {
  try {
    final content = File(task.filePath).readAsStringSync();
    final lines = content.split('\n');

    // Create copies to avoid modifying shared data
    final classes = <String, ClassInfo>{};
    final functions = <String, CodeInfo>{};

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
      'mixin': RegExp(r'mixin\s+(\w+)(?:<[^>]*>)?(?:\s+on\s+[\w\s,<>]+)?\s*\{'),
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
        classCollector(match, lineIndex, pragmaRegex, lines, classes,
            task.filePath, insideStateClass);
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
      if (task.analyzeFunctions) {
        functionCollecter(
          analyzeFunctions: task.analyzeFunctions,
          line: trimmedLine,
          insideStateClass: insideStateClass,
          prebuiltFlutterMethods: prebuiltFlutterMethods,
          lineIndex: lineIndex,
          pragmaRegex: pragmaRegex,
          lines: lines,
          functions: functions,
          filePath: task.filePath,
          currentClassName: currentClassName, // Pass current class name
        );
      }

      lineIndex++;
    }

    return CodeCollectionResult(
      filePath: task.filePath,
      success: true,
      collectedClasses: classes,
      collectedFunctions: functions,
    );
  } catch (e) {
    return CodeCollectionResult(
      filePath: task.filePath,
      success: false,
      error: e.toString(),
    );
  }
}

Future<void> collectCodeEntities({
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
    progressBar = ProgressBar(dartFiles.length,
        description: 'Scanning files for code entities');
  }

  List<CodeCollectionResult> results;

  if (useIsolates) {
    // Use true isolate-based processing
    results = await _collectWithIsolates(
      dartFiles,
      classes,
      functions,
      analyzeFunctions,
      concurrency,
      progressBar,
    );
  } else {
    // Use async/await parallel processing (faster for I/O bound tasks)
    results = await _collectWithFutures(
      dartFiles,
      classes,
      functions,
      analyzeFunctions,
      concurrency,
      progressBar,
    );
  }

  // Merge results back into original maps
  _mergeCollectionResults(results, classes, functions);

  // Print warnings for failed files
  for (final result in results) {
    if (!result.success) {
      print(
          '\nWarning: Could not read file ${result.filePath}: ${result.error}. Check file permissions or ensure the file exists.');
    }
  }

  if (showProgress) {
    progressBar!.done();
  }
}

// True isolate-based processing
Future<List<CodeCollectionResult>> _collectWithIsolates(
  List<File> dartFiles,
  Map<String, ClassInfo> classes,
  Map<String, CodeInfo> functions,
  bool analyzeFunctions,
  int concurrency,
  ProgressBar? progressBar,
) async {
  final results = <CodeCollectionResult>[];
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
          _collectCodeEntitiesIsolate, receivePort.sendPort);
      isolates.add(isolate);

      // Get the SendPort from the isolate
      final sendPort = await receivePort.first as SendPort;
      sendPorts.add(sendPort);
    }

    // Create tasks queue
    final tasks = dartFiles
        .map((file) => CodeCollectionTask(
              filePath: path.absolute(file.path),
              analyzeFunctions: analyzeFunctions,
              classes: classes,
              functions: functions,
            ))
        .toList();

    // Process tasks using isolates
    final completers = <Completer<CodeCollectionResult>>[];
    final taskIndex = <int>[];

    int currentTask = 0;

    // Start initial tasks
    for (int i = 0; i < concurrency && currentTask < tasks.length; i++) {
      final completer = Completer<CodeCollectionResult>();
      completers.add(completer);
      taskIndex.add(i);

      // Listen for response from this isolate
      receivePorts[i].listen((message) {
        if (message is CodeCollectionResult) {
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
        final completer = Completer<CodeCollectionResult>();
        completers.add(completer);
        taskIndex.add(isolateIndex);

        // Update listener for this isolate
        receivePorts[isolateIndex].listen((message) {
          if (message is CodeCollectionResult) {
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

// Async/await parallel processing
Future<List<CodeCollectionResult>> _collectWithFutures(
  List<File> dartFiles,
  Map<String, ClassInfo> classes,
  Map<String, CodeInfo> functions,
  bool analyzeFunctions,
  int concurrency,
  ProgressBar? progressBar,
) async {
  final results = <CodeCollectionResult>[];
  var processedCount = 0;

  // Create batches of files
  final batches = <List<File>>[];
  for (int i = 0; i < dartFiles.length; i += concurrency) {
    final end = (i + concurrency).clamp(0, dartFiles.length);
    batches.add(dartFiles.sublist(i, end));
  }

  for (final batch in batches) {
    // Process batch in parallel
    final futures = batch.map((file) => _processFileAsync(
          filePath: path.absolute(file.path),
          classes: classes,
          functions: functions,
          analyzeFunctions: analyzeFunctions,
        ));

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

Future<CodeCollectionResult> _processFileAsync({
  required String filePath,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool analyzeFunctions,
}) async {
  return Future(() {
    final task = CodeCollectionTask(
      filePath: filePath,
      analyzeFunctions: analyzeFunctions,
      classes: classes,
      functions: functions,
    );

    return _processFileForCollection(task);
  });
}

void _mergeCollectionResults(
  List<CodeCollectionResult> results,
  Map<String, ClassInfo> originalClasses,
  Map<String, CodeInfo> originalFunctions,
) {
  for (final result in results) {
    if (result.success) {
      // Merge collected classes
      if (result.collectedClasses != null) {
        for (final entry in result.collectedClasses!.entries) {
          originalClasses[entry.key] = entry.value;
        }
      }

      // Merge collected functions
      if (result.collectedFunctions != null) {
        for (final entry in result.collectedFunctions!.entries) {
          originalFunctions[entry.key] = entry.value;
        }
      }
    }
  }
}

// Synchronous version for backwards compatibility
void collectCodeEntitiesSync({
  required Directory dir,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool showProgress,
  required bool analyzeFunctions,
}) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar = ProgressBar(dartFiles.length,
        description: 'Scanning files for code entities');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = path.absolute(file.path);

    final task = CodeCollectionTask(
      filePath: filePath,
      analyzeFunctions: analyzeFunctions,
      classes: classes,
      functions: functions,
    );

    final result = _processFileForCollection(task);

    if (result.success) {
      _mergeCollectionResults([result], classes, functions);
    } else {
      print(
          '\nWarning: Could not read file ${result.filePath}: ${result.error}. Check file permissions or ensure the file exists.');
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
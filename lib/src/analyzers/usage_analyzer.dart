import 'dart:io';
import 'dart:isolate';
import 'dart:async';

import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

/// Data class to hold file processing parameters for parallel processing.
class _FileProcessingTask {
  final String filePath;
  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;
  final bool analyzeFunctions;
  final List<ImportInfo> exportList;

  _FileProcessingTask({
    required this.filePath,
    required this.classes,
    required this.functions,
    required this.analyzeFunctions,
    required this.exportList,
  });
}

/// Result class to hold processing results from parallel processing.
class _FileProcessingResult {
  final String filePath;
  final bool success;
  final String? error;
  final Map<String, ClassInfo>? updatedClasses;
  final Map<String, CodeInfo>? updatedFunctions;

  _FileProcessingResult({
    required this.filePath,
    required this.success,
    this.error,
    this.updatedClasses,
    this.updatedFunctions,
  });
}

/// Analyzes code usage patterns to identify references to classes and functions.
///
/// This analyzer scans through Dart files to find where classes and functions
/// are being used, helping to identify dead code and dependencies. It supports
/// both sequential and parallel processing modes for better performance.
///
/// Example usage:
/// ```dart
/// final classes = <String, ClassInfo>{};
/// final functions = <String, CodeInfo>{};
///
/// await UsageAnalyzer.findUsages(
///   directory: Directory('lib'),
///   classes: classes,
///   functions: functions,
///   showProgress: true,
///   analyzeFunctions: true,
///   useParallelProcessing: true,
/// );
/// ```
class UsageAnalyzer {
  /// Finds usages of classes and functions in the specified directory.
  ///
  /// Scans all Dart files in the [directory] and analyzes them for usage
  /// patterns of the provided classes and functions.
  ///
  /// Parameters:
  /// - [directory]: The directory to scan for Dart files
  /// - [classes]: Map of classes to analyze for usage
  /// - [functions]: Map of functions to analyze for usage
  /// - [showProgress]: Whether to display progress during analysis
  /// - [analyzeFunctions]: Whether to analyze function usage patterns
  /// - [exportList]: List of export information for analysis context
  /// - [useParallelProcessing]: Whether to use parallel processing for better performance
  /// - [maxConcurrency]: Maximum number of concurrent operations (defaults to CPU cores * 2)
  /// - [useIsolates]: Whether to use true isolates instead of async parallel processing
  ///
  /// Throws:
  /// - [ArgumentError] if directory doesn't exist or input data is invalid
  /// - [FileSystemException] if files cannot be read
  static Future<void> findUsages({
    required Directory directory,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool showProgress,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
    bool useParallelProcessing = true,
    int? maxConcurrency,
    bool useIsolates = false,
  }) async {
    if (!directory.existsSync()) {
      throw ArgumentError('Directory does not exist: ${directory.path}');
    }

    final dartFiles = Helper.getDartFiles(directory);

    if (dartFiles.isEmpty) {
      if (showProgress) {
        print('No Dart files found in directory: ${directory.path}');
      }
      return;
    }

    // Validate input data
    _validateAnalysisData(classes, functions, analyzeFunctions);

    if (useParallelProcessing) {
      await _findUsagesParallel(
        dartFiles: dartFiles,
        classes: classes,
        functions: functions,
        analyzeFunctions: analyzeFunctions,
        exportList: exportList,
        showProgress: showProgress,
        maxConcurrency: maxConcurrency,
        useIsolates: useIsolates,
      );
    } else {
      await _findUsagesSequential(
        dartFiles: dartFiles,
        classes: classes,
        functions: functions,
        analyzeFunctions: analyzeFunctions,
        exportList: exportList,
        showProgress: showProgress,
      );
    }
  }

  /// Sequential processing implementation (original approach).
  static Future<void> _findUsagesSequential({
    required List<File> dartFiles,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
    required bool showProgress,
  }) async {
    final progressBar = showProgress
        ? ProgressBar(dartFiles.length, description: 'Analyzing code usage')
        : null;

    final analysisResult = _AnalysisResult();

    for (var i = 0; i < dartFiles.length; i++) {
      final file = dartFiles[i];

      try {
        _analyzeFile(
          file: file,
          classes: classes,
          functions: functions,
          analyzeFunctions: analyzeFunctions,
          result: analysisResult,
          exportList: exportList,
        );
      } on FileSystemException catch (e) {
        analysisResult.addError('Cannot read file ${file.path}: ${e.message}');
      } on FormatException catch (e) {
        analysisResult
            .addError('Invalid format in file ${file.path}: ${e.message}');
      } catch (e) {
        analysisResult.addError('Unexpected error processing ${file.path}: $e');
      }

      progressBar?.update(i + 1);
    }

    progressBar?.done();

    // Report any errors that occurred during analysis
    _reportAnalysisResult(analysisResult, showProgress);
  }

  /// Parallel processing implementation with multiple processing strategies.
  static Future<void> _findUsagesParallel({
    required List<File> dartFiles,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
    required bool showProgress,
    int? maxConcurrency,
    bool useIsolates = false,
  }) async {
    // Determine optimal concurrency level
    final concurrency =
        maxConcurrency ?? (Platform.numberOfProcessors * 2).clamp(2, 8);

    ProgressBar? progressBar;
    if (showProgress) {
      progressBar = ProgressBar(
        dartFiles.length,
        description: 'Analyzing code usage (parallel)',
      );
    }

    List<_FileProcessingResult> results;

    if (useIsolates) {
      // Use true isolate-based processing for CPU-intensive tasks
      results = await _processWithIsolates(
        dartFiles,
        classes,
        functions,
        analyzeFunctions,
        exportList,
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
        exportList,
        concurrency,
        progressBar,
      );
    }

    // Merge results back into original maps
    _mergeResults(results, classes, functions);

    // Report errors and warnings
    final analysisResult = _AnalysisResult();
    for (final result in results) {
      if (!result.success) {
        analysisResult.addError(
          'Could not process file ${result.filePath}: ${result.error}',
        );
      }
    }

    progressBar?.done();
    _reportAnalysisResult(analysisResult, showProgress);
  }

  /// Processes files using async/await parallel processing.
  static Future<List<_FileProcessingResult>> _processWithFutures(
      List<File> dartFiles,
      Map<String, ClassInfo> classes,
      Map<String, CodeInfo> functions,
      bool analyzeFunctions,
      List<ImportInfo> exportList,
      int concurrency,
      ProgressBar? progressBar,
      ) async {
    final results = <_FileProcessingResult>[];
    var processedCount = 0;

    // Create batches of files to process in parallel
    final batches = <List<File>>[];
    for (int i = 0; i < dartFiles.length; i += concurrency) {
      final end = (i + concurrency).clamp(0, dartFiles.length);
      batches.add(dartFiles.sublist(i, end));
    }

    for (final batch in batches) {
      // Process batch in parallel
      final futures = batch.map(
            (file) => _processFileAsync(
          filePath: path.absolute(file.path),
          classes: classes,
          functions: functions,
          analyzeFunctions: analyzeFunctions,
          exportList: exportList,
        ),
      );

      final batchResults = await Future.wait(futures);
      results.addAll(batchResults);
      processedCount += batchResults.length;

      // Update progress
      progressBar?.update(processedCount);
    }

    return results;
  }

  /// Processes files using true isolates for CPU-intensive tasks.
  static Future<List<_FileProcessingResult>> _processWithIsolates(
      List<File> dartFiles,
      Map<String, ClassInfo> classes,
      Map<String, CodeInfo> functions,
      bool analyzeFunctions,
      List<ImportInfo> exportList,
      int concurrency,
      ProgressBar? progressBar,
      ) async {
    final results = <_FileProcessingResult>[];
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
            (file) => _FileProcessingTask(
          filePath: path.absolute(file.path),
          classes: classes,
          functions: functions,
          analyzeFunctions: analyzeFunctions,
          exportList: exportList,
        ),
      )
          .toList();

      // Process tasks using isolates
      final completers = <Completer<_FileProcessingResult>>[];
      final taskIndex = <int>[];

      int currentTask = 0;

      // Start initial tasks
      for (int i = 0; i < concurrency && currentTask < tasks.length; i++) {
        final completer = Completer<_FileProcessingResult>();
        completers.add(completer);
        taskIndex.add(i);

        // Listen for response from this isolate
        receivePorts[i].listen((message) {
          if (message is _FileProcessingResult) {
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

        progressBar?.update(processedCount);

        // Find which completer completed and remove it
        final completedIndex = completers.indexWhere((c) => c.isCompleted);
        completers.removeAt(completedIndex);
        final isolateIndex = taskIndex.removeAt(completedIndex);

        // If there are more tasks, assign next task to this isolate
        if (currentTask < tasks.length) {
          final completer = Completer<_FileProcessingResult>();
          completers.add(completer);
          taskIndex.add(isolateIndex);

          // Update listener for this isolate
          receivePorts[isolateIndex].listen((message) {
            if (message is _FileProcessingResult) {
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

  /// Isolate entry point for processing files.
  static void _processFileIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is _FileProcessingTask) {
        try {
          final content = File(message.filePath).readAsStringSync();

          // Create copies to avoid modifying shared data
          final classescopy = Map<String, ClassInfo>.from(message.classes);
          final functionsCity = Map<String, CodeInfo>.from(message.functions);

          // Analyze class usages
          ClassUsage.analyzeClassUsages(
            content: content,
            filePath: message.filePath,
            classes: classescopy,
            exportList: message.exportList,
          );

          // Analyze function usages
          if (message.analyzeFunctions) {
            FunctionUsage.analyzeFunctionUsages(
              content,
              message.filePath,
              functionsCity,
            );
          }

          final result = _FileProcessingResult(
            filePath: message.filePath,
            success: true,
            updatedClasses: classescopy,
            updatedFunctions: functionsCity,
          );

          sendPort.send(result);
        } catch (e) {
          final result = _FileProcessingResult(
            filePath: message.filePath,
            success: false,
            error: e.toString(),
          );
          sendPort.send(result);
        }
      }
    });
  }

  /// Processes a single file asynchronously.
  static Future<_FileProcessingResult> _processFileAsync({
    required String filePath,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
  }) async {
    return Future(() {
      try {
        final content = File(filePath).readAsStringSync();

        final classesCity = Map<String, ClassInfo>.from(classes);
        final functionsCity = Map<String, CodeInfo>.from(functions);

        ClassUsage.analyzeClassUsages(
          content: content,
          filePath: filePath,
          classes: classesCity,
          exportList: exportList,
        );

        if (analyzeFunctions) {
          FunctionUsage.analyzeFunctionUsages(content, filePath, functionsCity);
        }

        return _FileProcessingResult(
          filePath: filePath,
          success: true,
          updatedClasses: classesCity,
          updatedFunctions: functionsCity,
        );
      } catch (e) {
        return _FileProcessingResult(
          filePath: filePath,
          success: false,
          error: e.toString(),
        );
      }
    });
  }

  /// Merges parallel processing results back into original maps.
  static void _mergeResults(
      List<_FileProcessingResult> results,
      Map<String, ClassInfo> originalClasses,
      Map<String, CodeInfo> originalFunctions,
      ) {
    for (final result in results) {
      if (result.success && result.updatedClasses != null) {
        // Merge class usage information
        for (final entry in result.updatedClasses!.entries) {
          final original = originalClasses[entry.key];
          if (original != null) {
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

  /// Validates the input data for analysis.
  ///
  /// Ensures that there's meaningful data to analyze and provides
  /// helpful feedback if the input is empty or invalid.
  static void _validateAnalysisData(
      Map<String, ClassInfo> classes,
      Map<String, CodeInfo> functions,
      bool analyzeFunctions,
      ) {
    if (classes.isEmpty && (!analyzeFunctions || functions.isEmpty)) {
      throw ArgumentError(
        'No classes or functions provided for analysis. '
            'Ensure you have collected code entities before analyzing usage.',
      );
    }
  }

  /// Analyzes a single file for code usage patterns (sequential version).
  ///
  /// [file]: The Dart file to analyze
  /// [classes]: Map of classes to check for usage
  /// [functions]: Map of functions to check for usage
  /// [analyzeFunctions]: Whether to analyze function usage
  /// [result]: Object to track analysis results and errors
  /// [exportList]: List of export information for analysis context
  static void _analyzeFile({
    required File file,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required _AnalysisResult result,
    required List<ImportInfo> exportList,
  }) {
    final filePath = path.absolute(file.path);
    final content = file.readAsStringSync();

    // Validate file content
    if (content.trim().isEmpty) {
      result.addWarning('Skipping empty file: $filePath');
      return;
    }

    result.incrementProcessedFiles();

    // Analyze class usage patterns
    if (classes.isNotEmpty) {
      _analyzeClassUsage(
        content: content,
        filePath: filePath,
        classes: classes,
        result: result,
        exportList: exportList,
      );
    }

    // Analyze function usage patterns if requested
    if (analyzeFunctions && functions.isNotEmpty) {
      _analyzeFunctionUsage(
        content: content,
        filePath: filePath,
        functions: functions,
        result: result,
      );
    }
  }

  /// Analyzes class usage patterns in the file content.
  ///
  /// [content]: The file content to analyze
  /// [filePath]: Path to the file being analyzed
  /// [classes]: Map of classes to check for usage
  /// [result]: Object to track analysis results
  /// [exportList]: List of export information for analysis context
  static void _analyzeClassUsage({
    required String content,
    required String filePath,
    required Map<String, ClassInfo> classes,
    required _AnalysisResult result,
    required List<ImportInfo> exportList,
  }) {
    try {
      ClassUsage.analyzeClassUsages(
        content: content,
        filePath: filePath,
        classes: classes,
        exportList: exportList,
      );
      result.incrementClassAnalyses();
    } catch (e) {
      result.addError('Failed to analyze class usage in $filePath: $e');
    }
  }

  /// Analyzes function usage patterns in the file content.
  ///
  /// [content]: The file content to analyze
  /// [filePath]: Path to the file being analyzed
  /// [functions]: Map of functions to check for usage
  /// [result]: Object to track analysis results
  static void _analyzeFunctionUsage({
    required String content,
    required String filePath,
    required Map<String, CodeInfo> functions,
    required _AnalysisResult result,
  }) {
    try {
      FunctionUsage.analyzeFunctionUsages(content, filePath, functions);
      result.incrementFunctionAnalyses();
    } catch (e) {
      result.addError('Failed to analyze function usage in $filePath: $e');
    }
  }

  /// Reports the results of the analysis process.
  ///
  /// [result]: The analysis result containing statistics and errors
  /// [showProgress]: Whether to show detailed progress information
  static void _reportAnalysisResult(_AnalysisResult result, bool showProgress) {
    if (!showProgress) return;

    // Report warnings if any
    for (final warning in result.warnings) {
      print('Warning: $warning');
    }

    // Report errors if any
    for (final error in result.errors) {
      print('Error: $error');
    }

    // Report summary statistics
    if (result.errors.isNotEmpty || result.warnings.isNotEmpty) {
      print('Analysis completed with ${result.errors.length} errors '
          'and ${result.warnings.length} warnings.');
    }
  }
}

/// Tracks the results and statistics of a usage analysis operation.
///
/// This class maintains counters for processed files, successful analyses,
/// and any errors or warnings that occurred during the process.
class _AnalysisResult {
  /// Number of files successfully processed.
  int _processedFiles = 0;

  /// Number of successful class usage analyses.
  int _classAnalyses = 0;

  /// Number of successful function usage analyses.
  int _functionAnalyses = 0;

  /// List of error messages encountered during analysis.
  final List<String> _errors = [];

  /// List of warning messages encountered during analysis.
  final List<String> _warnings = [];

  /// Gets the number of files processed.
  int get processedFiles => _processedFiles;

  /// Gets the number of class analyses performed.
  int get classAnalyses => _classAnalyses;

  /// Gets the number of function analyses performed.
  int get functionAnalyses => _functionAnalyses;

  /// Gets the list of errors encountered.
  List<String> get errors => List.unmodifiable(_errors);

  /// Gets the list of warnings encountered.
  List<String> get warnings => List.unmodifiable(_warnings);

  /// Increments the count of processed files.
  void incrementProcessedFiles() => _processedFiles++;

  /// Increments the count of class analyses.
  void incrementClassAnalyses() => _classAnalyses++;

  /// Increments the count of function analyses.
  void incrementFunctionAnalyses() => _functionAnalyses++;

  /// Adds an error message to the result.
  ///
  /// [message]: The error message to add
  void addError(String message) => _errors.add(message);

  /// Adds a warning message to the result.
  ///
  /// [message]: The warning message to add
  void addWarning(String message) => _warnings.add(message);

  /// Returns true if the analysis completed without errors.
  bool get isSuccessful => _errors.isEmpty;

  /// Returns true if there are any issues (errors or warnings).
  bool get hasIssues => _errors.isNotEmpty || _warnings.isNotEmpty;
}
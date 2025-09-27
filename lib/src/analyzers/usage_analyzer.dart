import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:math' as math;

import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

/// Analyzes code usage patterns to identify references to classes and functions using parallel processing.
///
/// This analyzer scans through Dart files in parallel to find where classes and functions
/// are being used, significantly improving performance for large codebases.
///
/// Example usage:
/// ```dart
/// final classes = <String, ClassInfo>{};
/// final functions = <String, CodeInfo>{};
///
/// await ParallelUsageAnalyzer.findUsages(
///   directory: Directory('lib'),
///   classes: classes,
///   functions: functions,
///   showProgress: true,
///   analyzeFunctions: true,
///   maxConcurrency: 4,
/// );
/// ```
class UsageAnalyzer {
  /// Maximum number of concurrent isolates to use for processing
  static const int _defaultMaxConcurrency = 4;

  /// Minimum number of files per isolate to justify parallel processing
  static const int _minFilesPerIsolate = 5;

  /// Finds usages of classes and functions in the specified directory using parallel processing.
  ///
  /// Scans all Dart files in the [directory] and analyzes them for usage
  /// patterns of the provided classes and functions using multiple isolates.
  ///
  /// Parameters:
  /// - [directory]: The directory to scan for Dart files
  /// - [classes]: Map of classes to analyze for usage
  /// - [functions]: Map of functions to analyze for usage
  /// - [showProgress]: Whether to display progress during analysis
  /// - [analyzeFunctions]: Whether to analyze function usage patterns
  /// - [exportList]: List of export information for analysis
  /// - [maxConcurrency]: Maximum number of isolates to use (defaults to 4)
  ///
  /// Returns:
  /// - [ParallelAnalysisResult] containing analysis statistics and any errors
  ///
  /// Throws:
  /// - [ArgumentError] if directory doesn't exist or invalid parameters
  static Future<ParallelAnalysisResult> findUsages({
    required Directory directory,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool showProgress,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
    int maxConcurrency = _defaultMaxConcurrency,
  }) async {
    if (!directory.existsSync()) {
      throw ArgumentError('Directory does not exist: ${directory.path}');
    }

    if (maxConcurrency < 1) {
      throw ArgumentError('maxConcurrency must be at least 1');
    }

    final dartFiles = Helper.getDartFiles(directory);

    if (dartFiles.isEmpty) {
      if (showProgress) {
        print('No Dart files found in directory: ${directory.path}');
      }
      return ParallelAnalysisResult.empty();
    }

    // Validate input data
    _validateAnalysisData(classes, functions, analyzeFunctions);

    // Determine optimal concurrency level
    final optimalConcurrency = _calculateOptimalConcurrency(
      dartFiles.length,
      maxConcurrency,
    );

    if (showProgress) {
      print(
        'Processing ${dartFiles.length} files with $optimalConcurrency isolates...',
      );
    }

    final progressBar = showProgress
        ? ProgressBar(
            dartFiles.length,
            description: 'Analyzing code usage (parallel)',
          )
        : null;

    ParallelAnalysisResult result;

    if (optimalConcurrency == 1 || dartFiles.length < _minFilesPerIsolate) {
      // Use sequential processing for small workloads
      result = await _processSequentially(
        dartFiles: dartFiles,
        classes: classes,
        functions: functions,
        analyzeFunctions: analyzeFunctions,
        exportList: exportList,
        progressBar: progressBar,
      );
    } else {
      // Use parallel processing for larger workloads
      result = await _processInParallel(
        dartFiles: dartFiles,
        classes: classes,
        functions: functions,
        analyzeFunctions: analyzeFunctions,
        exportList: exportList,
        concurrency: optimalConcurrency,
        progressBar: progressBar,
      );
    }

    progressBar?.done();
    _reportAnalysisResult(result, showProgress);

    return result;
  }

  /// Calculates the optimal number of isolates to use based on workload and system resources.
  static int _calculateOptimalConcurrency(int fileCount, int maxConcurrency) {
    // Use the minimum of: requested concurrency, available processors, and optimal file distribution
    final availableProcessors = Platform.numberOfProcessors;
    final optimalForFiles = (fileCount / _minFilesPerIsolate).ceil();

    return math.min(
      maxConcurrency,
      math.min(availableProcessors, optimalForFiles),
    );
  }

  /// Processes files sequentially (fallback for small workloads).
  static Future<ParallelAnalysisResult> _processSequentially({
    required List<File> dartFiles,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
    ProgressBar? progressBar,
  }) async {
    final result = ParallelAnalysisResult();

    for (var i = 0; i < dartFiles.length; i++) {
      final file = dartFiles[i];

      try {
        await _analyzeFileSequential(
          file: file,
          classes: classes,
          functions: functions,
          analyzeFunctions: analyzeFunctions,
          result: result,
          exportList: exportList,
        );
      } catch (e) {
        result.addError('Error processing ${file.path}: $e');
      }

      progressBar?.update(i + 1);
    }

    return result;
  }

  /// Processes files in parallel using multiple isolates.
  static Future<ParallelAnalysisResult> _processInParallel({
    required List<File> dartFiles,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
    required int concurrency,
    ProgressBar? progressBar,
  }) async {
    // Split files into chunks for each isolate
    final chunks = _chunkFiles(dartFiles, concurrency);
    final result = ParallelAnalysisResult();

    // Track progress across all isolates
    var completedFiles = 0;

    // Create analysis tasks for each chunk
    final futures = <Future<IsolateAnalysisResult>>[];

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      if (chunk.isEmpty) continue;

      final future = _runIsolateAnalysis(
        files: chunk,
        classes: classes,
        functions: functions,
        analyzeFunctions: analyzeFunctions,
        exportList: exportList,
        isolateId: i,
      );

      futures.add(future);
    }

    // Process results as they complete
    final results = await Future.wait(futures);

    // Merge results from all isolates
    for (final isolateResult in results) {
      result.merge(isolateResult);
      completedFiles += isolateResult.processedFiles;
      progressBar?.update(completedFiles);
    }

    return result;
  }

  /// Runs analysis in a separate isolate.
  static Future<IsolateAnalysisResult> _runIsolateAnalysis({
    required List<File> files,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
    required int isolateId,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<IsolateAnalysisResult>();

    // Prepare data for isolate
    final isolateData = IsolateAnalysisData(
      filePaths: files.map((f) => f.path).toList(),
      classes: classes,
      functions: functions,
      analyzeFunctions: analyzeFunctions,
      exportList: exportList,
      isolateId: isolateId,
      sendPort: receivePort.sendPort,
    );

    // Spawn isolate
    try {
      await Isolate.spawn(_isolateEntryPoint, isolateData);
    } catch (e) {
      completer.completeError('Failed to spawn isolate $isolateId: $e');
      return completer.future;
    }

    // Listen for results
    receivePort.listen((message) {
      if (message is IsolateAnalysisResult) {
        completer.complete(message);
        receivePort.close();
      } else if (message is String && message.startsWith('ERROR:')) {
        completer.completeError(message.substring(6));
        receivePort.close();
      }
    });

    return completer.future;
  }

  /// Entry point for isolate execution.
  static void _isolateEntryPoint(IsolateAnalysisData data) async {
    final result = IsolateAnalysisResult(isolateId: data.isolateId);

    try {
      for (final filePath in data.filePaths) {
        final file = File(filePath);

        if (!file.existsSync()) {
          result.addError('File not found: $filePath');
          continue;
        }

        try {
          await _analyzeFileInIsolate(
            file: file,
            classes: data.classes,
            functions: data.functions,
            analyzeFunctions: data.analyzeFunctions,
            result: result,
            exportList: data.exportList,
          );
        } catch (e) {
          result.addError('Error analyzing $filePath: $e');
        }
      }

      data.sendPort.send(result);
    } catch (e) {
      data.sendPort.send('ERROR: Isolate ${data.isolateId} failed: $e');
    }
  }

  /// Analyzes a single file within an isolate.
  static Future<void> _analyzeFileInIsolate({
    required File file,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required IsolateAnalysisResult result,
    required List<ImportInfo> exportList,
  }) async {
    final filePath = path.absolute(file.path);
    final content = file.readAsStringSync();

    if (content.trim().isEmpty) {
      result.addWarning('Skipping empty file: $filePath');
      return;
    }

    result.incrementProcessedFiles();

    // Analyze class usage patterns
    if (classes.isNotEmpty) {
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

    // Analyze function usage patterns if requested
    if (analyzeFunctions && functions.isNotEmpty) {
      try {
        FunctionUsage.analyzeFunctionUsages(content, filePath, functions);
        result.incrementFunctionAnalyses();
      } catch (e) {
        result.addError('Failed to analyze function usage in $filePath: $e');
      }
    }
  }

  /// Sequential file analysis (used as fallback).
  static Future<void> _analyzeFileSequential({
    required File file,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool analyzeFunctions,
    required ParallelAnalysisResult result,
    required List<ImportInfo> exportList,
  }) async {
    final filePath = path.absolute(file.path);
    final content = file.readAsStringSync();

    if (content.trim().isEmpty) {
      result.addWarning('Skipping empty file: $filePath');
      return;
    }

    result.incrementProcessedFiles();

    // Analyze class usage patterns
    if (classes.isNotEmpty) {
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

    // Analyze function usage patterns if requested
    if (analyzeFunctions && functions.isNotEmpty) {
      try {
        FunctionUsage.analyzeFunctionUsages(content, filePath, functions);
        result.incrementFunctionAnalyses();
      } catch (e) {
        result.addError('Failed to analyze function usage in $filePath: $e');
      }
    }
  }

  /// Splits files into chunks for parallel processing.
  static List<List<File>> _chunkFiles(List<File> files, int chunkCount) {
    if (files.isEmpty || chunkCount <= 1) {
      return [files];
    }

    final chunks = <List<File>>[];
    final chunkSize = (files.length / chunkCount).ceil();

    for (var i = 0; i < files.length; i += chunkSize) {
      final end = math.min(i + chunkSize, files.length);
      chunks.add(files.sublist(i, end));
    }

    return chunks;
  }

  /// Validates the input data for analysis.
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

  /// Reports the results of the analysis process.
  static void _reportAnalysisResult(
    ParallelAnalysisResult result,
    bool showProgress,
  ) {
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
    print(
      'Analysis completed: ${result.processedFiles} files processed, '
      '${result.classAnalyses} class analyses, '
      '${result.functionAnalyses} function analyses',
    );

    if (result.hasIssues) {
      print(
        'Issues found: ${result.errors.length} errors, '
        '${result.warnings.length} warnings',
      );
    }
  }
}

/// Data structure for passing analysis parameters to isolates.
class IsolateAnalysisData {
  final List<String> filePaths;
  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;
  final bool analyzeFunctions;
  final List<ImportInfo> exportList;
  final int isolateId;
  final SendPort sendPort;

  const IsolateAnalysisData({
    required this.filePaths,
    required this.classes,
    required this.functions,
    required this.analyzeFunctions,
    required this.exportList,
    required this.isolateId,
    required this.sendPort,
  });
}

/// Results from analysis performed in an isolate.
class IsolateAnalysisResult {
  final int isolateId;
  int _processedFiles = 0;
  int _classAnalyses = 0;
  int _functionAnalyses = 0;
  final List<String> _errors = [];
  final List<String> _warnings = [];

  IsolateAnalysisResult({required this.isolateId});

  int get processedFiles => _processedFiles;
  int get classAnalyses => _classAnalyses;
  int get functionAnalyses => _functionAnalyses;
  List<String> get errors => List.unmodifiable(_errors);
  List<String> get warnings => List.unmodifiable(_warnings);

  void incrementProcessedFiles() => _processedFiles++;
  void incrementClassAnalyses() => _classAnalyses++;
  void incrementFunctionAnalyses() => _functionAnalyses++;
  void addError(String message) => _errors.add(message);
  void addWarning(String message) => _warnings.add(message);

  bool get isSuccessful => _errors.isEmpty;
  bool get hasIssues => _errors.isNotEmpty || _warnings.isNotEmpty;
}

/// Results from parallel analysis operation.
class ParallelAnalysisResult {
  int _processedFiles = 0;
  int _classAnalyses = 0;
  int _functionAnalyses = 0;
  final List<String> _errors = [];
  final List<String> _warnings = [];

  ParallelAnalysisResult();

  /// Creates an empty result for cases where no files are found.
  ParallelAnalysisResult.empty();

  int get processedFiles => _processedFiles;
  int get classAnalyses => _classAnalyses;
  int get functionAnalyses => _functionAnalyses;
  List<String> get errors => List.unmodifiable(_errors);
  List<String> get warnings => List.unmodifiable(_warnings);

  void incrementProcessedFiles() => _processedFiles++;
  void incrementClassAnalyses() => _classAnalyses++;
  void incrementFunctionAnalyses() => _functionAnalyses++;
  void addError(String message) => _errors.add(message);
  void addWarning(String message) => _warnings.add(message);

  bool get isSuccessful => _errors.isEmpty;
  bool get hasIssues => _errors.isNotEmpty || _warnings.isNotEmpty;

  /// Merges results from an isolate into this result.
  void merge(IsolateAnalysisResult isolateResult) {
    _processedFiles += isolateResult.processedFiles;
    _classAnalyses += isolateResult.classAnalyses;
    _functionAnalyses += isolateResult.functionAnalyses;
    _errors.addAll(isolateResult.errors);
    _warnings.addAll(isolateResult.warnings);
  }
}

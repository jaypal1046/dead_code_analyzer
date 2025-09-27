import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:dead_code_analyzer/src/collectors/export_collector.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;
import '../models/analyzer/class_context.dart';
import '../models/analyzer/entity_match.dart';
import 'code_patterns.dart';

/// Analyzes Dart code to collect information about classes and functions.
///
/// This analyzer scans through Dart files in a directory and extracts
/// metadata about classes, enums, extensions, mixins, and functions.
/// Supports both synchronous and asynchronous parallel processing.
///
class CodeAnalyzer {
  /// Regular expressions for matching different code entities.
  static final _codePatterns = CodePatterns();

  /// Maximum number of concurrent isolates for parallel processing
  static const int _maxConcurrency = 8;

  /// Collects code entities from the specified directory with parallel processing.
  ///
  /// Scans all Dart files in the [directory] and populates the provided
  /// maps with information about classes and functions found.
  ///
  /// Parameters:
  /// - [directory]: The directory to scan for Dart files
  /// - [classes]: Map to store collected class information
  /// - [functions]: Map to store collected function information
  /// - [showProgress]: Whether to display progress during scanning
  /// - [analyzeFunctions]: Whether to analyze function definitions
  /// - [useParallelProcessing]: Whether to use parallel processing (default: true)
  /// - [maxConcurrency]: Maximum number of concurrent workers (default: 8)
  ///
  /// Throws:
  /// - [ArgumentError] if directory doesn't exist
  /// - [FileSystemException] if files cannot be read
  static Future<void> collectCodeEntities({
    required Directory directory,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool showProgress,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
    bool useParallelProcessing = true,
    int maxConcurrency = _maxConcurrency,
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

    if (useParallelProcessing && dartFiles.length > 1) {
      await _collectCodeEntitiesParallel(
        dartFiles: dartFiles,
        classes: classes,
        functions: functions,
        exportList: exportList,
        analyzeFunctions: analyzeFunctions,
        showProgress: showProgress,
        maxConcurrency: maxConcurrency,
      );
    } else {
      await _collectCodeEntitiesSequential(
        dartFiles: dartFiles,
        classes: classes,
        functions: functions,
        exportList: exportList,
        analyzeFunctions: analyzeFunctions,
        showProgress: showProgress,
      );
    }
  }

  /// Sequential processing implementation (original behavior)
  static Future<void> _collectCodeEntitiesSequential({
    required List<File> dartFiles,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool analyzeFunctions,
    required bool showProgress,
  }) async {
    final processedFiles = <String>{};

    final progressBar = showProgress
        ? ProgressBar(
            dartFiles.length,
            description: 'Scanning files for code entities',
          )
        : null;

    var processedCount = 0;

    for (final file in dartFiles) {
      try {
        await _processFile(
          file: file,
          classes: classes,
          functions: functions,
          exportList: exportList,
          analyzeFunctions: analyzeFunctions,
          processedFiles: processedFiles,
        );
      } on FileSystemException catch (e) {
        print('Warning: Cannot read file ${file.path}: ${e.message}');
      } on FormatException catch (e) {
        print('Warning: Invalid format in file ${file.path}: ${e.message}');
      } catch (e) {
        print('Warning: Unexpected error processing ${file.path}: $e');
      }

      processedCount++;
      progressBar?.update(processedCount);
    }

    progressBar?.done();
  }

  /// Parallel processing implementation using isolates
  static Future<void> _collectCodeEntitiesParallel({
    required List<File> dartFiles,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool analyzeFunctions,
    required bool showProgress,
    required int maxConcurrency,
  }) async {
    // Determine optimal number of workers
    final numWorkers = (dartFiles.length < maxConcurrency)
        ? dartFiles.length
        : maxConcurrency;

    if (showProgress) {
      print(
        'Processing ${dartFiles.length} files using $numWorkers workers...',
      );
    }

    final progressBar = showProgress
        ? ProgressBar(
            dartFiles.length,
            description: 'Scanning files for code entities (parallel)',
          )
        : null;

    // Split files into chunks for each worker
    final chunks = _splitIntoChunks(dartFiles, numWorkers);
    final futures = <Future<FileProcessingResult>>[];

    // Create workers and start processing
    for (int i = 0; i < chunks.length; i++) {
      if (chunks[i].isNotEmpty) {
        final future = _createWorker(
          files: chunks[i],
          workerId: i,
          analyzeFunctions: analyzeFunctions,
          onProgress: showProgress
              ? (count) {
                  progressBar?.update(progressBar.width + count);
                }
              : null,
        );
        futures.add(future);
      }
    }

    // Wait for all workers to complete
    final results = await Future.wait(futures);

    // Merge results from all workers
    await _mergeResults(
      results: results,
      classes: classes,
      functions: functions,
      exportList: exportList,
    );

    progressBar?.done();

    if (showProgress) {
      print(
        'Parallel processing completed. Processed ${dartFiles.length} files.',
      );
    }
  }

  /// Creates a worker isolate to process a chunk of files
  static Future<FileProcessingResult> _createWorker({
    required List<File> files,
    required int workerId,
    required bool analyzeFunctions,
    void Function(int)? onProgress,
  }) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerEntryPoint,
      WorkerMessage(
        sendPort: receivePort.sendPort,
        files: files.map((f) => f.path).toList(),
        analyzeFunctions: analyzeFunctions,
        workerId: workerId,
      ),
    );

    final completer = Completer<FileProcessingResult>();

    receivePort.listen((data) {
      if (data is Map<String, dynamic>) {
        if (data['type'] == 'progress') {
          onProgress?.call(1);
        } else if (data['type'] == 'result') {
          completer.complete(FileProcessingResult.fromJson(data['data']));
          receivePort.close();
          isolate.kill();
        } else if (data['type'] == 'error') {
          completer.completeError(Exception(data['message']));
          receivePort.close();
          isolate.kill();
        }
      }
    });

    return completer.future;
  }

  /// Entry point for worker isolates
  static void _workerEntryPoint(WorkerMessage message) async {
    try {
      final classes = <String, ClassInfo>{};
      final functions = <String, CodeInfo>{};
      final exportList = <ImportInfo>[];
      final processedFiles = <String>{};

      for (final filePath in message.files) {
        try {
          final file = File(filePath);
          await _processFile(
            file: file,
            classes: classes,
            functions: functions,
            exportList: exportList,
            analyzeFunctions: message.analyzeFunctions,
            processedFiles: processedFiles,
          );

          // Send progress update
          message.sendPort.send({
            'type': 'progress',
            'workerId': message.workerId,
            'file': filePath,
          });
        } catch (e) {
          // Continue processing other files even if one fails
          print('Worker ${message.workerId} error processing $filePath: $e');
        }
      }

      // Send results back to main isolate
      final result = FileProcessingResult(
        classes: classes,
        functions: functions,
        exportList: exportList,
        workerId: message.workerId,
      );

      message.sendPort.send({'type': 'result', 'data': result.toJson()});
    } catch (e) {
      message.sendPort.send({'type': 'error', 'message': e.toString()});
    }
  }

  /// Processes a single Dart file to extract code entities.
  static Future<void> _processFile({
    required File file,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool analyzeFunctions,
    required Set<String> processedFiles,
  }) async {
    final filePath = path.absolute(file.path);

    // Skip if already processed to prevent infinite recursion
    if (processedFiles.contains(filePath)) {
      return;
    }

    // Mark file as processed
    processedFiles.add(filePath);

    final content = await file.readAsString();
    final lines = content.split('\n');

    final context = ClassContext();

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final trimmedLine = line.trim();

      // Update class context based on braces and class definitions
      _updateClassContext(
        line: trimmedLine,
        lineIndex: lineIndex,
        lines: lines,
        context: context,
        classes: classes,
        filePath: filePath,
      );

      // Handle export statements
      if (line.startsWith('export')) {
        ExportCollector.handleExport(
          line: trimmedLine,
          currentFile: file,
          classes: classes,
          functions: functions,
          exportList: exportList,
          analyzeFunctions: analyzeFunctions,
        );
      }

      // Analyze functions if requested
      if (analyzeFunctions) {
        _analyzeFunctions(
          line: trimmedLine,
          lineIndex: lineIndex,
          lines: lines,
          context: context,
          functions: functions,
          filePath: filePath,
        );
      }
    }
  }

  /// Splits a list of files into chunks for parallel processing
  static List<List<File>> _splitIntoChunks(List<File> files, int numChunks) {
    final chunks = <List<File>>[];
    final chunkSize = (files.length / numChunks).ceil();

    for (int i = 0; i < files.length; i += chunkSize) {
      final end = (i + chunkSize < files.length) ? i + chunkSize : files.length;
      chunks.add(files.sublist(i, end));
    }

    return chunks;
  }

  /// Merges results from all worker isolates
  static Future<void> _mergeResults({
    required List<FileProcessingResult> results,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
  }) async {
    for (final result in results) {
      // Merge classes
      classes.addAll(result.classes);

      // Merge functions
      functions.addAll(result.functions);

      // Merge export list
      exportList.addAll(result.exportList);
    }
  }

  // Rest of the methods remain unchanged...

  static void _updateClassContext({
    required String line,
    required int lineIndex,
    required List<String> lines,
    required ClassContext context,
    required Map<String, ClassInfo> classes,
    required String filePath,
  }) {
    final openBraces = '{'.allMatches(line).length;
    final closeBraces = '}'.allMatches(line).length;

    final entityMatch = _findCodeEntity(line);
    if (entityMatch != null) {
      _handleNewCodeEntity(
        entityMatch: entityMatch,
        lineIndex: lineIndex,
        lines: lines,
        context: context,
        classes: classes,
        filePath: filePath,
      );
    }

    if (context.isInsideClass) {
      context.updateDepth(openBraces - closeBraces);

      if (context.depth <= 0) {
        _exitCurrentClass(context, classes);
      }
    }
  }

  static EntityMatch? _findCodeEntity(String line) {
    for (final entry in _codePatterns.patterns.entries) {
      final match = entry.value.firstMatch(line);
      if (match != null) {
        return EntityMatch(type: entry.key, match: match);
      }
    }
    return null;
  }

  static void _handleNewCodeEntity({
    required EntityMatch entityMatch,
    required int lineIndex,
    required List<String> lines,
    required ClassContext context,
    required Map<String, ClassInfo> classes,
    required String filePath,
  }) {
    final className = entityMatch.match.group(1)!;

    context.enterClass(className, entityMatch.type);

    final isStateClass = _isStateClass(className, classes);
    context.setInsideStateClass(isStateClass);

    ClassCollector.collectClassFromLine(
      classMatch: entityMatch.match,
      lineIndex: lineIndex,
      pragmaRegex: _codePatterns.pragmaRegex,
      lines: lines,
      classes: classes,
      filePath: filePath,
      insideStateClass: isStateClass,
    );
  }

  static void _exitCurrentClass(
    ClassContext context,
    Map<String, ClassInfo> classes,
  ) {
    context.exitClass();

    if (context.isInsideClass && context.currentType == 'class') {
      final isStateClass = _isStateClass(context.currentClassName, classes);
      context.setInsideStateClass(isStateClass);
    } else {
      context.setInsideStateClass(false);
    }
  }

  static bool _isStateClass(String className, Map<String, ClassInfo> classes) {
    if (!className.endsWith('State')) return false;

    final widgetName = className.substring(0, className.length - 5);
    return classes.containsKey(widgetName) || className.startsWith('_');
  }

  static void _analyzeFunctions({
    required String line,
    required int lineIndex,
    required List<String> lines,
    required ClassContext context,
    required Map<String, CodeInfo> functions,
    required String filePath,
  }) {
    FunctionCollector.collectFunctions(
      analyzeFunctions: true,
      line: line,
      insideStateClass: context.insideStateClass,
      prebuiltFlutterMethods: Helper.prebuiltFlutterMethods,
      lineIndex: lineIndex,
      pragmaRegex: _codePatterns.pragmaRegex,
      lines: lines,
      functions: functions,
      filePath: filePath,
      currentClassName: context.currentClassName,
    );
  }
}

/// Message class for communication with worker isolates
class WorkerMessage {
  final SendPort sendPort;
  final List<String> files;
  final bool analyzeFunctions;
  final int workerId;

  WorkerMessage({
    required this.sendPort,
    required this.files,
    required this.analyzeFunctions,
    required this.workerId,
  });
}

/// Result class for collecting data from worker isolates
class FileProcessingResult {
  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;
  final List<ImportInfo> exportList;
  final int workerId;

  FileProcessingResult({
    required this.classes,
    required this.functions,
    required this.exportList,
    required this.workerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'classes': classes.map((k, v) => MapEntry(k, v.toJson())),
      'functions': functions.map((k, v) => MapEntry(k, v.toJson())),
      'exportList': exportList.map((e) => e.toJson()).toList(),
      'workerId': workerId,
    };
  }

  static FileProcessingResult fromJson(Map<String, dynamic> json) {
    return FileProcessingResult(
      classes: (json['classes'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, ClassInfo.fromJson(v)),
      ),
      functions: (json['functions'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, CodeInfo.fromJson(v)),
      ),
      exportList: (json['exportList'] as List)
          .map((e) => ImportInfo.fromJson(e))
          .toList(),
      workerId: json['workerId'],
    );
  }
}

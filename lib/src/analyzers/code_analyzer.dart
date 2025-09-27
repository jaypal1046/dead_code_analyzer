import 'dart:io';
import 'dart:isolate';
import 'dart:async';

import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:dead_code_analyzer/src/collectors/class_collector.dart';
import 'package:dead_code_analyzer/src/collectors/export_collector.dart';
import 'package:dead_code_analyzer/src/collectors/function_collector.dart';
import 'package:dead_code_analyzer/src/models/class_info.dart';
import 'package:dead_code_analyzer/src/models/code_info.dart';
import 'package:dead_code_analyzer/src/utils/helper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

/// Data class to hold file processing parameters for collection
class CodeCollectionTask {
  final String filePath;
  final bool analyzeFunctions;
  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;
  final List<ImportInfo> exportList;

  CodeCollectionTask({
    required this.filePath,
    required this.analyzeFunctions,
    required this.classes,
    required this.functions,
    required this.exportList,
  });
}

/// Result class to hold collection results
class CodeCollectionResult {
  final String filePath;
  final bool success;
  final String? error;
  final Map<String, ClassInfo>? collectedClasses;
  final Map<String, CodeInfo>? collectedFunctions;
  final List<ImportInfo>? collectedExports;

  CodeCollectionResult({
    required this.filePath,
    required this.success,
    this.error,
    this.collectedClasses,
    this.collectedFunctions,
    this.collectedExports,
  });
}

/// Analyzes Dart code to collect information about classes and functions.
///
/// This analyzer scans through Dart files in a directory and extracts
/// metadata about classes, enums, extensions, mixins, and functions.
/// Supports both synchronous and asynchronous parallel processing.
///
/// Example usage:
/// ```dart
/// final classes = <String, ClassInfo>{};
/// final functions = <String, CodeInfo>{};
/// final exportList = <ImportInfo>[];
///
/// // Synchronous processing
/// CodeAnalyzer.collectCodeEntities(
///   directory: Directory('lib'),
///   classes: classes,
///   functions: functions,
///   exportList: exportList,
///   showProgress: true,
///   analyzeFunctions: true,
/// );
///
/// // Asynchronous parallel processing
/// await CodeAnalyzer.collectCodeEntitiesAsync(
///   directory: Directory('lib'),
///   classes: classes,
///   functions: functions,
///   exportList: exportList,
///   showProgress: true,
///   analyzeFunctions: true,
///   useIsolates: false,
///   maxConcurrency: 4,
/// );
/// ```
class CodeAnalyzer {
  /// Regular expressions for matching different code entities.
  static final _codePatterns = _CodePatterns();

  // Track processed files to prevent circular export recursion
  static final Set<String> _processedFiles = {};

  /// Collects code entities from the specified directory synchronously.
  ///
  /// Scans all Dart files in the [directory] and populates the provided
  /// maps with information about classes and functions found.
  ///
  /// Parameters:
  /// - [directory]: The directory to scan for Dart files
  /// - [classes]: Map to store collected class information
  /// - [functions]: Map to store collected function information
  /// - [exportList]: List to store export information
  /// - [showProgress]: Whether to display progress during scanning
  /// - [analyzeFunctions]: Whether to analyze function definitions
  ///
  /// Throws:
  /// - [ArgumentError] if directory doesn't exist
  /// - [FileSystemException] if files cannot be read
  static void collectCodeEntities({
    required Directory directory,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool showProgress,
    required bool analyzeFunctions,
  }) {
    if (!directory.existsSync()) {
      throw ArgumentError('Directory does not exist: ${directory.path}');
    }

    // Reset processed files at the start of a new analysis
    _processedFiles.clear();

    final dartFiles = Helper.getDartFiles(directory);

    if (dartFiles.isEmpty) {
      if (showProgress) {
        print('No Dart files found in directory: ${directory.path}');
      }
      return;
    }

    final progressBar = showProgress
        ? ProgressBar(dartFiles.length,
        description: 'Scanning files for code entities')
        : null;

    var processedCount = 0;

    for (final file in dartFiles) {
      try {
        _processFile(
          file: file,
          classes: classes,
          functions: functions,
          exportList: exportList,
          analyzeFunctions: analyzeFunctions,
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

  /// Collects code entities from the specified directory asynchronously with parallel processing.
  ///
  /// Parameters:
  /// - [directory]: The directory to scan for Dart files
  /// - [classes]: Map to store collected class information
  /// - [functions]: Map to store collected function information
  /// - [exportList]: List to store export information
  /// - [showProgress]: Whether to display progress during scanning
  /// - [analyzeFunctions]: Whether to analyze function definitions
  /// - [maxConcurrency]: Maximum number of concurrent operations (defaults to 2x CPU cores, clamped 2-8)
  /// - [useIsolates]: Whether to use true isolates or async futures for parallelization
  static Future<void> collectCodeEntitiesAsync({
    required Directory directory,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool showProgress,
    required bool analyzeFunctions,
    int? maxConcurrency,
    bool useIsolates = false,
  }) async {
    if (!directory.existsSync()) {
      throw ArgumentError('Directory does not exist: ${directory.path}');
    }

    // Reset processed files at the start of a new analysis
    _processedFiles.clear();

    final dartFiles = Helper.getDartFiles(directory);

    if (dartFiles.isEmpty) {
      if (showProgress) {
        print('No Dart files found in directory: ${directory.path}');
      }
      return;
    }

    // Determine optimal concurrency level
    final concurrency =
        maxConcurrency ?? (Platform.numberOfProcessors * 2).clamp(2, 8);

    ProgressBar? progressBar;
    if (showProgress) {
      progressBar = ProgressBar(
        dartFiles.length,
        description: 'Scanning files for code entities',
      );
    }

    List<CodeCollectionResult> results;

    if (useIsolates) {
      // Use true isolate-based processing
      results = await _collectWithIsolates(
        dartFiles,
        classes,
        functions,
        exportList,
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
        exportList,
        analyzeFunctions,
        concurrency,
        progressBar,
      );
    }

    // Merge results back into original maps
    _mergeCollectionResults(results, classes, functions, exportList);

    // Print warnings for failed files
    for (final result in results) {
      if (!result.success) {
        print(
          'Warning: Could not read file ${result.filePath}: ${result.error}',
        );
      }
    }

    progressBar?.done();
  }

  /// Processes a single Dart file to extract code entities.
  ///
  /// [file]: The Dart file to process
  /// [classes]: Map to store class information
  /// [functions]: Map to store function information
  /// [exportList]: List to store export information
  /// [analyzeFunctions]: Whether to analyze functions
  static void _processFile({
    required File file,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool analyzeFunctions,
  }) {
    final filePath = path.absolute(file.path);

    // Skip if already processed to prevent infinite recursion
    if (_processedFiles.contains(filePath)) {
      return;
    }

    // Mark file as processed
    _processedFiles.add(filePath);

    final content = file.readAsStringSync();
    final lines = content.split('\n');

    final context = _ClassContext();

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

  /// Isolate entry point for processing files
  static void _collectCodeEntitiesIsolate(SendPort sendPort) {
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

  /// Core file processing logic for parallel processing
  static CodeCollectionResult _processFileForCollection(CodeCollectionTask task) {
    try {
      final content = File(task.filePath).readAsStringSync();
      final lines = content.split('\n');

      // Create copies to avoid modifying shared data
      final classes = <String, ClassInfo>{};
      final functions = <String, CodeInfo>{};
      final exportList = <ImportInfo>[];

      final context = _ClassContext();

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
          filePath: task.filePath,
        );

        // Handle export statements
        if (line.startsWith('export')) {
          ExportCollector.handleExport(
            line: trimmedLine,
            currentFile: File(task.filePath),
            classes: classes,
            functions: functions,
            exportList: exportList,
            analyzeFunctions: task.analyzeFunctions,
          );
        }

        // Analyze functions if requested
        if (task.analyzeFunctions) {
          _analyzeFunctions(
            line: trimmedLine,
            lineIndex: lineIndex,
            lines: lines,
            context: context,
            functions: functions,
            filePath: task.filePath,
          );
        }
      }

      return CodeCollectionResult(
        filePath: task.filePath,
        success: true,
        collectedClasses: classes,
        collectedFunctions: functions,
        collectedExports: exportList,
      );
    } catch (e) {
      return CodeCollectionResult(
        filePath: task.filePath,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// True isolate-based processing
  static Future<List<CodeCollectionResult>> _collectWithIsolates(
      List<File> dartFiles,
      Map<String, ClassInfo> classes,
      Map<String, CodeInfo> functions,
      List<ImportInfo> exportList,
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
          _collectCodeEntitiesIsolate,
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
            (file) => CodeCollectionTask(
          filePath: path.absolute(file.path),
          analyzeFunctions: analyzeFunctions,
          classes: classes,
          functions: functions,
          exportList: exportList,
        ),
      )
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

        progressBar?.update(processedCount);

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

  /// Async/await parallel processing
  static Future<List<CodeCollectionResult>> _collectWithFutures(
      List<File> dartFiles,
      Map<String, ClassInfo> classes,
      Map<String, CodeInfo> functions,
      List<ImportInfo> exportList,
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
      final futures = batch.map(
            (file) => _processFileAsync(
          filePath: path.absolute(file.path),
          classes: classes,
          functions: functions,
          exportList: exportList,
          analyzeFunctions: analyzeFunctions,
        ),
      );

      final batchResults = await Future.wait(futures);
      results.addAll(batchResults);
      processedCount += batchResults.length;

      progressBar?.update(processedCount);
    }

    return results;
  }

  static Future<CodeCollectionResult> _processFileAsync({
    required String filePath,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool analyzeFunctions,
  }) async {
    return Future(() {
      final task = CodeCollectionTask(
        filePath: filePath,
        analyzeFunctions: analyzeFunctions,
        classes: classes,
        functions: functions,
        exportList: exportList,
      );

      return _processFileForCollection(task);
    });
  }

  static void _mergeCollectionResults(
      List<CodeCollectionResult> results,
      Map<String, ClassInfo> originalClasses,
      Map<String, CodeInfo> originalFunctions,
      List<ImportInfo> originalExportList,
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

        // Merge collected exports
        if (result.collectedExports != null) {
          originalExportList.addAll(result.collectedExports!);
        }
      }
    }
  }

  /// Updates the current class context based on the current line.
  ///
  /// Tracks class definitions, nesting level, and State class detection.
  static void _updateClassContext({
    required String line,
    required int lineIndex,
    required List<String> lines,
    required _ClassContext context,
    required Map<String, ClassInfo> classes,
    required String filePath,
  }) {
    // Count braces to track nesting depth
    final openBraces = '{'.allMatches(line).length;
    final closeBraces = '}'.allMatches(line).length;

    // Check for class/enum/extension/mixin definitions
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

    // Update nesting depth and handle class exits
    if (context.isInsideClass) {
      context.updateDepth(openBraces - closeBraces);

      if (context.depth <= 0) {
        _exitCurrentClass(context, classes);
      }
    }
  }

  /// Finds and returns information about code entities in the given line.
  static _EntityMatch? _findCodeEntity(String line) {
    for (final entry in _codePatterns.patterns.entries) {
      final match = entry.value.firstMatch(line);
      if (match != null) {
        return _EntityMatch(type: entry.key, match: match);
      }
    }
    return null;
  }

  /// Handles discovery of a new code entity (class, enum, etc.).
  static void _handleNewCodeEntity({
    required _EntityMatch entityMatch,
    required int lineIndex,
    required List<String> lines,
    required _ClassContext context,
    required Map<String, ClassInfo> classes,
    required String filePath,
  }) {
    final className = entityMatch.match.group(1)!;

    // Update context
    context.enterClass(className, entityMatch.type);

    // Check if this is a State class
    final isStateClass = _isStateClass(className, classes);
    context.setInsideStateClass(isStateClass);

    // Collect class information
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

  /// Exits the current class context and returns to parent if nested.
  static void _exitCurrentClass(
      _ClassContext context,
      Map<String, ClassInfo> classes,
      ) {
    context.exitClass();

    // Update State class status for new current class
    if (context.isInsideClass && context.currentType == 'class') {
      final isStateClass = _isStateClass(context.currentClassName, classes);
      context.setInsideStateClass(isStateClass);
    } else {
      context.setInsideStateClass(false);
    }
  }

  /// Checks if a class name represents a Flutter State class.
  static bool _isStateClass(String className, Map<String, ClassInfo> classes) {
    if (!className.endsWith('State')) return false;

    final widgetName = className.substring(0, className.length - 5);
    return classes.containsKey(widgetName) || className.startsWith('_');
  }

  /// Analyzes functions in the current line.
  static void _analyzeFunctions({
    required String line,
    required int lineIndex,
    required List<String> lines,
    required _ClassContext context,
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

/// Container class for regular expression patterns used in code analysis.
class _CodePatterns {
  /// Regex for matching pragma annotations.
  final RegExp pragmaRegex = RegExp(
    r'''^\s*@pragma\s*\(\s*[\'"]((?:vm:entry-point)|(?:vm:external-name)|(?:vm:prefer-inline)|(?:vm:exact-result-type)|(?:vm:never-inline)|(?:vm:non-nullable-by-default)|(?:flutter:keep-to-string)|(?:flutter:keep-to-string-in-subtypes))[\'"]\s*(?:,\s*[^)]+)?\s*\)\s*$''',
    multiLine: false,
  );

  /// Patterns for matching different code entities.
  final Map<String, RegExp> patterns = {
    'class': RegExp(
      r'class\s+(\w+)(?:<[^>]*>)?(?:\s+extends\s+\w+(?:<[^>]*>)?)?(?:\s+with\s+[\w\s,<>]+)?(?:\s+implements\s+[\w\s,<>]+)?\s*\{',
    ),
    'enum': RegExp(
      r'enum\s+(\w+)(?:\s+with\s+[\w\s,<>]+)?\s*\{',
    ),
    'extension': RegExp(
      r'extension\s+(\w+)(?:<[^>]*>)?\s+on\s+[\w<>\s,]+\s*\{',
    ),
    'mixin': RegExp(
      r'mixin\s+(\w+)(?:<[^>]*>)?(?:\s+on\s+[\w\s,<>]+)?\s*\{',
    ),
  };
}

/// Represents a matched code entity with its type and regex match.
class _EntityMatch {
  /// The type of entity (class, enum, extension, mixin).
  final String type;

  /// The regex match containing the entity details.
  final RegExpMatch match;

  const _EntityMatch({
    required this.type,
    required this.match,
  });
}

/// Manages the current class context during code analysis.
///
/// Tracks the current class being analyzed, nesting depth,
/// and whether we're inside a Flutter State class.
class _ClassContext {
  /// Stack of class information for handling nested classes.
  final List<_ClassInfo> _classStack = [];

  /// Current nesting depth within braces.
  int depth = 0;

  /// Whether currently inside a Flutter State class.
  bool insideStateClass = false;

  /// Returns true if currently inside any class.
  bool get isInsideClass => _classStack.isNotEmpty;

  /// Returns the name of the current class, or empty string if none.
  String get currentClassName =>
      _classStack.isNotEmpty ? _classStack.last.name : '';

  /// Returns the type of the current class, or empty string if none.
  String get currentType => _classStack.isNotEmpty ? _classStack.last.type : '';

  /// Enters a new class context.
  ///
  /// [className]: Name of the class being entered
  /// [type]: Type of the entity (class, enum, extension, mixin)
  void enterClass(String className, String type) {
    _classStack.add(_ClassInfo(name: className, type: type));
    depth = 1; // Reset depth for new class
  }

  /// Exits the current class context.
  void exitClass() {
    if (_classStack.isNotEmpty) {
      _classStack.removeLast();
    }

    // Reset depth appropriately
    if (_classStack.isNotEmpty) {
      depth = 1; // Still inside parent class
    } else {
      depth = 0; // Outside all classes
    }
  }

  /// Updates the current nesting depth.
  ///
  /// [change]: The change in depth (positive for opening braces, negative for closing)
  void updateDepth(int change) {
    depth += change;
  }

  /// Sets whether currently inside a State class.
  void setInsideStateClass(bool value) {
    insideStateClass = value;
  }
}

/// Information about a class in the context stack.
class _ClassInfo {
  /// The name of the class.
  final String name;

  /// The type of the entity (class, enum, extension, mixin).
  final String type;

  const _ClassInfo({
    required this.name,
    required this.type,
  });
}
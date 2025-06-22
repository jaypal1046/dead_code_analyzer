import 'dart:io';

import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

/// Analyzes code usage patterns to identify references to classes and functions.
///
/// This analyzer scans through Dart files to find where classes and functions
/// are being used, helping to identify dead code and dependencies.
///
/// Example usage:
/// ```dart
/// final classes = <String, ClassInfo>{};
/// final functions = <String, CodeInfo>{};
///
/// UsageAnalyzer.findUsages(
///   directory: Directory('lib'),
///   classes: classes,
///   functions: functions,
///   showProgress: true,
///   analyzeFunctions: true,
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
  ///
  /// Throws:
  /// - [ArgumentError] if directory doesn't exist
  /// - [FileSystemException] if files cannot be read
  static void findUsages({
    required Directory directory,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool showProgress,
    required bool analyzeFunctions,
    required List<ImportInfo> exportList,
  }) {
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

  /// Analyzes a single file for code usage patterns.
  ///
  /// [file]: The Dart file to analyze
  /// [classes]: Map of classes to check for usage
  /// [functions]: Map of functions to check for usage
  /// [analyzeFunctions]: Whether to analyze function usage
  /// [result]: Object to track analysis results and errors
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

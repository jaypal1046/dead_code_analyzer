import 'dart:io';
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
  static final _codePatterns = CodePatterns();

  // Track processed files to prevent circular export recursion
  static final Set<String> _processedFiles = {};

  /// Collects code entities from the specified directory.
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
  ///
  /// Throws:
  /// - [ArgumentError] if directory doesn't exist
  /// - [FileSystemException] if files cannot be read
  static void collectCodeEntities({
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

  /// Processes a single Dart file to extract code entities.
  ///
  /// [file]: The Dart file to process
  /// [classes]: Map to store class information
  /// [functions]: Map to store function information
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

  /// Updates the current class context based on the current line.
  ///
  /// Tracks class definitions, nesting level, and State class detection.
  static void _updateClassContext({
    required String line,
    required int lineIndex,
    required List<String> lines,
    required ClassContext context,
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
  static EntityMatch? _findCodeEntity(String line) {
    for (final entry in _codePatterns.patterns.entries) {
      final match = entry.value.firstMatch(line);
      if (match != null) {
        return EntityMatch(type: entry.key, match: match);
      }
    }
    return null;
  }

  /// Handles discovery of a new code entity (class, enum, etc.).
  static void _handleNewCodeEntity({
    required EntityMatch entityMatch,
    required int lineIndex,
    required List<String> lines,
    required ClassContext context,
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
    ClassContext context,
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

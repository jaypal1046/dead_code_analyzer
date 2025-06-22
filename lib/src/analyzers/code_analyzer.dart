import 'dart:io';

import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:dead_code_analyzer/src/collectors/class_collector.dart';
import 'package:dead_code_analyzer/src/collectors/function_collector.dart';
import 'package:dead_code_analyzer/src/models/class_info.dart';
import 'package:dead_code_analyzer/src/models/code_info.dart';
import 'package:dead_code_analyzer/src/utils/helper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

/// Analyzes Dart code to collect information about classes and functions.
///
/// This analyzer scans through Dart files in a directory and extracts
/// metadata about classes, enums, extensions, mixins, and functions.
///
/// Example usage:
/// ```dart
/// final classes = <String, ClassInfo>{};
/// final functions = <String, CodeInfo>{};
///
/// CodeAnalyzer.collectCodeEntities(
///   directory: Directory('lib'),
///   classes: classes,
///   functions: functions,
///   showProgress: true,
///   analyzeFunctions: true,
/// );
/// ```
class CodeAnalyzer {
  /// Regular expressions for matching different code entities.
  static final _codePatterns = _CodePatterns();

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
        _handleExport(
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

  /// Handles an export statement by resolving and processing the exported file.
  static void _handleExport({
    required String line,
    required File currentFile,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool analyzeFunctions,
  }) {
    final exportRegex = RegExp(
      r'''export\s+['"](.+?)['"]\s*(?:as\s+(\w+))?\s*(?:show\s+([\w\s,]+))?\s*(?:hide\s+([\w\s,]+))?;''',
    );
    final match = exportRegex.firstMatch(line);
    if (match == null) return;

    final exportPath = match.group(1)!;
    final asAlias = match.group(2);
    final showClasses = match
            .group(3)
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final hideClasses = match
            .group(4)
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    // Resolve the export path relative to the current file's directory
    final currentDir = path.dirname(currentFile.path);
    // Normalize and resolve the export path for all OS (Windows, Mac, Linux)
    String resolvedPath = path.normalize(path.join(currentDir, exportPath));
    // Convert to absolute path if not already
    if (!path.isAbsolute(resolvedPath)) {
      resolvedPath = path.absolute(resolvedPath);
    }
    // On Windows, convert all separators to backslash for consistency
    if (Platform.isWindows) {
      resolvedPath = path.canonicalize(resolvedPath);
    }

    // Validate the exported file
    final exportedFile = File(resolvedPath);
    if (!exportedFile.existsSync()) {
      print('Warning: Exported file does not exist: $resolvedPath');
      return;
    }

    // Check if it's a Dart file
    if (path.extension(resolvedPath) != '.dart') {
      print('Warning: Exported file is not a Dart file: $resolvedPath');
      return;
    }

    // Store export information
    exportList.add(
      ImportInfo(
        path: resolvedPath, // Store absolute path
        asAlias: asAlias,
        shownClasses: showClasses,
        hiddenClasses: hideClasses,
        sourceFile: path.absolute(currentFile.path), // Track the source of the export
      ),
    );

    // Recursively process the exported file
    try {
      _processFile(
        file: exportedFile,
        classes: classes,
        functions: functions,
        exportList: exportList,
        analyzeFunctions: analyzeFunctions,
      );
    } catch (e) {
      print('Warning: Error processing exported file $resolvedPath: $e');
    }
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
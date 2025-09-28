import 'dart:io';

import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:path/path.dart' as path;

class ExportCollector {
  /// Handles an export statement by resolving and processing the exported file.
  static void handleExport({
    required String line,
    required File currentFile,
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required List<ImportInfo> exportList,
    required bool analyzeFunctions,
  }) async {
    // Handle valid Dart export patterns only
    final simpleExportRegex = RegExp(r'''export\s+['"](.+?)['"];''');
    final namedExportRegex = RegExp(
      r'''export\s+['"](.+?)['"]\s*(?:show\s+([\w\s,]+))?\s*(?:hide\s+([\w\s,]+))?;''',
    );

    String? exportPath;
    List<String> showItems = [];
    List<String> hideItems = [];

    // Check for named exports with show/hide
    final namedMatch = namedExportRegex.firstMatch(line);
    if (namedMatch != null) {
      exportPath = namedMatch.group(1)!;
      showItems =
          namedMatch
              .group(2)
              ?.split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];
      hideItems =
          namedMatch
              .group(3)
              ?.split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];
    } else {
      // Check for simple export 'path' pattern
      final simpleMatch = simpleExportRegex.firstMatch(line);
      if (simpleMatch != null) {
        exportPath = simpleMatch.group(1)!;
      }
    }

    if (exportPath == null) return;

    // Resolve the export path relative to the current file's directory
    final currentDir = path.dirname(currentFile.path);
    // Normalize and resolve the export path for all OS (Windows, Mac, Linux)
    String resolvedPath = path.normalize(path.join(currentDir, exportPath));

    // Handle .dart extension if not present
    if (!resolvedPath.endsWith('.dart')) {
      resolvedPath += '.dart';
    }

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

    // Separate classes and functions from show/hide lists using file analysis
    final (showClasses, showFunctions) = _separateClassesAndFunctions(
      showItems,
      resolvedPath,
      classes,
      functions,
    );
    final (hideClasses, hideFunctions) = _separateClassesAndFunctions(
      hideItems,
      resolvedPath,
      classes,
      functions,
    );

    // Determine if this is a wildcard export (simple export with no show/hide)
    final isWildcardExport = showItems.isEmpty && hideItems.isEmpty;

    // Store export information with enhanced metadata
    exportList.add(
      ImportInfo(
        path: resolvedPath, // Store absolute path
        shownClasses: showClasses,
        hiddenClasses: hideClasses,
        shownFunctions: showFunctions,
        hiddenFunctions: hideFunctions,
        sourceFile: path.absolute(
          currentFile.path,
        ), // Track the source of the export
        isExport: true, // Mark this as an export
        isWildcardExport: isWildcardExport, // Mark if it's a wildcard export
      ),
    );

    // Optional: Print debug information
    print(
      'Found export: ${isWildcardExport ? 'wildcard' : 'selective'} from $resolvedPath in ${currentFile.path}',
    );
    if (showClasses.isNotEmpty || showFunctions.isNotEmpty) {
      print('  - Showing classes: ${showClasses.join(', ')}');
      print('  - Showing functions: ${showFunctions.join(', ')}');
    }
    if (hideClasses.isNotEmpty || hideFunctions.isNotEmpty) {
      print('  - Hiding classes: ${hideClasses.join(', ')}');
      print('  - Hiding functions: ${hideFunctions.join(', ')}');
    }
  }

  /// Analyzes an exported file to identify what classes and functions it contains
  static (List<String>, List<String>) analyzeExportedFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return ([], []);

    final lines = file.readAsLinesSync();
    final classes = <String>[];
    final functions = <String>[];

    for (final line in lines) {
      final trimmedLine = line.trim();

      // Skip comments and empty lines
      if (trimmedLine.isEmpty ||
          trimmedLine.startsWith('//') ||
          trimmedLine.startsWith('/*')) {
        continue;
      }

      // Match class declarations
      final classRegex = RegExp(r'(?:abstract\s+)?class\s+(\w+)');
      final classMatch = classRegex.firstMatch(trimmedLine);
      if (classMatch != null) {
        classes.add(classMatch.group(1)!);
        continue;
      }

      // Match enum declarations
      final enumRegex = RegExp(r'enum\s+(\w+)');
      final enumMatch = enumRegex.firstMatch(trimmedLine);
      if (enumMatch != null) {
        classes.add(enumMatch.group(1)!); // Treat enums as classes
        continue;
      }

      // Match mixin declarations
      final mixinRegex = RegExp(r'mixin\s+(\w+)');
      final mixinMatch = mixinRegex.firstMatch(trimmedLine);
      if (mixinMatch != null) {
        classes.add(mixinMatch.group(1)!); // Treat mixins as classes
        continue;
      }

      // Match typedef declarations
      final typedefRegex = RegExp(r'typedef\s+(\w+)');
      final typedefMatch = typedefRegex.firstMatch(trimmedLine);
      if (typedefMatch != null) {
        functions.add(typedefMatch.group(1)!); // Treat typedefs as functions
        continue;
      }

      // Match function declarations (top-level functions)
      final functionRegex = RegExp(r'(?:Future<\w+>|[\w<>]+)\s+(\w+)\s*\(');
      final functionMatch = functionRegex.firstMatch(trimmedLine);
      if (functionMatch != null &&
          !trimmedLine.contains('class ') &&
          !trimmedLine.contains('{')) {
        functions.add(functionMatch.group(1)!);
        continue;
      }

      // Match variable declarations that might be functions
      final varRegex = RegExp(r'(?:final|const|var)\s+(?:\w+\s+)?(\w+)\s*=');
      final varMatch = varRegex.firstMatch(trimmedLine);
      if (varMatch != null) {
        functions.add(
          varMatch.group(1)!,
        ); // Treat variables as functions for now
      }
    }

    return (classes, functions);
  }

  /// Helper method to properly separate classes and functions using file analysis
  static (List<String>, List<String>) _separateClassesAndFunctions(
    List<String> items,
    String exportedFilePath,
    Map<String, ClassInfo> currentClasses,
    Map<String, CodeInfo> currentFunctions,
  ) {
    // First, analyze the exported file to understand what it contains
    final (fileClasses, fileFunctions) = analyzeExportedFile(exportedFilePath);

    final classNames = <String>[];
    final functionNames = <String>[];

    for (final item in items) {
      // Check if it's a class in the exported file
      if (fileClasses.contains(item)) {
        classNames.add(item);
      }
      // Check if it's a function in the exported file
      else if (fileFunctions.contains(item)) {
        functionNames.add(item);
      }
      // Fallback to current context
      else if (currentClasses.containsKey(item)) {
        classNames.add(item);
      } else if (currentFunctions.containsKey(item)) {
        functionNames.add(item);
      }
    }

    return (classNames, functionNames);
  }

  /// Helper method to get all exports from a file
  static List<ImportInfo> getExportsFromFile(File file) {
    final exportList = <ImportInfo>[];
    final lines = file.readAsLinesSync();

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.startsWith('export ')) {
        handleExport(
          line: trimmedLine,
          currentFile: file,
          classes: {}, // Empty for this helper method
          functions: {}, // Empty for this helper method
          exportList: exportList,
          analyzeFunctions: false,
        );
      }
    }

    return exportList;
  }

  /// Helper method to check if a file has any exports
  static bool hasExports(File file) {
    final lines = file.readAsLinesSync();
    return lines.any((line) => line.trim().startsWith('export '));
  }
}

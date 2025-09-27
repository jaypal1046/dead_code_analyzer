/// Utility functions for analyzing Dart and Flutter code in the dead code analyzer.
///
/// The [Helper] class provides methods for file handling, comment detection, and
/// categorization of Flutter-specific constructs. It is designed to support the
/// `dead_code_analyzer` package by processing Dart files and identifying code
/// patterns such as commented code, constructors, and prebuilt Flutter methods.
///
/// Example usage:
/// ```dart
/// final dartFiles = Helper.getDartFiles(Directory('lib'));
/// final isCommented = Helper.isLineCommented('// void main() {}');
/// ```

import 'dart:io';

import 'package:args/args.dart';
import 'package:dead_code_analyzer/dead_code_analyzer.dart';

/// Utility class for code analysis tasks in Flutter projects.
class Helper {
  /// Retrieves all Dart files in a directory, excluding certain paths.
  ///
  /// [directory] is the root directory to search for Dart files.
  /// Returns a list of [File] objects for `.dart` files, excluding those in
  /// `.dart_tool` or `build` directories.
  static List<File> getDartFiles(Directory directory) {
    try {
      return directory
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') &&
                !file.path.contains(RegExp(r'[\\/]\.dart_tool[\\/]')) &&
                !file.path.contains(RegExp(r'[\\/]build[\\/]')) &&
                !file.path.contains(RegExp(r'[\\/]\.idea[\\/]')) &&
                !file.path.contains(RegExp(r'[\\/]\.vscode[\\/]')) &&
                !file.path.contains(RegExp(r'[\\/]test[\\/]')) &&
                !file.path.contains(RegExp(r'[\\/]\.fvm[\\/]')),
          )
          .toList();
    } catch (e, stackTrace) {
      throw FileSystemException(
        'Failed to list Dart files in ${directory.path}: $e',
        stackTrace.toString(),
      );
    }
  }

  /// Prints the command-line usage instructions for the analyzer.
  ///
  /// [parser] is the [ArgParser] instance containing the command-line options.
  static void printUsage(ArgParser parser) {
    // ignore: avoid_print
    print('''
Usage: dart run dead_code_analyzer [options]

${parser.usage}

Example:
  dart run dead_code_analyzer -p /path/to/flutter/project -o /path/to/save/report -f --limit 20
''');
  }

  /// Checks if a line of code is commented out.
  ///
  /// [line] is the line of code to check.
  /// Returns `true` if the line is a single-line comment (`//`), a single-line
  /// block comment (`/* */`), or part of a multi-line comment.
  static bool isLineCommented(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('//') ||
        (trimmed.startsWith('/*') && trimmed.endsWith('*/'));
  }

  /// Checks if a function declaration is within a commented section.
  ///
  /// [line] is the line containing the function declaration.
  /// [match] is the [RegExpMatch] for the function declaration.
  /// [lines] is the list of all lines in the file.
  /// [lineIndex] is the index of the line in [lines].
  /// Returns `true` if the function is commented out.
  static bool isFunctionCommented(
    String line,
    RegExpMatch match,
    List<String> lines,
    int lineIndex,
  ) {
    final beforeFunction = line.substring(0, match.start).trim();
    final functionPart = line.substring(match.start).trim();

    if (beforeFunction.endsWith('//') || functionPart.startsWith('//')) {
      return true;
    }

    if (isLineCommented(line)) {
      return true;
    }

    return _isInMultiLineComment(lines, lineIndex, match.start);
  }

  /// Checks if a position in a file is within a multi-line comment.
  ///
  /// [lines] is the list of all lines in the file.
  /// [lineIndex] is the index of the line to check.
  /// [charPosition] is the character position within the line.
  /// Returns `true` if the position is inside a `/* */` comment.
  static bool _isInMultiLineComment(
    List<String> lines,
    int lineIndex,
    int charPosition,
  ) {
    var insideComment = false;

    for (var i = 0; i <= lineIndex; i++) {
      final lineToCheck = lines[i];
      final endPos = i == lineIndex ? charPosition : lineToCheck.length;

      var pos = 0;
      while (pos < endPos - 1) {
        if (pos < lineToCheck.length - 1 &&
            lineToCheck[pos] == '/' &&
            lineToCheck[pos + 1] == '/') {
          break; // Skip single-line comments
        }

        if (!insideComment &&
            pos < lineToCheck.length - 1 &&
            lineToCheck[pos] == '/' &&
            lineToCheck[pos + 1] == '*') {
          insideComment = true;
          pos += 2;
        } else if (insideComment &&
            pos < lineToCheck.length - 1 &&
            lineToCheck[pos] == '*' &&
            lineToCheck[pos + 1] == '/') {
          insideComment = false;
          pos += 2;
        } else {
          pos++;
        }
      }
    }

    return insideComment;
  }

  /// Checks if a function is a constructor based on its name and declaration.
  ///
  /// [functionName] is the name of the function.
  /// [line] is the line containing the function declaration.
  /// Returns `true` if the function is a constructor.
  static bool isConstructor(String functionName, String line) {
    if (functionName.isEmpty ||
        functionName[0] != functionName[0].toUpperCase()) {
      return false;
    }

    final constructorPattern = RegExp(r'^\s*(?://\s*)?[A-Z]\w*(?:\.\w+)?\s*\(');
    return constructorPattern.hasMatch(line.trim());
  }

  /// Cleans a function name by removing comment-related suffixes.
  ///
  /// [functionKey] is the function name, potentially with a suffix.
  /// Returns the cleaned function name.
  static String cleanFunctionName(String functionKey) =>
      functionKey.split('_commented_').first;

  /// Filters functions that are commented out.
  ///
  /// [functions] is a map of function names to their [CodeInfo].
  /// Returns a map containing only the commented functions.
  static Map<String, CodeInfo> getCommentedFunctions(
    Map<String, CodeInfo> functions,
  ) => Map.fromEntries(
    functions.entries.where((entry) => entry.value.commentedOut),
  );

  /// Filters functions that are not commented out.
  ///
  /// [functions] is a map of function names to their [CodeInfo].
  /// Returns a map containing only the active (non-commented) functions.
  static Map<String, CodeInfo> getActiveFunctions(
    Map<String, CodeInfo> functions,
  ) => Map.fromEntries(
    functions.entries.where((entry) => !entry.value.commentedOut),
  );

  /// Sanitizes a file path for use in reports or keys.
  ///
  /// [filePath] is the file path to sanitize.
  /// Returns a sanitized string, removing the 'lib/' prefix and replacing invalid
  /// characters with underscores.
  static String sanitizeFilePath(String filePath) {
    final sanitized = filePath.startsWith('lib/')
        ? filePath.substring(4)
        : filePath;
    return sanitized.replaceAll(RegExp(r'[\/\\.]'), '_');
  }

  /// A set of prebuilt Flutter and Dart methods commonly overridden or used.
  ///
  /// This set includes lifecycle methods, widget methods, and other framework-specific
  /// methods that are typically not considered "dead" code.
  static const Set<String> prebuiltFlutterMethods = {
    // Core Dart methods
    'print',
    'debugPrint',
    'main',
    'runApp',
    'runZoned',
    'toString',
    'hashCode',
    'noSuchMethod',

    // Widget lifecycle
    'createElement',
    'canUpdate',
    'createState',
    'initState',
    'didChangeDependencies',
    'didUpdateWidget',
    'reassemble',
    'deactivate',
    'dispose',

    // Render object methods
    'createRenderObject',
    'updateRenderObject',
    'didUnmountRenderObject',
    'performLayout',
    'performResize',
    'paint',
    'hitTest',
    'hitTestSelf',
    'hitTestChildren',
    'applyPaintTransform',
    'getTransformTo',
    'getDistanceToActualBaseline',
    'computeMinIntrinsicWidth',
    'computeMaxIntrinsicWidth',
    'computeMinIntrinsicHeight',
    'computeMaxIntrinsicHeight',
    'performCommit',
    'adoptChild',
    'dropChild',
    'visitChildren',
    'redepthChildren',
    'attach',
    'detach',
    'showOnScreen',
    'describeSemanticsConfiguration',
    'assembleSemanticsNode',
    'clearSemantics',

    // Inherited widget
    'updateShouldNotify',

    // Animation methods
    'addListener',
    'removeListener',
    'addStatusListener',
    'removeStatusListener',

    // Stream controller
    'onListen',
    'onPause',
    'onResume',
    'onCancel',

    // Element methods
    'mount',
    'updateSlotForChild',
    'attachRenderObject',
    'detachRenderObject',
    'unmount',
    'performRebuild',
    'debugVisitOnstageChildren',
    'debugDescribeChildren',

    // Ticker methods
    'start',
    'shouldScheduleTick',
    'unscheduleTick',

    // App lifecycle
    'didChangeAppLifecycleState',
    'didHaveMemoryPressure',
    'didChangeLocales',
    'didChangeTextScaleFactor',
    'didChangePlatformBrightness',
    'didChangeAccessibilityFeatures',

    // Widgets binding observer
    'didChangeMetrics',
    'didRequestAppExit',
    'didPopRoute',
    'didPushRoute',
    'didPushRouteInformation',

    // Hero animations
    'createRectTween',
    'flightShuttleBuilder',
    'placeholderBuilder',

    // Page route
    'buildPage',
    'buildTransitions',
    'canTransitionFrom',
    'canTransitionTo',

    // Custom painter
    'shouldRepaint',
    'shouldRebuildSemantics',
    'semanticsBuilder',

    // Sliver methods
    'childMainAxisPosition',
    'childCrossAxisPosition',
    'childScrollOffset',
    'calculatePaintOffset',
    'calculateCacheOffset',
    'childExistingScrollOffset',
    'updateOutOfBandData',
    'updateParentData',

    // Platform channel
    'setMethodCallHandler',
  };

  /// A set of Dart keywords used in class collection.
  ///
  /// These keywords are used to avoid misidentifying language constructs as user-defined
  /// classes or functions.
  static const Set<String> keywords = {
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'Function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'sealed',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };

  /// A list of pattern names for class collection.
  ///
  /// These patterns describe the types of class-like constructs recognized by the analyzer,
  /// such as regular classes, enums, mixins, and extensions.
  static const List<String> patternNames = [
    'Regular class',
    'Enum',
    'Mixin',
    'Named extension',
    'Anonymous extension',
    'Typedef',
    'Mixin class',
  ];
}

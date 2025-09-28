/// A utility class for generating and saving detailed reports of Flutter code usage analysis.
///
/// The [FileReporter] class processes class and function information, categorizes them based on usage,
/// and generates a formatted text report. The report includes summaries, detailed sections for classes
/// and functions, and relative file paths for better readability. It adheres to Flutter package guidelines
/// for documentation, error handling, and code style.
///
/// Example usage:
/// ```dart
/// FileReporter.saveResultsToFile(
///   classes: classMap,
///   functions: functionMap,
///   outputDirectory: 'reports',
///   projectPath: '/path/to/project',
///   analyzeFunctions: true,
/// );
/// ```

import 'dart:io';

import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class FileReporter {
  /// Converts an absolute file path to a path relative to the project's `lib` directory or root.
  ///
  /// [absolutePath] is the full path to the file.
  /// [projectPath] is the root directory of the project.
  /// Returns a relative path string, normalized for readability.
  static String _toLibRelativePath(String absolutePath, String projectPath) {
    final libPath = path.join(projectPath, 'lib');
    return absolutePath.startsWith(libPath)
        ? path.relative(absolutePath, from: libPath)
        : path.relative(absolutePath, from: projectPath);
  }

  /// Formats a map of external usage files into a readable string.
  ///
  /// [externalUsages] maps file paths to the number of references.
  /// [projectPath] is the root directory of the project.
  /// Returns a formatted string of file paths and reference counts.
  static String _formatUsageFiles(
    Map<String, int> externalUsages,
    String projectPath,
  ) {
    final usageFiles = externalUsages.entries
        .map((entry) {
          final fileName = _toLibRelativePath(entry.key, projectPath);
          final count = entry.value;
          return '$fileName ($count references)';
        })
        .join(', ');
    return '[$usageFiles]';
  }

  /// Writes a categorized section for class entities to the report buffer.
  ///
  /// [buffer] is the output buffer for the report.
  /// [title] is the section title.
  /// [entries] are the class entries to report.
  /// [entityType] describes the type of entities (e.g., 'unused classes').
  /// [projectPath] is the root directory of the project.
  static void _writeCategoryClassSection(
    StringBuffer buffer,
    String title,
    List<MapEntry<String, ClassInfo>> entries,
    String entityType,
    String projectPath,
  ) {
    buffer
      ..writeln(title)
      ..writeln('-' * title.length)
      ..writeln();

    if (entries.isEmpty) {
      buffer.writeln('No $entityType found.');
      buffer.writeln();
      return;
    }

    for (final entry in entries) {
      final name = entry.key;
      final info = entry.value;
      final internalUses = info.internalUsageCount;
      final externalUses = info.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      final definedIn = _toLibRelativePath(info.definedInFile, projectPath);
      final usageFilesStr = externalUses > 0
          ? ' ${_formatUsageFiles(info.externalUsages, projectPath)}'
          : '';
      final entryPointNote = info.isEntryPoint && totalUses == 0
          ? ' [Used by native code via @pragma("vm:entry-point")]'
          : '';

      buffer.writeln(
        '- $name (in $definedIn, internal: $internalUses, external: $externalUses, total: $totalUses)$usageFilesStr$entryPointNote',
      );
    }
    buffer.writeln();
  }

  /// Writes a categorized section for function entities to the report buffer.
  ///
  /// [buffer] is the output buffer for the report.
  /// [title] is the section title.
  /// [entries] are the function entries to report.
  /// [entityType] describes the type of entities (e.g., 'unused functions').
  /// [projectPath] is the root directory of the project.
  static void _writeCategoryFunctionSection(
    StringBuffer buffer,
    String title,
    List<MapEntry<String, CodeInfo>> entries,
    String entityType,
    String projectPath,
  ) {
    buffer
      ..writeln(title)
      ..writeln('-' * title.length)
      ..writeln();

    if (entries.isEmpty) {
      buffer.writeln('No $entityType found.');
      buffer.writeln();
      return;
    }

    for (final entry in entries) {
      final name = entry.key;
      final info = entry.value;
      final internalUses = info.internalUsageCount;
      final externalUses = info.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      final definedIn = _toLibRelativePath(info.definedInFile, projectPath);
      final usageFilesStr = externalUses > 0
          ? ' ${_formatUsageFiles(info.externalUsages, projectPath)}'
          : '';
      final entryPointNote = info.isEntryPoint && totalUses == 0
          ? ' [Used by native code via @pragma]'
          : '';

      buffer.writeln(
        '- $name (in $definedIn, internal: $internalUses, external: $externalUses, total: $totalUses)$usageFilesStr$entryPointNote',
      );
    }
    buffer.writeln();
  }

  /// Categorizes classes based on their usage patterns.
  ///
  /// [classes] is a map of class names to their [ClassInfo].
  /// Returns a map of category names to lists of class entries, sorted by usage.
  static Map<String, List<MapEntry<String, ClassInfo>>> _categorizeClasses(
    Map<String, ClassInfo> classes,
  ) {
    final sortedClasses = classes.entries.toList()
      ..sort((a, b) {
        final externalComparison = a.value.totalExternalUsages.compareTo(
          b.value.totalExternalUsages,
        );
        return externalComparison != 0
            ? externalComparison
            : a.value.totalUsages.compareTo(b.value.totalUsages);
      });

    final categories = <String, List<MapEntry<String, ClassInfo>>>{
      'unused': [],
      'internalOnly': [],
      'externalOnly': [],
      'bothInternalExternal': [],
      'stateClass': [],
      'entryPoint': [],
      'commented': [],
      'mixing': [],
      'enum': [],
      'extension': [],
      'typedef': [],
    };

    for (final entry in sortedClasses) {
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;
      final totalUses = internalUses + externalUses;

      if (classInfo.commentedOut) {
        categories['commented']!.add(entry);
      } else if (classInfo.isEntryPoint) {
        categories['entryPoint']!.add(entry);
      } else if (classInfo.type == 'state_class') {
        categories['stateClass']!.add(entry);
      } else if (totalUses == 0) {
        categories['unused']!.add(entry);
      } else if (classInfo.type == 'enum') {
        categories['enum']!.add(entry);
      } else if (classInfo.type == 'mixin' || classInfo.type == 'mixin_class') {
        categories['mixing']!.add(entry);
      } else if (classInfo.type == 'extension') {
        categories['extension']!.add(entry);
      } else if (classInfo.type == 'typedef') {
        categories['typedef']!.add(entry);
      } else if (internalUses > 0 && externalUses == 0) {
        categories['internalOnly']!.add(entry);
      } else if (internalUses == 0 && externalUses > 0) {
        categories['externalOnly']!.add(entry);
      } else if (internalUses > 0 && externalUses > 0) {
        categories['bothInternalExternal']!.add(entry);
      }
    }

    return categories;
  }

  /// Categorizes functions based on their usage patterns.
  ///
  /// [functions] is a map of function names to their [CodeInfo].
  /// Returns a map of category names to lists of function entries, sorted by usage.
  static Map<String, List<MapEntry<String, CodeInfo>>> _categorizeFunctions(
    Map<String, CodeInfo> functions,
  ) {
    final sortedFunctions = functions.entries.toList()
      ..sort((a, b) {
        final externalComparison = a.value.totalExternalUsages.compareTo(
          b.value.totalExternalUsages,
        );
        return externalComparison != 0
            ? externalComparison
            : a.value.totalUsages.compareTo(b.value.totalUsages);
      });

    final categories = <String, List<MapEntry<String, CodeInfo>>>{
      'unused': [],
      'internalOnly': [],
      'externalOnly': [],
      'bothInternalExternal': [],
      'emptyPrebuilt': [],
      'entryPoint': [],
      'commented': [],
      'commentedPrebuilt': [],
    };

    for (final entry in sortedFunctions) {
      final functionInfo = entry.value;
      final internalUses = functionInfo.internalUsageCount;
      final externalUses = functionInfo.totalExternalUsages;
      final totalUses = internalUses + externalUses;

      if (functionInfo.isPrebuiltFlutter) {
        if (functionInfo.isEmpty) {
          categories['emptyPrebuilt']!.add(entry);
        }
        continue;
      }

      if (functionInfo.isEntryPoint) {
        categories['entryPoint']!.add(entry);
      } else if (functionInfo.isPrebuiltFlutterCommentedOut) {
        categories['commentedPrebuilt']!.add(entry);
      } else if (functionInfo.commentedOut) {
        categories['commented']!.add(entry);
      } else if (totalUses == 0) {
        categories['unused']!.add(entry);
      } else if (internalUses > 0 && externalUses == 0) {
        categories['internalOnly']!.add(entry);
      } else if (internalUses == 0 && externalUses > 0) {
        categories['externalOnly']!.add(entry);
      } else if (internalUses > 0 && externalUses > 0) {
        categories['bothInternalExternal']!.add(entry);
      }
    }

    return categories;
  }

  /// Writes the class analysis section to the report buffer.
  ///
  /// [buffer] is the output buffer for the report.
  /// [categories] is a map of class categories to their entries.
  /// [projectPath] is the root directory of the project.
  static void _writeClassAnalysis(
    StringBuffer buffer,
    Map<String, List<MapEntry<String, ClassInfo>>> categories,
    String projectPath,
  ) {
    buffer
      ..writeln('Class Analysis')
      ..writeln('=' * 14)
      ..writeln();

    const classSections = [
      ('Unused Classes', 'unused', 'unused classes'),
      ('Commented Classes', 'commented', 'commented classes'),
      (
        'Classes Used Only Internally',
        'internalOnly',
        'internally used classes',
      ),
      (
        'Classes Used Only Externally',
        'externalOnly',
        'externally used classes',
      ),
      (
        'Classes Used Both Internally and Externally',
        'bothInternalExternal',
        'internally and externally used classes',
      ),
      ('Mixin Classes', 'mixing', 'mixin classes'),
      ('Enum Classes', 'enum', 'enum classes'),
      ('Extension Classes', 'extension', 'extension classes'),
      ('Typedef Classes', 'typedef', 'typedef classes'),
      ('State Classes', 'stateClass', 'state classes'),
      ('Entry-Point Classes (@pragma)', 'entryPoint', 'entry-point classes'),
    ];

    for (final (title, category, entityType) in classSections) {
      _writeCategoryClassSection(
        buffer,
        title,
        categories[category]!,
        entityType,
        projectPath,
      );
    }
  }

  /// Writes the function analysis section to the report buffer.
  ///
  /// [buffer] is the output buffer for the report.
  /// [categories] is a map of function categories to their entries.
  /// [projectPath] is the root directory of the project.
  static void _writeFunctionAnalysis(
    StringBuffer buffer,
    Map<String, List<MapEntry<String, CodeInfo>>> categories,
    String projectPath,
  ) {
    buffer
      ..writeln('Function Analysis')
      ..writeln('=' * 17)
      ..writeln();

    const functionSections = [
      ('Unused Functions', 'unused', 'unused functions'),
      ('Commented Functions', 'commented', 'commented functions'),
      (
        'Functions Used Only Internally',
        'internalOnly',
        'internally used functions',
      ),
      (
        'Functions Used Only Externally',
        'externalOnly',
        'externally used functions',
      ),
      (
        'Functions Used Both Internally and Externally',
        'bothInternalExternal',
        'internally and externally used functions',
      ),
      (
        'Empty Prebuilt Flutter Functions',
        'emptyPrebuilt',
        'empty prebuilt functions',
      ),
      (
        'Commented Prebuilt Flutter Functions',
        'commentedPrebuilt',
        'commented prebuilt functions',
      ),
      (
        'Entry-Point Functions (@pragma)',
        'entryPoint',
        'entry-point functions',
      ),
    ];

    for (final (title, category, entityType) in functionSections) {
      _writeCategoryFunctionSection(
        buffer,
        title,
        categories[category]!,
        entityType,
        projectPath,
      );
    }
  }

  /// Calculates the percentage of a count relative to a total.
  ///
  /// [count] is the number of items in the category.
  /// [total] is the total number of items.
  /// Returns the percentage as a double, avoiding division by zero.
  static double _calculatePercentage(int count, int total) =>
      (count / (total > 0 ? total : 1)) * 100;

  /// Writes the summary section to the report buffer.
  ///
  /// [buffer] is the output buffer for the report.
  /// [classes] is a map of class names to their [ClassInfo].
  /// [functions] is a map of function names to their [CodeInfo].
  /// [classCategories] is a map of class categories to their entries.
  /// [functionCategories] is a map of function categories to their entries.
  /// [analyzeFunctions] determines whether to include function statistics.
  static void _writeSummary(
    StringBuffer buffer,
    Map<String, ClassInfo> classes,
    Map<String, CodeInfo> functions,
    Map<String, List<MapEntry<String, ClassInfo>>> classCategories,
    Map<String, List<MapEntry<String, CodeInfo>>> functionCategories,
    bool analyzeFunctions,
  ) {
    buffer
      ..writeln('Summary')
      ..writeln('-' * 7)
      ..writeln();

    final totalClasses = classes.length;
    buffer
      ..writeln('Total classes: $totalClasses')
      ..writeln(
        'Unused classes: ${classCategories['unused']!.length} '
        '(${_calculatePercentage(classCategories['unused']!.length, totalClasses).toStringAsFixed(1)}%)',
      )
      ..writeln(
        'Classes used only internally: ${classCategories['internalOnly']!.length} '
        '(${_calculatePercentage(classCategories['internalOnly']!.length, totalClasses).toStringAsFixed(1)}%)',
      )
      ..writeln(
        'Classes used only externally: ${classCategories['externalOnly']!.length} '
        '(${_calculatePercentage(classCategories['externalOnly']!.length, totalClasses).toStringAsFixed(1)}%)',
      )
      ..writeln(
        'Classes used both internally and externally: ${classCategories['bothInternalExternal']!.length} '
        '(${_calculatePercentage(classCategories['bothInternalExternal']!.length, totalClasses).toStringAsFixed(1)}%)',
      )
      ..writeln(
        'Mixin classes: ${classCategories['mixing']!.length} '
        '(${_calculatePercentage(classCategories['mixing']!.length, totalClasses).toStringAsFixed(1)}%)',
      )
      ..writeln(
        'Enum classes: ${classCategories['enum']!.length} '
        '(${_calculatePercentage(classCategories['enum']!.length, totalClasses).toStringAsFixed(1)}%)',
      )
      ..writeln(
        'Extension classes: ${classCategories['extension']!.length} '
        '(${_calculatePercentage(classCategories['extension']!.length, totalClasses).toStringAsFixed(1)}%)',
      )
      ..writeln(
        'State classes: ${classCategories['stateClass']!.length} '
        '(${_calculatePercentage(classCategories['stateClass']!.length, totalClasses).toStringAsFixed(1)}%)',
      )
      ..writeln(
        'Entry-point classes: ${classCategories['entryPoint']!.length} '
        '(${_calculatePercentage(classCategories['entryPoint']!.length, totalClasses).toStringAsFixed(1)}%)',
      );

    if (analyzeFunctions) {
      final totalFunctions = functions.length;
      buffer
        ..writeln()
        ..writeln('Total functions: $totalFunctions')
        ..writeln(
          'Unused functions: ${functionCategories['unused']!.length} '
          '(${_calculatePercentage(functionCategories['unused']!.length, totalFunctions).toStringAsFixed(1)}%)',
        )
        ..writeln(
          'Functions used only internally: ${functionCategories['internalOnly']!.length} '
          '(${_calculatePercentage(functionCategories['internalOnly']!.length, totalFunctions).toStringAsFixed(1)}%)',
        )
        ..writeln(
          'Functions used only externally: ${functionCategories['externalOnly']!.length} '
          '(${_calculatePercentage(functionCategories['externalOnly']!.length, totalFunctions).toStringAsFixed(1)}%)',
        )
        ..writeln(
          'Functions used both internally and externally: ${functionCategories['bothInternalExternal']!.length} '
          '(${_calculatePercentage(functionCategories['bothInternalExternal']!.length, totalFunctions).toStringAsFixed(1)}%)',
        )
        ..writeln(
          'Empty prebuilt Flutter functions: ${functionCategories['emptyPrebuilt']!.length} '
          '(${_calculatePercentage(functionCategories['emptyPrebuilt']!.length, totalFunctions).toStringAsFixed(1)}%)',
        )
        ..writeln(
          'Commented prebuilt Flutter functions: ${functionCategories['commentedPrebuilt']!.length} '
          '(${_calculatePercentage(functionCategories['commentedPrebuilt']!.length, totalFunctions).toStringAsFixed(1)}%)',
        )
        ..writeln(
          'Entry-point functions: ${functionCategories['entryPoint']!.length} '
          '(${_calculatePercentage(functionCategories['entryPoint']!.length, totalFunctions).toStringAsFixed(1)}%)',
        );
    }
  }

  /// Generates the report header with a timestamp and description.
  ///
  /// Returns a formatted header string.
  static String _generateReportHeader() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final timestamp = formatter.format(now);

    return '''
Flutter Code Usage Analysis - $timestamp
${'=' * 50}
This report analyzes class and function usage in a Flutter project.
- Classes and functions are categorized by usage type (e.g., unused, internal, external).
- Entry-point entities (@pragma("vm:entry-point")) and state classes are reported separately.
- Empty or commented prebuilt Flutter functions (e.g., build, initState) are listed separately.
- File paths are relative to the lib/ directory or project root.

''';
  }

  /// Generates a filename for the report based on the current timestamp.
  ///
  /// Returns a filename string in the format `flutter_code_analysis_YYYY-MM-DD_HH-mm-ss.txt`.
  static String _generateFilename() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return 'flutter_code_analysis_${formatter.format(now)}.txt';
  }

  /// Saves the code usage analysis report to a file.
  ///
  /// [classes] is a map of class names to their [ClassInfo].
  /// [functions] is a map of function names to their [CodeInfo].
  /// [outputDirectory] is the directory where the report will be saved.
  /// [projectPath] is the root directory of the project.
  /// [analyzeFunctions] determines whether to include function analysis.
  ///
  /// Throws an [IOException] if the report cannot be saved (e.g., due to permissions).
  static void saveResultsToFile({
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required String outputDirectory,
    required String projectPath,
    required bool analyzeFunctions,
  }) {
    final filename = _generateFilename();
    final filePath = path.join(outputDirectory, filename);
    final buffer = StringBuffer();

    try {
      // Ensure the output directory exists
      final dir = Directory(outputDirectory);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Generate report content
      buffer.write(_generateReportHeader());

      Map<String, List<MapEntry<String, ClassInfo>>> classCategories =
          _categorizeClasses(classes);
      Map<String, List<MapEntry<String, CodeInfo>>> functionCategories =
          analyzeFunctions ? _categorizeFunctions(functions) : {};

      _writeClassAnalysis(buffer, classCategories, projectPath);
      if (analyzeFunctions) {
        _writeFunctionAnalysis(buffer, functionCategories, projectPath);
      }
      _writeSummary(
        buffer,
        classes,
        functions,
        classCategories,
        functionCategories,
        analyzeFunctions,
      );

      // Write to file
      File(filePath).writeAsStringSync(buffer.toString());
      print('Analysis report saved to: $filePath');
    } catch (e, stackTrace) {
      final errorMessage =
          '''
Error saving analysis report to $filePath:
$e
Ensure the output directory ($outputDirectory) exists and you have write permissions.
Stack trace:
$stackTrace
''';
      print(errorMessage);
      rethrow;
    }
  }
}

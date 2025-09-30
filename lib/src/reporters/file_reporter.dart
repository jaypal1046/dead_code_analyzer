import 'dart:io';

import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

/// library dead_code_analyzer.src.reporters.file_reporter;
/// The [FileReporter] class processes class and function information, categorizes them based on usage,
/// and generates a formatted text report. The report includes summaries, detailed sections for classes
/// and functions, and relative file paths for better readability. It adheres to Flutter package guidelines
/// for documentation, error handling, and code style.
///
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
    OutType outType,
  ) {
    switch (outType) {
      case OutType.html:
        buffer.writeln('<div class="category">');
        buffer.writeln('<h3>$title</h3>');
        break;
      case OutType.md:
        buffer.writeln('### $title');
        buffer.writeln();
        break;
      case OutType.txt:
        buffer
          ..writeln(title)
          ..writeln('-' * title.length)
          ..writeln();
    }

    if (entries.isEmpty) {
      if (outType == OutType.html) {
        buffer.writeln('<p class="empty">No $entityType found.</p>');
      } else {
        buffer.writeln('No $entityType found.');
        buffer.writeln();
      }

      if (outType == OutType.html) {
        buffer.writeln('</div>');
      }
      return;
    }

    if (outType == OutType.html) {
      buffer.writeln('<ul class="class-list">');
    }

    for (final entry in entries) {
      final name = entry.key;
      final info = entry.value;
      final internalUses = info.internalUsageCount;
      final externalUses = info.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      final definedIn = _toLibRelativePath(info.definedInFile, projectPath);
      final absolutePath = info.definedInFile; // Keep absolute path for VS Code
      final usageFilesStr = externalUses > 0
          ? ' ${_formatUsageFiles(info.externalUsages, projectPath)}'
          : '';
      final entryPointNote = info.isEntryPoint && totalUses == 0
          ? ' [Used by native code via @pragma("vm:entry-point")]'
          : '';

      switch (outType) {
        case OutType.html:
          buffer.writeln('<li>');
          buffer.writeln('<strong>$name</strong>');
          buffer.writeln('<span class="details">');
          // Create clickable link to open in VS Code
          buffer.writeln(
            '(in <a href="vscode://file/$absolutePath" class="vscode-link"><code>$definedIn</code></a>, ',
          );
          buffer.writeln('internal: $internalUses, ');
          buffer.writeln('external: $externalUses, ');
          buffer.writeln('total: $totalUses)');
          if (usageFilesStr.isNotEmpty) {
            buffer.writeln(usageFilesStr);
          }
          if (entryPointNote.isNotEmpty) {
            buffer.writeln('<span class="entry-point">$entryPointNote</span>');
          }
          buffer.writeln('</span>');
          buffer.writeln('</li>');
          break;
        case OutType.md:
          buffer.writeln(
            '- **$name** (in `$definedIn`, internal: $internalUses, external: $externalUses, total: $totalUses)$usageFilesStr$entryPointNote',
          );
          break;
        case OutType.txt:
          buffer.writeln(
            '- $name (in $definedIn, internal: $internalUses, external: $externalUses, total: $totalUses)$usageFilesStr$entryPointNote',
          );
      }
    }

    switch (outType) {
      case OutType.html:
        buffer.writeln('</ul>');
        buffer.writeln('</div>');
        break;
      case OutType.md:
        buffer.writeln();
      case OutType.txt:
        buffer.writeln();
    }
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
    OutType outType,
  ) {
    switch (outType) {
      case OutType.html:
        buffer.writeln('<div class="category">');
        buffer.writeln('<h3>$title</h3>');
        break;
      case OutType.md:
        buffer.writeln('### $title');
        buffer.writeln();
        break;
      case OutType.txt:
        buffer
          ..writeln(title)
          ..writeln('-' * title.length)
          ..writeln();
    }

    if (entries.isEmpty) {
      if (outType == OutType.html) {
        buffer.writeln('<p class="empty">No $entityType found.</p>');
      } else {
        buffer.writeln('No $entityType found.');
        buffer.writeln();
      }

      if (outType == OutType.html) {
        buffer.writeln('</div>');
      }
      return;
    }

    if (outType == OutType.html) {
      buffer.writeln('<ul class="function-list">');
    }

    for (final entry in entries) {
      final name = entry.key;
      final info = entry.value;

      final internalUses = info.internalUsageCount;
      final externalUses = info.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      final absolutePath = info.definedInFile; // Keep absolute path for VS Code
      final definedIn = _toLibRelativePath(info.definedInFile, projectPath);
      final usageFilesStr = externalUses > 0
          ? ' ${_formatUsageFiles(info.externalUsages, projectPath)}'
          : '';
      final entryPointNote = info.isEntryPoint && totalUses == 0
          ? ' [Used by native code via @pragma]'
          : '';

      switch (outType) {
        case OutType.html:
          buffer.writeln('<li>');
          buffer.writeln('<strong>$name</strong>');
          buffer.writeln('<span class="details">');

          buffer.writeln(
            '(in <a href="vscode://file/$absolutePath" class="vscode-link"><code>$definedIn</code></a>, ',
          );
          buffer.writeln('internal: $internalUses, ');
          buffer.writeln('external: $externalUses, ');
          buffer.writeln('total: $totalUses)');
          if (usageFilesStr.isNotEmpty) {
            buffer.writeln(usageFilesStr);
          }
          if (entryPointNote.isNotEmpty) {
            buffer.writeln('<span class="entry-point">$entryPointNote</span>');
          }
          buffer.writeln('</span>');
          buffer.writeln('</li>');
          break;
        case OutType.md:
          buffer.writeln(
            '- **$name** (in `$definedIn`, internal: $internalUses, external: $externalUses, total: $totalUses)$usageFilesStr$entryPointNote',
          );
          break;
        case OutType.txt:
          buffer.writeln(
            '- $name (in $definedIn, internal: $internalUses, external: $externalUses, total: $totalUses)$usageFilesStr$entryPointNote',
          );
      }
    }

    switch (outType) {
      case OutType.html:
        buffer.writeln('</ul>');
        buffer.writeln('</div>');
        break;
      case OutType.md:
        buffer.writeln();
      case OutType.txt:
        buffer.writeln();
    }
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
    OutType outType,
  ) {
    switch (outType) {
      case OutType.html:
        buffer.writeln('<div class="section">');
        buffer.writeln('<h2>Class Analysis</h2>');
        break;
      case OutType.md:
        buffer.writeln('## Class Analysis');
        buffer.writeln();
        break;
      case OutType.txt:
        buffer
          ..writeln('Class Analysis')
          ..writeln('=' * 14)
          ..writeln();
    }

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
        outType,
      );
    }

    if (outType == OutType.html) {
      buffer.writeln('</div>');
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
    OutType outType,
  ) {
    switch (outType) {
      case OutType.html:
        buffer.writeln('<div class="section">');
        buffer.writeln('<h2>Function Analysis</h2>');
        break;
      case OutType.md:
        buffer.writeln('## Function Analysis');
        buffer.writeln();
        break;
      case OutType.txt:
        buffer
          ..writeln('Function Analysis')
          ..writeln('=' * 17)
          ..writeln();
    }

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
        outType,
      );
    }

    if (outType == OutType.html) {
      buffer.writeln('</div>');
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
    OutType outType,
  ) {
    switch (outType) {
      case OutType.html:
        buffer.writeln('<div class="section summary">');
        buffer.writeln('<h2>Summary</h2>');
        buffer.writeln('<div class="summary-content">');
        buffer.writeln('<h3>Class Statistics</h3>');
        buffer.writeln('<table class="summary-table">');
        buffer.writeln(
          '<thead><tr><th>Metric</th><th>Count</th><th>Percentage</th></tr></thead>',
        );
        buffer.writeln('<tbody>');
        break;
      case OutType.md:
        buffer.writeln('## Summary');
        buffer.writeln();
        buffer.writeln('### Class Statistics');
        buffer.writeln();
        break;
      case OutType.txt:
        buffer
          ..writeln('Summary')
          ..writeln('-' * 7)
          ..writeln();
    }

    final totalClasses = classes.length;

    final classStats = [
      ('Total classes', totalClasses, totalClasses),
      ('Unused classes', classCategories['unused']?.length ?? 0, totalClasses),
      (
        'Classes used only internally',
        classCategories['internalOnly']?.length ?? 0,
        totalClasses,
      ),
      (
        'Classes used only externally',
        classCategories['externalOnly']?.length ?? 0,
        totalClasses,
      ),
      (
        'Classes used both internally and externally',
        classCategories['bothInternalExternal']?.length ?? 0,
        totalClasses,
      ),
      ('Mixin classes', classCategories['mixing']?.length ?? 0, totalClasses),
      ('Enum classes', classCategories['enum']?.length ?? 0, totalClasses),
      (
        'Extension classes',
        classCategories['extension']?.length ?? 0,
        totalClasses,
      ),
      (
        'State classes',
        classCategories['stateClass']?.length ?? 0,
        totalClasses,
      ),
      (
        'Entry-point classes',
        classCategories['entryPoint']?.length ?? 0,
        totalClasses,
      ),
    ];

    for (final (label, count, total) in classStats) {
      final percentage = total > 0
          ? _calculatePercentage(count, total).toStringAsFixed(1)
          : '0.0';

      switch (outType) {
        case OutType.html:
          if (label == 'Total classes') {
            buffer.writeln(
              '<tr class="total-row"><td><strong>$label</strong></td><td><strong>$count</strong></td><td>-</td></tr>',
            );
          } else {
            buffer.writeln(
              '<tr><td>$label</td><td>$count</td><td>$percentage%</td></tr>',
            );
          }
          break;
        case OutType.md:
          if (label == 'Total classes') {
            buffer.writeln('- **$label:** $count');
          } else {
            buffer.writeln('- **$label:** $count ($percentage%)');
          }
          break;
        case OutType.txt:
          if (label == 'Total classes') {
            buffer.writeln('$label: $count');
          } else {
            buffer.writeln('$label: $count ($percentage%)');
          }
      }
    }

    if (outType == OutType.html) {
      buffer.writeln('</tbody>');
      buffer.writeln('</table>');
    }

    if (analyzeFunctions) {
      final totalFunctions = functions.length;

      switch (outType) {
        case OutType.html:
          buffer.writeln('<h3>Function Statistics</h3>');
          buffer.writeln('<table class="summary-table">');
          buffer.writeln(
            '<thead><tr><th>Metric</th><th>Count</th><th>Percentage</th></tr></thead>',
          );
          buffer.writeln('<tbody>');
          break;
        case OutType.md:
          buffer.writeln();
          buffer.writeln('### Function Statistics');
          buffer.writeln();
          break;
        case OutType.txt:
          buffer.writeln();
      }

      final functionStats = [
        ('Total functions', totalFunctions, totalFunctions),
        (
          'Unused functions',
          functionCategories['unused']?.length ?? 0,
          totalFunctions,
        ),
        (
          'Functions used only internally',
          functionCategories['internalOnly']?.length ?? 0,
          totalFunctions,
        ),
        (
          'Functions used only externally',
          functionCategories['externalOnly']?.length ?? 0,
          totalFunctions,
        ),
        (
          'Functions used both internally and externally',
          functionCategories['bothInternalExternal']?.length ?? 0,
          totalFunctions,
        ),
        (
          'Empty prebuilt Flutter functions',
          functionCategories['emptyPrebuilt']?.length ?? 0,
          totalFunctions,
        ),
        (
          'Commented prebuilt Flutter functions',
          functionCategories['commentedPrebuilt']?.length ?? 0,
          totalFunctions,
        ),
        (
          'Entry-point functions',
          functionCategories['entryPoint']?.length ?? 0,
          totalFunctions,
        ),
      ];

      for (final (label, count, total) in functionStats) {
        final percentage = total > 0
            ? _calculatePercentage(count, total).toStringAsFixed(1)
            : '0.0';

        switch (outType) {
          case OutType.html:
            if (label == 'Total functions') {
              buffer.writeln(
                '<tr class="total-row"><td><strong>$label</strong></td><td><strong>$count</strong></td><td>-</td></tr>',
              );
            } else {
              buffer.writeln(
                '<tr><td>$label</td><td>$count</td><td>$percentage%</td></tr>',
              );
            }
            break;
          case OutType.md:
            if (label == 'Total functions') {
              buffer.writeln('- **$label:** $count');
            } else {
              buffer.writeln('- **$label:** $count ($percentage%)');
            }
            break;
          case OutType.txt:
            if (label == 'Total functions') {
              buffer.writeln('$label: $count');
            } else {
              buffer.writeln('$label: $count ($percentage%)');
            }
        }
      }

      if (outType == OutType.html) {
        buffer.writeln('</tbody>');
        buffer.writeln('</table>');
      }
    }

    if (outType == OutType.html) {
      buffer.writeln('</div>'); // Close summary-content
      buffer.writeln('</div>'); // Close section summary
      buffer.writeln('</body></html>');
    }
  }

  /// Generates the report header with a timestamp and description.
  ///
  /// Returns a formatted header string.
  static String _generateReportHeader(OutType outType) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final timestamp = formatter.format(now);

    switch (outType) {
      case OutType.html:
        return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Flutter Code Usage Analysis</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background-color: #2196F3;
            color: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        h1 { margin: 0 0 10px 0; }
        .timestamp { opacity: 0.9; font-size: 0.9em; }
        .description {
            background-color: white;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 4px solid #2196F3;
        }
        ul { margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Flutter Code Usage Analysis</h1>
        <div class="timestamp">$timestamp</div>
    </div>
    <div class="description">
        <p><strong>This report analyzes class and function usage in a Flutter project.</strong></p>
        <ul>
            <li>Classes and functions are categorized by usage type (e.g., unused, internal, external).</li>
            <li>Entry-point entities (@pragma("vm:entry-point")) and state classes are reported separately.</li>
            <li>Empty or commented prebuilt Flutter functions (e.g., build, initState) are listed separately.</li>
            <li>File paths are relative to the lib/ directory or project root.</li>
        </ul>
    </div>
''';

      case OutType.md:
        return '''
# Flutter Code Usage Analysis

**Generated:** $timestamp

---

## Overview

This report analyzes class and function usage in a Flutter project.

- Classes and functions are categorized by usage type (e.g., unused, internal, external).
- Entry-point entities (@pragma("vm:entry-point")) and state classes are reported separately.
- Empty or commented prebuilt Flutter functions (e.g., build, initState) are listed separately.
- File paths are relative to the lib/ directory or project root.

---

''';

      case OutType.txt:
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
  }

  /// Generates a filename for the report based on the current timestamp.
  ///
  /// Returns a filename string in the format `flutter_code_analysis_YYYY-MM-DD_HH-mm-ss.txt`.
  static String _generateFilename(OutType outType) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    if (outType == OutType.html) {
      return 'flutter_code_analysis_${formatter.format(now)}.html';
    } else if (outType == OutType.md) {
      return 'flutter_code_analysis_${formatter.format(now)}.md';
    }
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
    required OutType outType,
  }) {
    final filename = _generateFilename(
      outType,
    ); // Pass outType for correct extension
    final filePath = path.join(outputDirectory, filename);
    final buffer = StringBuffer();

    try {
      // Ensure the output directory exists
      final dir = Directory(outputDirectory);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Generate report content based on output type

      buffer.write(_generateReportHeader(outType));

      Map<String, List<MapEntry<String, ClassInfo>>> classCategories =
          _categorizeClasses(classes);
      Map<String, List<MapEntry<String, CodeInfo>>> functionCategories =
          analyzeFunctions ? _categorizeFunctions(functions) : {};

      // Write analysis sections

      _writeClassAnalysis(buffer, classCategories, projectPath, outType);
      if (analyzeFunctions) {
        _writeFunctionAnalysis(
          buffer,
          functionCategories,
          projectPath,
          outType,
        );
      }
      _writeSummary(
        buffer,
        classes,
        functions,
        classCategories,
        functionCategories,
        analyzeFunctions,
        outType,
      );

      // Write to file
      File(filePath).writeAsStringSync(buffer.toString());
      // Print a clickable file URI for HTML reports, otherwise just the path
      if (outType == OutType.html) {
        final uri = Uri.file(filePath).toString();

        print('Analysis report saved to: $uri');
        print('Opening in browser...');
        _openInBrowser(filePath);
      } else {
        print('Analysis report saved to: $filePath');
      }
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

  static void _openInBrowser(String filePath) {
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', '', filePath]);
      } else if (Platform.isMacOS) {
        Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [filePath]);
      }
      print('Report opened in browser successfully.');
    } catch (e) {
      print('Error opening browser: $e');
      print('Please open manually: $filePath');
    }
  }
}

enum OutType { txt, html, md }

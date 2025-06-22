import 'dart:io';
import 'package:dead_code_analyzer/src/models/class_info.dart';
import 'package:dead_code_analyzer/src/models/code_info.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class FileReporter {
  // Helper function to convert absolute path to lib-relative path
  static String toLibRelativePath(String absolutePath, String projectPath) {
    final libPath = path.join(projectPath, 'lib');
    if (absolutePath.startsWith(libPath)) {
      return path.relative(absolutePath, from: libPath);
    }
    return path.relative(absolutePath, from: projectPath);
  }

// Helper function to format usage files
  static String formatUsageFiles(
      Map<String, int> externalUsages, String projectPath) {
    final usageFiles = externalUsages.entries.map((entry) {
      final fileName = toLibRelativePath(entry.key, projectPath);
      final count = entry.value;
      return '$fileName ($count references)';
    }).toList();
    return usageFiles.toString();
  }

// Helper function to write category section for classes
  static void writeCategoryClassSection(
    StringBuffer buffer,
    String title,
    List<MapEntry<String, ClassInfo>> entries,
    String entityType,
    String projectPath,
  ) {
    buffer.writeln(title);
    buffer.writeln('-' * 30);
    int count = 0;

    for (final entry in entries) {
      final name = entry.key;
      final info = entry.value;
      final internalUses = info.internalUsageCount;
      final externalUses = info.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      count++;

      final definedIn = toLibRelativePath(info.definedInFile, projectPath);
      final usageFilesStr = externalUses > 0
          ? ' ${formatUsageFiles(info.externalUsages, projectPath)}'
          : '';
      final entryPointNote = info.isEntryPoint && totalUses == 0
          ? ' [Used by native code via @pragma("vm:entry-point")]'
          : '';

      buffer.writeln(
          ' - $name (in $definedIn, internal references: $internalUses, external references: $externalUses, total: $totalUses)$usageFilesStr$entryPointNote');
    }

    if (count == 0) {
      buffer.writeln('No $entityType found.');
    }
    buffer.writeln('');
  }

// Helper function to write category section for functions
  static void writeCategoryFunctionSection(
    StringBuffer buffer,
    String title,
    List<MapEntry<String, CodeInfo>> entries,
    String entityType,
    String projectPath,
  ) {
    buffer.writeln(title);
    buffer.writeln('-' * 30);
    int count = 0;

    for (final entry in entries) {
      final name = entry.key;
      final info = entry.value;
      final internalUses = info.internalUsageCount;
      final externalUses = info.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      count++;

      final definedIn = toLibRelativePath(info.definedInFile, projectPath);
      final usageFilesStr = externalUses > 0
          ? ' ${formatUsageFiles(info.externalUsages, projectPath)}'
          : '';
      final entryPointNote = info.isEntryPoint && totalUses == 0
          ? ' [Used by native code via @pragma]'
          : '';

      buffer.writeln(
          ' - $name (in $definedIn, internal references: $internalUses, external references: $externalUses, total: $totalUses)$usageFilesStr$entryPointNote');
    }

    if (count == 0) {
      buffer.writeln('No $entityType found.');
    }
    buffer.writeln('');
  }

// Function to categorize classes
  static Map<String, List<MapEntry<String, ClassInfo>>> categorizeClasses(
      Map<String, ClassInfo> classes) {
    final sortedClasses = classes.entries.toList()
      ..sort((a, b) {
        final externalComparison =
            a.value.totalExternalUsages.compareTo(b.value.totalExternalUsages);
        if (externalComparison != 0) return externalComparison;
        return a.value.totalUsages.compareTo(b.value.totalUsages);
      });

    final categories = <String, List<MapEntry<String, ClassInfo>>>{
      'unused': <MapEntry<String, ClassInfo>>[],
      'internalOnly': <MapEntry<String, ClassInfo>>[],
      'externalOnly': <MapEntry<String, ClassInfo>>[],
      'bothInternalExternal': <MapEntry<String, ClassInfo>>[],
      'stateClass': <MapEntry<String, ClassInfo>>[],
      'entryPoint': <MapEntry<String, ClassInfo>>[],
      'commented': <MapEntry<String, ClassInfo>>[],
      'mixing': <MapEntry<String, ClassInfo>>[],
      'enum': <MapEntry<String, ClassInfo>>[],
      'extension': <MapEntry<String, ClassInfo>>[],
      'typedef': <MapEntry<String, ClassInfo>>[],
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

// Function to categorize functions
  static Map<String, List<MapEntry<String, CodeInfo>>> categorizeFunctions(
      Map<String, CodeInfo> functions) {
    final sortedFunctions = functions.entries.toList()
      ..sort((a, b) {
        final externalComparison =
            a.value.totalExternalUsages.compareTo(b.value.totalExternalUsages);
        if (externalComparison != 0) return externalComparison;
        return a.value.totalUsages.compareTo(b.value.totalUsages);
      });

    final categories = <String, List<MapEntry<String, CodeInfo>>>{
      'unused': <MapEntry<String, CodeInfo>>[],
      'internalOnly': <MapEntry<String, CodeInfo>>[],
      'externalOnly': <MapEntry<String, CodeInfo>>[],
      'bothInternalExternal': <MapEntry<String, CodeInfo>>[],
      'emptyPrebuilt': <MapEntry<String, CodeInfo>>[],
      'entryPoint': <MapEntry<String, CodeInfo>>[],
      'commented': <MapEntry<String, CodeInfo>>[],
      'commentedPrebuilt': <MapEntry<String, CodeInfo>>[],
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
        continue; // Skip non-empty prebuilt functions
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

// Function to write class analysis section
  static void writeClassAnalysis(
    StringBuffer buffer,
    Map<String, List<MapEntry<String, ClassInfo>>> categories,
    String projectPath,
  ) {
    buffer.writeln('Class Analysis');
    buffer.writeln('=' * 30);

    writeCategoryClassSection(buffer, 'Unused Classes', categories['unused']!,
        'unused_classes', projectPath);
    writeCategoryClassSection(buffer, 'Commented Classes',
        categories['commented']!, 'commented_classes', projectPath);
    writeCategoryClassSection(
        buffer,
        'Classes Used Only Internally',
        categories['internalOnly']!,
        'classes_used_only_internally',
        projectPath);
    writeCategoryClassSection(
        buffer,
        'Classes Used Only Externally',
        categories['externalOnly']!,
        'classes_used_only_externally',
        projectPath);
    writeCategoryClassSection(
        buffer,
        'Classes Used Both Internally and Externally',
        categories['bothInternalExternal']!,
        'classes_used_both',
        projectPath);
    writeCategoryClassSection(buffer, 'Mixing Classes', categories['mixing']!,
        'mixing_classes', projectPath);
    writeCategoryClassSection(buffer, 'Enum Classes', categories['enum']!,
        'enum_classes', projectPath);
    writeCategoryClassSection(buffer, 'Extension Classes',
        categories['extension']!, 'extension_classes', projectPath);
    writeCategoryClassSection(buffer, 'Typedef Classes', categories['typedef']!,
        'typedef_classes', projectPath);
    writeCategoryClassSection(buffer, 'State Classes',
        categories['stateClass']!, 'state_classes', projectPath);
    writeCategoryClassSection(
        buffer,
        '@pragma Classes: Hints for Dart compiler/runtime optimizations.',
        categories['entryPoint']!,
        'entry_point_classes',
        projectPath);
  }

// Function to write function analysis section
  static void writeFunctionAnalysis(
    StringBuffer buffer,
    Map<String, List<MapEntry<String, CodeInfo>>> categories,
    String projectPath,
  ) {
    buffer.writeln('Function Analysis');
    buffer.writeln('=' * 30);

    writeCategoryFunctionSection(buffer, 'Unused Functions',
        categories['unused']!, 'unused functions', projectPath);
    writeCategoryFunctionSection(buffer, 'Commented Functions',
        categories['commented']!, 'commented functions', projectPath);
    writeCategoryFunctionSection(
        buffer,
        'Functions Used Only Internally',
        categories['internalOnly']!,
        'functions used only internally',
        projectPath);
    writeCategoryFunctionSection(
        buffer,
        'Functions Used Only Externally',
        categories['externalOnly']!,
        'functions used only externally',
        projectPath);
    writeCategoryFunctionSection(
        buffer,
        'Functions Used Both Internally and Externally',
        categories['bothInternalExternal']!,
        'functions used both internally and externally',
        projectPath);
    writeCategoryFunctionSection(
        buffer,
        'Empty Prebuilt Flutter Functions',
        categories['emptyPrebuilt']!,
        'empty prebuilt Flutter functions',
        projectPath);
    writeCategoryFunctionSection(
        buffer,
        'Pre build element Commented',
        categories['commentedPrebuilt']!,
        'Pre build element Commented',
        projectPath);
    writeCategoryFunctionSection(buffer, 'Entry-Point Functions (@pragma)',
        categories['entryPoint']!, 'entry-point functions', projectPath);
  }

// Function to calculate percentage
  static double calculatePercentage(int count, int total) {
    return count / (total > 0 ? total : 1) * 100;
  }

// Function to write summary section
  static void writeSummary(
    StringBuffer buffer,
    Map<String, ClassInfo> classes,
    Map<String, CodeInfo> functions,
    Map<String, List<MapEntry<String, ClassInfo>>> classCategories,
    Map<String, List<MapEntry<String, CodeInfo>>> functionCategories,
    bool analyzeFunctions,
  ) {
    buffer.writeln('Summary');
    buffer.writeln('-' * 30);

    final totalClasses = classes.length;
    buffer.writeln('Total classes: $totalClasses');
    buffer.writeln(
        'Unused classes: ${classCategories['unused']!.length} (${calculatePercentage(classCategories['unused']!.length, totalClasses).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Classes used only internally: ${classCategories['internalOnly']!.length} (${calculatePercentage(classCategories['internalOnly']!.length, totalClasses).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Classes used only externally: ${classCategories['externalOnly']!.length} (${calculatePercentage(classCategories['externalOnly']!.length, totalClasses).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Classes used both internally and externally: ${classCategories['bothInternalExternal']!.length} (${calculatePercentage(classCategories['bothInternalExternal']!.length, totalClasses).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Mixin classed: ${classCategories['mixing']!.length} (${calculatePercentage(classCategories['mixing']!.length, totalClasses).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Enum classes: ${classCategories['enum']!.length} (${calculatePercentage(classCategories['enum']!.length, totalClasses).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Extension classes: ${classCategories['extension']!.length} (${calculatePercentage(classCategories['extension']!.length, totalClasses).toStringAsFixed(1)}%)');
    buffer.writeln(
        'State classes: ${classCategories['stateClass']!.length} (${calculatePercentage(classCategories['stateClass']!.length, totalClasses).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Entry-point classes: ${classCategories['entryPoint']!.length} (${calculatePercentage(classCategories['entryPoint']!.length, totalClasses).toStringAsFixed(1)}%)');

    if (analyzeFunctions) {
      final totalFunctions = functions.length;
      buffer.writeln('Total functions: $totalFunctions');
      buffer.writeln(
          'Unused functions: ${functionCategories['unused']!.length} (${calculatePercentage(functionCategories['unused']!.length, totalFunctions).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Functions used only internally: ${functionCategories['internalOnly']!.length} (${calculatePercentage(functionCategories['internalOnly']!.length, totalFunctions).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Functions used only externally: ${functionCategories['externalOnly']!.length} (${calculatePercentage(functionCategories['externalOnly']!.length, totalFunctions).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Functions used both internally and externally: ${functionCategories['bothInternalExternal']!.length} (${calculatePercentage(functionCategories['bothInternalExternal']!.length, totalFunctions).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Empty prebuilt Flutter functions: ${functionCategories['emptyPrebuilt']!.length} (${calculatePercentage(functionCategories['emptyPrebuilt']!.length, totalFunctions).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Commented prebuilt Flutter functions: ${functionCategories['commentedPrebuilt']!.length} (${calculatePercentage(functionCategories['commentedPrebuilt']!.length, totalFunctions).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Entry-point functions: ${functionCategories['entryPoint']!.length} (${calculatePercentage(functionCategories['entryPoint']!.length, totalFunctions).toStringAsFixed(1)}%)');
    }
  }

// Function to generate report header
  static String generateReportHeader() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');

    final buffer = StringBuffer();
    buffer.writeln('Flutter Code Usage Analysis - ${formatter.format(now)}');
    buffer.writeln('=' * 50);
    buffer.writeln(
        'This report lists classes and functions (if analyzed) by usage type. Entry-point entities (@pragma("vm:entry-point")) and state classes are reported separately. Empty prebuilt Flutter functions (e.g., build, initState) are listed separately. File paths are relative to the lib/ directory or project root.');
    buffer.writeln('');

    return buffer.toString();
  }

// Function to generate filename with timestamp
  static String generateFilename() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    final timestamp = formatter.format(now);
    return 'flutter_code_analysis_$timestamp.txt';
  }

// Main refactored function
  static void saveResultsToFile({
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required String outputDir,
    required String projectPath,
    required bool analyzeFunctions,
  }) {
    try {
      final filename = generateFilename();
      final filePath = path.join(outputDir, filename);
      final buffer = StringBuffer();

      // Add header
      buffer.write(generateReportHeader());

      // Categorize classes and functions
      final classCategories = categorizeClasses(classes);
      final functionCategories = analyzeFunctions
          ? categorizeFunctions(functions)
          : <String, List<MapEntry<String, CodeInfo>>>{};

      // Write class analysis
      writeClassAnalysis(buffer, classCategories, projectPath);

      // Write function analysis if enabled
      if (analyzeFunctions) {
        writeFunctionAnalysis(buffer, functionCategories, projectPath);
      }

      // Write summary
      writeSummary(buffer, classes, functions, classCategories,
          functionCategories, analyzeFunctions);

      // Save to file
      final file = File(filePath);
      file.writeAsStringSync(buffer.toString());
      print('\nAnalysis report saved to: $filePath');
    } catch (e) {
      print(
          '\nError saving analysis report: $e. Ensure you have write permissions for $outputDir.');
    }
  }
}

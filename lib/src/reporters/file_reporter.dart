import 'dart:io';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

void saveResultsToFile(
    {required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required String outputDir,
    required String projectPath,
    required bool analyzeFunctions}) {
  try {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    final timestamp = formatter.format(now);
    final filename = 'flutter_code_analysis_$timestamp.txt';
    final filePath = path.join(outputDir, filename);

    final buffer = StringBuffer();
    buffer.writeln('Flutter Code Usage Analysis - ${formatter.format(now)}');
    buffer.writeln('=' * 50);
    buffer.writeln(
        'This report lists classes and functions (if analyzed) by usage type. Entry-point entities (@pragma("vm:entry-point")) and state classes are reported separately. Empty prebuilt Flutter functions (e.g., build, initState) are listed separately. File paths are relative to the lib/ directory or project root.');
    buffer.writeln('');

    // Helper function to convert absolute path to lib-relative path
    String toLibRelativePath(String absolutePath, String projectPath) {
      final libPath = path.join(projectPath, 'lib');
      if (absolutePath.startsWith(libPath)) {
        return path.relative(absolutePath, from: libPath);
      }
      return path.relative(absolutePath, from: projectPath);
    }

    // Helper function to write category section
    void writeCategoryClassSection(String title,
        List<MapEntry<String, ClassInfo>> entries, String entityType) {
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
        final usageFiles = info.externalUsageFiles.map((filePath) {
          final fileName = toLibRelativePath(filePath, projectPath);
          final count = info.externalUsages[filePath] ?? 0;
          return '$fileName ($count references)';
        }).toList();
        final usageFilesStr = usageFiles.toString();
        if (entityType == "commented_classes") {
          buffer.writeln(
              ' - $name (in $definedIn, internal references: $internalUses, external references: $externalUses, total: $totalUses)${externalUses > 0 ? ' $usageFilesStr' : ''}${info.isEntryPoint && totalUses == 0 ? ' [Used by native code via @pragma("vm:entry-point")]' : ''}');
        } else {
          buffer.writeln(
              ' - $name (in $definedIn, internal references: $internalUses, external references: $externalUses, total: $totalUses)${externalUses > 0 ? ' $usageFilesStr' : ''}${info.isEntryPoint && totalUses == 0 ? ' [Used by native code via @pragma("vm:entry-point")]' : ''}');
        }
      }
      if (count == 0) {
        buffer.writeln('No $entityType found.');
      }
      buffer.writeln('');
    }

    // Helper function to write category section
    void writeCategoryFunctionSection(String title,
        List<MapEntry<String, CodeInfo>> entries, String entityType) {
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
        final usageFiles = info.externalUsageFiles.map((filePath) {
          final fileName = toLibRelativePath(filePath, projectPath);
          final count = info.externalUsages[filePath] ?? 0;
          return '$fileName ($count references)';
        }).toList();
        final usageFilesStr = usageFiles.toString();
        buffer.writeln(
            ' - $name (in $definedIn, internal references: $internalUses, external references: $externalUses, total: $totalUses)${externalUses > 0 ? ' $usageFilesStr' : ''}${info.isEntryPoint && totalUses == 0 ? ' [Used by native code via @pragma]' : ''}');
      }
      if (count == 0) {
        buffer.writeln('No $entityType found.');
      }
      buffer.writeln('');
    }

    // Process classes
    final sortedClasses = classes.entries.toList()
      ..sort((a, b) {
        final externalComparison =
            a.value.totalExternalUsages.compareTo(b.value.totalExternalUsages);
        if (externalComparison != 0) return externalComparison;
        return a.value.totalUsages.compareTo(b.value.totalUsages);
      });

    final unusedClasses = <MapEntry<String, ClassInfo>>[];
    final internalOnlyClasses = <MapEntry<String, ClassInfo>>[];
    final externalOnlyClasses = <MapEntry<String, ClassInfo>>[];
    final bothInternalExternalClasses = <MapEntry<String, ClassInfo>>[];
    final stateClassEntries = <MapEntry<String, ClassInfo>>[];
    final entryPointClassEntries = <MapEntry<String, ClassInfo>>[];
    final commentedClasses = <MapEntry<String, ClassInfo>>[];
    final mixingClasses = <MapEntry<String, ClassInfo>>[];
    final enumClasses = <MapEntry<String, ClassInfo>>[];
    final extensionClasses = <MapEntry<String, ClassInfo>>[];
    final typedefClasses = <MapEntry<String, ClassInfo>>[];

    for (final entry in sortedClasses) {
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      if (classInfo.commentedOut) {
        commentedClasses.add(entry);
      } else if (classInfo.isEntryPoint) {
        entryPointClassEntries.add(entry);
      } else if (classInfo.type == 'state_class') {
        stateClassEntries.add(entry);
      } else if (totalUses == 0) {
        unusedClasses.add(entry);
      } else if (classInfo.type == 'enum') {
        enumClasses.add(entry);
      } else if (classInfo.type == 'mixin' || classInfo.type == 'mixin_class') {
        mixingClasses.add(entry);
      } else if (classInfo.type == 'extension') {
        extensionClasses.add(entry);
      } else if (classInfo.type == 'typedef') {
        typedefClasses.add(entry);
      } else if (internalUses > 0 && externalUses == 0) {
        internalOnlyClasses.add(entry);
      } else if (internalUses == 0 && externalUses > 0) {
        externalOnlyClasses.add(entry);
      } else if (internalUses > 0 && externalUses > 0) {
        bothInternalExternalClasses.add(entry);
      }
    }

    buffer.writeln('Class Analysis');
    buffer.writeln('=' * 30);
    writeCategoryClassSection(
        'Unused Classes', unusedClasses, 'unused_classes');
    writeCategoryClassSection(
        'Commented Classes', commentedClasses, 'commented_classes');
    writeCategoryClassSection('Classes Used Only Internally',
        internalOnlyClasses, 'classes_used_only_internally');
    writeCategoryClassSection('Classes Used Only Externally',
        externalOnlyClasses, 'classes_used_only_externally');
    writeCategoryClassSection('Classes Used Both Internally and Externally',
        bothInternalExternalClasses, 'classes_used_both');
    writeCategoryClassSection(
        'Mixing Classes', mixingClasses, 'mixing_classes');
    writeCategoryClassSection('Enum Classes', enumClasses, 'enum_classes');
    writeCategoryClassSection(
        'Extension Classes', extensionClasses, 'extension_classes');
    writeCategoryClassSection(
        'Typedef Classes', typedefClasses, 'typedef_classes');
    writeCategoryClassSection(
        'State Classes', stateClassEntries, 'state_classes');
    writeCategoryClassSection(
        '@pragma Classes: Hints for Dart compiler/runtime optimizations.',
        entryPointClassEntries,
        'entry_point_classes');

    // Declare function lists outside the if block
    final unusedFunctions = <MapEntry<String, CodeInfo>>[];
    final internalOnlyFunctions = <MapEntry<String, CodeInfo>>[];
    final externalOnlyFunctions = <MapEntry<String, CodeInfo>>[];
    final bothInternalExternalFunctions = <MapEntry<String, CodeInfo>>[];
    final emptyPrebuiltFunctionEntries = <MapEntry<String, CodeInfo>>[];
    final entryPointFunctionEntries = <MapEntry<String, CodeInfo>>[];
    final commentedFunctions = <MapEntry<String, CodeInfo>>[];
    final commentedPrebuildFunctions = <MapEntry<String, CodeInfo>>[];

    // Process functions (if enabled)
    if (analyzeFunctions) {
      final sortedFunctions = functions.entries.toList()
        ..sort((a, b) {
          final externalComparison = a.value.totalExternalUsages
              .compareTo(b.value.totalExternalUsages);
          if (externalComparison != 0) return externalComparison;
          return a.value.totalUsages.compareTo(b.value.totalUsages);
        });

      for (final entry in sortedFunctions) {
        final functionInfo = entry.value;
        final internalUses = functionInfo.internalUsageCount;
        final externalUses = functionInfo.totalExternalUsages;
        final totalUses = internalUses + externalUses;

        if (functionInfo.isPrebuiltFlutter) {
          if (functionInfo.isEmpty) {
            emptyPrebuiltFunctionEntries.add(entry);
          }
          continue; // Skip non-empty prebuilt functions
        }

        if (functionInfo.isEntryPoint) {
          entryPointFunctionEntries.add(entry);
        } else if (functionInfo.isPrebuiltFlutterCommentedOut) {
          commentedPrebuildFunctions.add(entry);
        } else if (functionInfo.commentedOut) {
          commentedFunctions.add(entry);
        } else if (totalUses == 0) {
          unusedFunctions.add(entry);
        } else if (internalUses > 0 && externalUses == 0) {
          internalOnlyFunctions.add(entry);
        } else if (internalUses == 0 && externalUses > 0) {
          externalOnlyFunctions.add(entry);
        } else if (internalUses > 0 && externalUses > 0) {
          bothInternalExternalFunctions.add(entry);
        }
      }

      buffer.writeln('Function Analysis');
      buffer.writeln('=' * 30);
      writeCategoryFunctionSection(
          'Unused Functions', unusedFunctions, 'unused functions');
      writeCategoryFunctionSection(
          'Commented Functions', commentedFunctions, 'commented functions');
      writeCategoryFunctionSection('Functions Used Only Internally',
          internalOnlyFunctions, 'functions used only internally');
      writeCategoryFunctionSection('Functions Used Only Externally',
          externalOnlyFunctions, 'functions used only externally');
      writeCategoryFunctionSection(
          'Functions Used Both Internally and Externally',
          bothInternalExternalFunctions,
          'functions used both internally and externally');
      writeCategoryFunctionSection('Empty Prebuilt Flutter Functions',
          emptyPrebuiltFunctionEntries, 'empty prebuilt Flutter functions');
      writeCategoryFunctionSection('Pre build element Commented',
          commentedPrebuildFunctions, "Pre build element Commented");
      writeCategoryFunctionSection('Entry-Point Functions (@pragma)',
          entryPointFunctionEntries, 'entry-point functions');
    }

    // Summary
    buffer.writeln('Summary');
    buffer.writeln('-' * 30);
    buffer.writeln('Total classes: ${classes.length}');
    buffer.writeln(
        'Unused classes: ${unusedClasses.length} (${(unusedClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Classes used only internally: ${internalOnlyClasses.length} (${(internalOnlyClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Classes used only externally: ${externalOnlyClasses.length} (${(externalOnlyClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Classes used both internally and externally: ${bothInternalExternalClasses.length} (${(bothInternalExternalClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Mixin classed: ${mixingClasses.length} (${(mixingClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Enum classes: ${enumClasses.length} (${(enumClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Extension classes: ${extensionClasses.length} (${(extensionClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'State classes: ${stateClassEntries.length} (${(stateClassEntries.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Entry-point classes: ${entryPointClassEntries.length} (${(entryPointClassEntries.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
    if (analyzeFunctions) {
      buffer.writeln('Total functions: ${functions.length}');
      buffer.writeln(
          'Unused functions: ${unusedFunctions.length} (${(unusedFunctions.length / (functions.isNotEmpty ? functions.length : 1) * 100).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Functions used only internally: ${internalOnlyFunctions.length} (${(internalOnlyFunctions.length / (functions.isNotEmpty ? functions.length : 1) * 100).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Functions used only externally: ${externalOnlyFunctions.length} (${(externalOnlyFunctions.length / (functions.isNotEmpty ? functions.length : 1) * 100).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Functions used both internally and externally: ${bothInternalExternalFunctions.length} (${(bothInternalExternalFunctions.length / (functions.isNotEmpty ? functions.length : 1) * 100).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Empty prebuilt Flutter functions: ${emptyPrebuiltFunctionEntries.length} (${(emptyPrebuiltFunctionEntries.length / (functions.isNotEmpty ? functions.length : 1) * 100).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Commented prebuilt Flutter functions: ${commentedPrebuildFunctions.length} (${(commentedPrebuildFunctions.length / (functions.isNotEmpty ? functions.length : 1) * 100).toStringAsFixed(1)}%)');
      buffer.writeln(
          'Entry-point functions: ${entryPointFunctionEntries.length} (${(entryPointFunctionEntries.length / (functions.isNotEmpty ? functions.length : 1) * 100).toStringAsFixed(1)}%)');
    }

    final file = File(filePath);
    file.writeAsStringSync(buffer.toString());
    print('\nAnalysis report saved to: $filePath');
  } catch (e) {
    print(
        '\nError saving analysis report: $e. Ensure you have write permissions for $outputDir.');
  }
}

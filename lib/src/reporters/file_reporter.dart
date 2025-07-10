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
    final filename = 'flutter_code_analysis_$timestamp.md';
    final filePath = path.join(outputDir, filename);

    final buffer = StringBuffer();
    buffer.writeln('# Flutter Code Usage Analysis - ${formatter.format(now)}');
    buffer.writeln('=' * 50);
    buffer.writeln(
        'This report lists classes and functions (if analyzed) by usage type.'
        'Entry-point entities (@pragma("vm:entry-point")) and state classes are reported separately.'
        'Empty prebuilt Flutter functions (e.g., build, initState) are listed separately.'
        'File paths are relative to the lib/ directory or project root.');
    buffer.writeln('');
    // Summary badges and table
    final summaryUnusedCount = classes.values
        .where((c) => c.totalUsages == 0 && !c.commentedOut && !c.isEntryPoint)
        .length;
    final summaryInternalCount = classes.values
        .where((c) => c.internalUsageCount > 0 && c.totalExternalUsages == 0)
        .length;
    final summaryExternalCount = classes.values
        .where((c) => c.internalUsageCount == 0 && c.totalExternalUsages > 0)
        .length;
    final summaryBothCount = classes.values
        .where((c) => c.internalUsageCount > 0 && c.totalExternalUsages > 0)
        .length;

    // Badges
    buffer.writeln(
        '![❌ Unused](https://img.shields.io/badge/Unused_$summaryUnusedCount-red) '
        '![🏠 Internal](https://img.shields.io/badge/Internal_$summaryInternalCount-yellow) '
        '![🌐 External](https://img.shields.io/badge/External_$summaryExternalCount-blue) '
        '![✅ Both](https://img.shields.io/badge/Both_$summaryBothCount-brightgreen)');
    buffer.writeln('');
    // Summary table
    buffer.writeln('## 🔖 Summary');
    buffer.writeln('| Category                          | Count |');
    buffer.writeln('|:----------------------------------|:-----:|');
    buffer
        .writeln('| ❌ Unused Classes                 | $summaryUnusedCount |');
    buffer.writeln(
        '| 🏠 Classes Used Only Internally   | $summaryInternalCount |');
    buffer.writeln(
        '| 🌐 Classes Used Only Externally   | $summaryExternalCount |');
    buffer.writeln('| ✅ Classes Used Both              | $summaryBothCount |');
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
      // Collapsible section for each category
      buffer.writeln('<details>');
      buffer.writeln('<summary>$title (${entries.length})</summary>');
      buffer.writeln('');
      buffer.writeln('---');
      if (entries.isEmpty) {
        buffer.writeln('No $entityType found.');
      } else {
        // Table header
        buffer.writeln('| Class | Internal | External | Total |');
        buffer.writeln('|:---|:---:|:---:|:---:|');
        for (final entry in entries) {
          final name = entry.key;
          final info = entry.value;
          final internalUses = info.internalUsageCount;
          final externalUses = info.totalExternalUsages;
          final totalUses = internalUses + externalUses;
          final fileUri = Uri.file(info.definedInFile).toString();
          final lineNum = info.lineIndex + 1;
          final linkDestination = '<$fileUri#L$lineNum>';
          buffer.writeln(
              '| 📄 [$name]($linkDestination) | $internalUses | $externalUses | $totalUses |');
        }
      }
      buffer.writeln('');
      buffer.writeln('</details>');
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

    // Markdown table summary
    buffer.writeln('## 📋 Summary');
    buffer.writeln('| Metric | Count | Percent |');
    buffer.writeln('|:-----------------------------|------:|--------:|');
    buffer.writeln(
        '| 🧮 **Total classes**          | ${classes.length} | 100% |');
    buffer.writeln(
        '| ❌ Unused classes             | ${unusedClasses.length} | ${(unusedClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln(
        '| 🏠 Internal only              | ${internalOnlyClasses.length} | ${(internalOnlyClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln(
        '| 🌐 External only              | ${externalOnlyClasses.length} | ${(externalOnlyClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln(
        '| ✅ Both internal & external   | ${bothInternalExternalClasses.length} | ${(bothInternalExternalClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln(
        '| 🧩 Mixin classes              | ${mixingClasses.length} | ${(mixingClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln(
        '| 🔢 Enum classes               | ${enumClasses.length} | ${(enumClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln(
        '| 🧩 Extension classes          | ${extensionClasses.length} | ${(extensionClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln(
        '| 🧬 State classes              | ${stateClassEntries.length} | ${(stateClassEntries.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln(
        '| 🚩 Entry-point classes        | ${entryPointClassEntries.length} | ${(entryPointClassEntries.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}% |');
    buffer.writeln('');

    // ASCII Class Usage Distribution
    buffer.writeln('## 📊 Class Usage Distribution (ASCII)');
    final classUsageData = [
      ['❌ Unused', summaryUnusedCount],
      ['🏠 Internal', summaryInternalCount],
      ['🌐 External', summaryExternalCount],
      ['✅ Both', summaryBothCount],
    ];
    final classMax =
        classUsageData.map((e) => e[1] as int).reduce((a, b) => a > b ? a : b);
    // Markdown table for ASCII bar chart
    buffer.writeln('| Category      | Count |');
    buffer.writeln('|:------------- |:------|');
    for (final row in classUsageData) {
      final label = row[0] as String;
      final count = row[1] as int;
      final bar =
          count > 0 ? '█' * (count * 30 ~/ (classMax == 0 ? 1 : classMax)) : '';
      buffer.writeln('| $label | $bar${bar.isNotEmpty ? ' ' : ''}$count |');
    }
    buffer.writeln('');

    // Compute file size distribution bins
    final dartFiles = Directory(projectPath)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    final bins = <String, int>{
      '<50 lines': 0,
      '50-200 lines': 0,
      '201-500 lines': 0,
      '501-1000 lines': 0,
      '>1000 lines': 0,
    };
    for (final f in dartFiles) {
      final len = f.readAsLinesSync().length;
      if (len < 50) {
        bins['<50 lines'] = bins['<50 lines']! + 1;
      } else if (len <= 200) {
        bins['50-200 lines'] = bins['50-200 lines']! + 1;
      } else if (len <= 500) {
        bins['201-500 lines'] = bins['201-500 lines']! + 1;
      } else if (len <= 1000) {
        bins['501-1000 lines'] = bins['501-1000 lines']! + 1;
      } else {
        bins['>1000 lines'] = bins['>1000 lines']! + 1;
      }
    }
    // ASCII File Size Distribution
    buffer.writeln('## 📄 File Size Distribution (ASCII)');
    final fileBins = bins.entries.toList();
    final fileMax =
        fileBins.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    // Markdown table for ASCII file size chart
    buffer.writeln('| File Size      | Count |');
    buffer.writeln('|:-------------- |:------|');
    for (final bin in fileBins) {
      final bar = bin.value > 0
          ? '█' * (bin.value * 30 ~/ (fileMax == 0 ? 1 : fileMax))
          : '';
      buffer.writeln(
          '| ${bin.key} | $bar${bar.isNotEmpty ? ' ' : ''}${bin.value} |');
    }
    buffer.writeln('');

    final file = File(filePath);
    file.writeAsStringSync(buffer.toString());
    print('\nAnalysis report saved to: $filePath');
  } catch (e) {
    print(
        '\nError saving analysis report: $e. Ensure you have write permissions for $outputDir.');
  }
}

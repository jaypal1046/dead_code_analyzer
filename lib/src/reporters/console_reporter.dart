import 'dart:math';
import 'package:dead_code_analyzer/src/models/categorized_classes.dart';
import 'package:dead_code_analyzer/src/models/categorized_functions.dart';
import 'package:dead_code_analyzer/src/models/class_info.dart';
import 'package:dead_code_analyzer/src/models/code_info.dart';
import 'package:dead_code_analyzer/src/utils/helper.dart';
import 'package:path/path.dart' as path;

class ConsoleReporter {
  // Helper function to convert absolute path to lib-relative path
  static String toLibRelativePath(String absolutePath, String projectPath) {
    final libPath = path.join(projectPath, 'lib');
    if (absolutePath.startsWith(libPath)) {
      return path.relative(absolutePath, from: libPath);
    }
    return path.relative(absolutePath, from: projectPath);
  }

// Categorize classes based on their usage patterns
  static CategorizedClasses categorizeClasses(Map<String, ClassInfo> classes) {
    final sortedClasses = classes.entries.toList()
      ..sort((a, b) => b.value.totalUsages.compareTo(a.value.totalUsages));

    final unusedClasses = <String>[];
    final internalOnlyClasses = <String>[];
    final externalOnlyClasses = <String>[];
    final bothInternalExternalClasses = <String>[];
    final stateClasses = <String>[];
    final entryPointClasses = <String>[];
    final commentedClasses = <String>[];

    for (final entry in sortedClasses) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUsages = classInfo.internalUsageCount;
      final externalUsages = classInfo.totalExternalUsages;
      final totalUsages = classInfo.totalUsages;

      if (classInfo.commentedOut) {
        commentedClasses.add(className);
      } else if (classInfo.isEntryPoint) {
        entryPointClasses.add(className);
      } else if (classInfo.type == 'state_class') {
        stateClasses.add(className);
      } else if (totalUsages == 0) {
        unusedClasses.add(className);
      } else if (internalUsages > 0 && externalUsages == 0) {
        internalOnlyClasses.add(className);
      } else if (internalUsages == 0 && externalUsages > 0) {
        externalOnlyClasses.add(className);
      } else if (internalUsages > 0 && externalUsages > 0) {
        bothInternalExternalClasses.add(className);
      }
    }

    return CategorizedClasses(
      unused: unusedClasses,
      internalOnly: internalOnlyClasses,
      externalOnly: externalOnlyClasses,
      bothInternalExternal: bothInternalExternalClasses,
      state: stateClasses,
      entryPoint: entryPointClasses,
      commented: commentedClasses,
    );
  }

// Categorize functions based on their usage patterns
  static CategorizedFunctions categorizeFunctions(
      Map<String, CodeInfo> functions) {
    final unusedFunctions = <String>[];
    final internalOnlyFunctions = <String>[];
    final externalOnlyFunctions = <String>[];
    final bothInternalExternalFunctions = <String>[];
    final emptyPrebuiltFunctions = <String>[];
    final entryPointFunctions = <String>[];
    final commentedFunctions = <String>[];

    final sortedFunctions = functions.entries.toList()
      ..sort((a, b) => b.value.totalUsages.compareTo(a.value.totalUsages));

    for (final entry in sortedFunctions) {
      final functionName = entry.key;
      final functionInfo = entry.value;
      final internalUsages = functionInfo.internalUsageCount;
      final externalUsages = functionInfo.totalExternalUsages;
      final totalUsages = functionInfo.totalUsages;

      if (functionInfo.commentedOut) {
        commentedFunctions.add(functionName);
        continue;
      }

      if (functionInfo.isPrebuiltFlutter) {
        if (functionInfo.isEmpty) {
          emptyPrebuiltFunctions.add(functionName);
        }
        continue;
      }

      if (functionInfo.isEntryPoint) {
        entryPointFunctions.add(functionName);
      } else if (totalUsages == 0) {
        unusedFunctions.add(functionName);
      } else if (internalUsages > 0 && externalUsages == 0) {
        internalOnlyFunctions.add(functionName);
      } else if (internalUsages == 0 && externalUsages > 0) {
        externalOnlyFunctions.add(functionName);
      } else if (internalUsages > 0 && externalUsages > 0) {
        bothInternalExternalFunctions.add(functionName);
      }
    }

    return CategorizedFunctions(
      unused: unusedFunctions,
      internalOnly: internalOnlyFunctions,
      externalOnly: externalOnlyFunctions,
      bothInternalExternal: bothInternalExternalFunctions,
      emptyPrebuilt: emptyPrebuiltFunctions,
      entryPoint: entryPointFunctions,
      commented: commentedFunctions,
    );
  }

// Print analysis summary
  static void printAnalysisSummary(
    Map<String, ClassInfo> classes,
    Map<String, CodeInfo> functions,
    CategorizedClasses categorizedClasses,
    CategorizedFunctions categorizedFunctions,
    bool analyzeFunctions,
  ) {
    print('\nAnalysis Summary:');

    final activeClasses =
        classes.entries.where((entry) => !entry.value.commentedOut).length;
    print('Total classes analyzed: ${classes.length}');
    print('Commented Classes: ${categorizedClasses.commented.length}');
    print(
        'Unused Classes: ${categorizedClasses.unused.length} (${(categorizedClasses.unused.length / (activeClasses > 0 ? activeClasses : 1) * 100).toStringAsFixed(1)}%)');
    print(
        'Classes used only internally: ${categorizedClasses.internalOnly.length}');
    print(
        'Classes used only externally: ${categorizedClasses.externalOnly.length}');
    print(
        'Classes used both internally and externally: ${categorizedClasses.bothInternalExternal.length}');
    print('State classes: ${categorizedClasses.state.length}');
    print(
        'Entry-point classes (@pragma("vm:entry-point")): ${categorizedClasses.entryPoint.length}');

    if (analyzeFunctions) {
      final activeFunctions =
          functions.entries.where((entry) => !entry.value.commentedOut).length;
      print('Total functions analyzed: ${functions.length}');
      print('Commented functions: ${categorizedFunctions.commented.length}');
      print(
          'Unused functions: ${categorizedFunctions.unused.length} (${(categorizedFunctions.unused.length / (activeFunctions > 0 ? activeFunctions : 1) * 100).toStringAsFixed(1)}%)');
      print(
          'Functions used only internally: ${categorizedFunctions.internalOnly.length}');
      print(
          'Functions used only externally: ${categorizedFunctions.externalOnly.length}');
      print(
          'Functions used both internally and externally: ${categorizedFunctions.bothInternalExternal.length}');
      print(
          'Empty prebuilt Flutter functions: ${categorizedFunctions.emptyPrebuilt.length}');
      print(
          'Entry-point functions (@pragma("vm:entry-point")): ${categorizedFunctions.entryPoint.length}');
    }
  }

// Print unused classes section
  static void printUnusedClasses(
    List<String> unusedClasses,
    Map<String, ClassInfo> classes,
    String projectPath,
    int maxUnused,
  ) {
    if (unusedClasses.isEmpty) return;

    print('\nUnused Classes:');
    for (int i = 0; i < min(unusedClasses.length, maxUnused); i++) {
      final className = unusedClasses[i];
      final definedIn =
          toLibRelativePath(classes[className]!.definedInFile, projectPath);
      print(' - $className (in $definedIn)');
    }
    if (unusedClasses.length > maxUnused) {
      print(' - ... and ${unusedClasses.length - maxUnused} more');
    }
  }

// Print commented functions section
  static void printCommentedFunctions(
    List<String> commentedFunctions,
    Map<String, CodeInfo> functions,
    String projectPath,
    int maxUnused,
  ) {
    if (commentedFunctions.isEmpty) return;

    print('\nCommented Functions:');
    for (int i = 0; i < min(commentedFunctions.length, maxUnused); i++) {
      final functionName = commentedFunctions[i];
      final cleanName = Healper.getCleanFunctionName(functionName);
      final definedIn = toLibRelativePath(
          functions[functionName]!.definedInFile, projectPath);
      print(' - $cleanName (in $definedIn) [COMMENTED OUT]');
    }
    if (commentedFunctions.length > maxUnused) {
      print(' - ... and ${commentedFunctions.length - maxUnused} more');
    }
  }

// Print entry-point classes section
  static void printEntryPointClasses(
    List<String> entryPointClasses,
    Map<String, ClassInfo> classes,
    String projectPath,
  ) {
    if (entryPointClasses.isEmpty) return;

    print('\nEntry-Point Classes (@pragma("vm:entry-point")):');
    for (final className in entryPointClasses) {
      final classInfo = classes[className]!;
      final definedIn = toLibRelativePath(classInfo.definedInFile, projectPath);
      final totalUses = classInfo.totalUsages;
      print(
          ' - $className (in $definedIn, total references: $totalUses)${totalUses == 0 ? ' [Used by native code]' : ''}');
    }
  }

// Print unused functions section
  static void printUnusedFunctions(
    List<String> unusedFunctions,
    Map<String, CodeInfo> functions,
    String projectPath,
    int maxUnused,
  ) {
    if (unusedFunctions.isEmpty) return;

    print('\nUnused Functions:');
    for (int i = 0; i < min(unusedFunctions.length, maxUnused); i++) {
      final functionName = unusedFunctions[i];
      final definedIn = toLibRelativePath(
          functions[functionName]!.definedInFile, projectPath);
      print(' - $functionName (in $definedIn)');
    }
    if (unusedFunctions.length > maxUnused) {
      print(' - ... and ${unusedFunctions.length - maxUnused} more');
    }
  }

// Print empty prebuilt Flutter functions section
  static void printEmptyPrebuiltFunctions(
    List<String> emptyPrebuiltFunctions,
    Map<String, CodeInfo> functions,
    String projectPath,
    int maxUnused,
  ) {
    if (emptyPrebuiltFunctions.isEmpty) return;

    print('\nEmpty Prebuilt Flutter Functions:');
    for (int i = 0; i < min(emptyPrebuiltFunctions.length, maxUnused); i++) {
      final functionName = emptyPrebuiltFunctions[i];
      final definedIn = toLibRelativePath(
          functions[functionName]!.definedInFile, projectPath);
      final totalUses = functions[functionName]!.totalUsages;
      print(' - $functionName (in $definedIn, total references: $totalUses)');
    }
    if (emptyPrebuiltFunctions.length > maxUnused) {
      print(' - ... and ${emptyPrebuiltFunctions.length - maxUnused} more');
    }
  }

// Print entry-point functions section
  static void printEntryPointFunctions(
    List<String> entryPointFunctions,
    Map<String, CodeInfo> functions,
    String projectPath,
  ) {
    if (entryPointFunctions.isEmpty) return;

    print('\nEntry-Point Functions (@pragma("vm:entry-point")):');
    for (final functionName in entryPointFunctions) {
      final functionInfo = functions[functionName]!;
      final definedIn =
          toLibRelativePath(functionInfo.definedInFile, projectPath);
      final totalUses = functionInfo.totalUsages;
      print(
          ' - $functionName (in $definedIn, total references: $totalUses)${totalUses == 0 ? ' [Used by native code]' : ''}');
    }
  }

// Print detailed class usage information
  static void printDetailedClassUsage(
    Map<String, ClassInfo> classes,
    CategorizedClasses categorizedClasses,
    String projectPath,
  ) {
    print('\nDetailed Class Usage:');

    final sortedClasses = classes.entries.toList()
      ..sort((a, b) => b.value.totalUsages.compareTo(a.value.totalUsages));

    for (final entry in sortedClasses) {
      final className = entry.key;
      final classInfo = entry.value;
      final definedIn = toLibRelativePath(classInfo.definedInFile, projectPath);
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;
      final totalUses = classInfo.totalUsages;

      final usageFiles = classInfo.externalUsageFiles.map((filePath) {
        final fileName = toLibRelativePath(filePath, projectPath);
        final count = classInfo.externalUsages[filePath] ?? 0;
        return '$fileName ($count references)';
      }).toList();

      print('Class: $className');
      print('  Defined in: $definedIn');
      print('  Internal references: $internalUses');
      print('  External references: $externalUses');
      print('  Total references: $totalUses');

      if (classInfo.isEntryPoint) {
        print('  Entry-point: Yes (@pragma("vm:entry-point"))');
      }

      if (usageFiles.isNotEmpty) {
        print('  External usage files: $usageFiles');
      }

      if (classInfo.type == 'state_class') {
        print('  Category: State Class');
      } else if (categorizedClasses.unused.contains(className)) {
        print('  Category: Unused');
      } else if (categorizedClasses.internalOnly.contains(className)) {
        print('  Category: Internal Only');
      } else if (categorizedClasses.externalOnly.contains(className)) {
        print('  Category: External Only');
      } else if (categorizedClasses.bothInternalExternal.contains(className)) {
        print('  Category: Both Internal and External');
      }
      print('');
    }
  }

// Print detailed function usage information
  static void printDetailedFunctionUsage(
    Map<String, CodeInfo> functions,
    CategorizedFunctions categorizedFunctions,
    String projectPath,
  ) {
    print('\nDetailed Function Usage:');

    for (final entry in functions.entries) {
      final functionName = entry.key;
      final functionInfo = entry.value;
      final definedIn =
          toLibRelativePath(functionInfo.definedInFile, projectPath);
      final internalUses = functionInfo.internalUsageCount;
      final externalUses = functionInfo.totalExternalUsages;
      final totalUses = internalUses + externalUses;

      final usageFiles = functionInfo.externalUsageFiles.map((filePath) {
        final fileName = toLibRelativePath(filePath, projectPath);
        final count = functionInfo.externalUsages[filePath] ?? 0;
        return '$fileName ($count references)';
      }).toList();

      print('Function: $functionName');
      print('  Defined in: $definedIn');
      print('  Internal references: $internalUses');
      print('  External references: $externalUses');
      print('  Total references: $totalUses');

      if (functionInfo.isEntryPoint) {
        print('  Entry-point: Yes (@pragma("vm:entry-point"))');
      }

      if (functionInfo.isPrebuiltFlutter) {
        print(
            '  Prebuilt Flutter: Yes${functionInfo.isEmpty ? ' (Empty)' : ''}');
      }

      if (usageFiles.isNotEmpty) {
        print('  External usage files: $usageFiles');
      }

      if (functionInfo.isPrebuiltFlutter && functionInfo.isEmpty) {
        print('  Category: Empty Prebuilt Flutter Function');
      } else if (categorizedFunctions.unused.contains(functionName)) {
        print('  Category: Unused');
      } else if (categorizedFunctions.internalOnly.contains(functionName)) {
        print('  Category: Internal Only');
      } else if (categorizedFunctions.externalOnly.contains(functionName)) {
        print('  Category: External Only');
      } else if (categorizedFunctions.bothInternalExternal
          .contains(functionName)) {
        print('  Category: Both Internal and External');
      }
      print('');
    }
  }

// Print recommendations based on analysis results
  static void printRecommendations(
    CategorizedClasses categorizedClasses,
    CategorizedFunctions categorizedFunctions,
    Map<String, ClassInfo> classes,
    Map<String, CodeInfo> functions,
    String projectPath,
    bool analyzeFunctions,
  ) {
    print('\nRecommendations:');

    if (categorizedClasses.unused.isNotEmpty) {
      print(
          '- Review unused classes (e.g., in ${toLibRelativePath(classes[categorizedClasses.unused.first]!.definedInFile, projectPath)}) for potential removal.');
    }

    if (categorizedClasses.internalOnly.isNotEmpty) {
      print(
          '- Consider reducing the scope of classes used only internally (e.g., make them private).');
    }

    if (categorizedClasses.externalOnly.isNotEmpty) {
      print(
          '- Verify classes used only externally are necessary as public APIs.');
    }

    if (categorizedClasses.bothInternalExternal.isNotEmpty) {
      print(
          '- Evaluate classes used both internally and externally for optimization.');
    }

    if (categorizedClasses.state.isNotEmpty) {
      print('- Check state classes for proper widget integration.');
    }

    if (categorizedClasses.entryPoint.isNotEmpty) {
      print(
          '- Verify entry-point classes are correctly referenced by native code, especially those with no Dart references.');
    }

    if (analyzeFunctions) {
      if (categorizedFunctions.commented.isNotEmpty) {
        print(
            '- Review commented functions (${categorizedFunctions.commented.length} found) - consider removing if no longer needed.');
      }

      if (categorizedFunctions.unused.isNotEmpty) {
        print(
            '- Review unused functions (e.g., in ${toLibRelativePath(functions[categorizedFunctions.unused.first]!.definedInFile, projectPath)}) for potential removal.');
      }

      if (categorizedFunctions.internalOnly.isNotEmpty) {
        print(
            '- Consider reducing the scope of functions used only internally.');
      }

      if (categorizedFunctions.externalOnly.isNotEmpty) {
        print('- Verify functions used only externally are necessary.');
      }

      if (categorizedFunctions.bothInternalExternal.isNotEmpty) {
        print(
            '- Evaluate functions used both internally and externally for optimization.');
      }

      if (categorizedFunctions.emptyPrebuilt.isNotEmpty) {
        print(
            '- Implement empty prebuilt Flutter functions (e.g., ${categorizedFunctions.emptyPrebuilt.first} in ${toLibRelativePath(functions[categorizedFunctions.emptyPrebuilt.first]!.definedInFile, projectPath)}) to ensure proper functionality.');
      }

      if (categorizedFunctions.entryPoint.isNotEmpty) {
        print(
            '- Verify entry-point functions are correctly referenced by native code.');
      }
    }
  }

// Main function that orchestrates the entire printing process
  static void printResults({
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool verbose,
    required String projectPath,
    required bool analyzeFunctions,
    int maxUnused = 10,
  }) {
    // Categorize classes and functions
    final categorizedClasses = categorizeClasses(classes);
    final categorizedFunctions = analyzeFunctions
        ? categorizeFunctions(functions)
        : CategorizedFunctions(
            unused: [],
            internalOnly: [],
            externalOnly: [],
            bothInternalExternal: [],
            emptyPrebuilt: [],
            entryPoint: [],
            commented: [],
          );

    // Print analysis summary
    printAnalysisSummary(classes, functions, categorizedClasses,
        categorizedFunctions, analyzeFunctions);

    // Print specific sections
    printUnusedClasses(
        categorizedClasses.unused, classes, projectPath, maxUnused);

    if (analyzeFunctions) {
      printCommentedFunctions(
          categorizedFunctions.commented, functions, projectPath, maxUnused);
    }

    printEntryPointClasses(categorizedClasses.entryPoint, classes, projectPath);

    if (analyzeFunctions) {
      printUnusedFunctions(
          categorizedFunctions.unused, functions, projectPath, maxUnused);
      printEmptyPrebuiltFunctions(categorizedFunctions.emptyPrebuilt, functions,
          projectPath, maxUnused);
      printEntryPointFunctions(
          categorizedFunctions.entryPoint, functions, projectPath);
    }

    // Print verbose details if requested
    if (verbose) {
      printDetailedClassUsage(classes, categorizedClasses, projectPath);
      if (analyzeFunctions) {
        printDetailedFunctionUsage(
            functions, categorizedFunctions, projectPath);
      }
    }

    // Print recommendations
    printRecommendations(categorizedClasses, categorizedFunctions, classes,
        functions, projectPath, analyzeFunctions);

    // Print tip for verbose mode
    if (!verbose &&
        _shouldShowVerboseTip(
            categorizedClasses, categorizedFunctions, analyzeFunctions)) {
      print('\nTip: Use --verbose to see detailed code usage information.');
    }
  }

// Helper function to determine if verbose tip should be shown
  static bool _shouldShowVerboseTip(CategorizedClasses categorizedClasses,
      CategorizedFunctions categorizedFunctions, bool analyzeFunctions) {
    return categorizedClasses.unused.isNotEmpty ||
        categorizedClasses.internalOnly.isNotEmpty ||
        categorizedClasses.externalOnly.isNotEmpty ||
        categorizedClasses.bothInternalExternal.isNotEmpty ||
        (analyzeFunctions &&
            (categorizedFunctions.unused.isNotEmpty ||
                categorizedFunctions.internalOnly.isNotEmpty ||
                categorizedFunctions.externalOnly.isNotEmpty ||
                categorizedFunctions.bothInternalExternal.isNotEmpty ||
                categorizedFunctions.emptyPrebuilt.isNotEmpty));
  }
}

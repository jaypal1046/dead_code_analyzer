import 'dart:math';

import 'package:dead_code_analyzer/src/models/class_info.dart';
import 'package:dead_code_analyzer/src/models/code_info.dart';
import 'package:dead_code_analyzer/src/models/reporter/categorized_classes.dart';
import 'package:dead_code_analyzer/src/models/reporter/categorized_functions.dart';
import 'package:dead_code_analyzer/src/utils/helper.dart';
import 'package:path/path.dart' as path;

/// A console reporter for displaying dead code analysis results.
/// 
/// This class provides methods to categorize and display information about
/// unused classes and functions in a Flutter/Dart project.
class ConsoleReporter {
  /// Private constructor to prevent instantiation.
  ConsoleReporter._();

  /// Converts an absolute path to a lib-relative path for cleaner output.
  /// 
  /// Returns a path relative to the lib directory if the file is within lib,
  /// otherwise returns a path relative to the project root.
  static String toLibRelativePath(String absolutePath, String projectPath) {
    final libPath = path.join(projectPath, 'lib');
    if (absolutePath.startsWith(libPath)) {
      return path.relative(absolutePath, from: libPath);
    }
    return path.relative(absolutePath, from: projectPath);
  }

  /// Categorizes classes based on their usage patterns.
  /// 
  /// Returns a [CategorizedClasses] object containing lists of classes
  /// grouped by their usage characteristics.
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

  /// Categorizes functions based on their usage patterns.
  /// 
  /// Returns a [CategorizedFunctions] object containing lists of functions
  /// grouped by their usage characteristics.
  static CategorizedFunctions categorizeFunctions(
    Map<String, CodeInfo> functions,
  ) {
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

  /// Prints a summary of the analysis results.
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
    
    final unusedPercentage = activeClasses > 0 
        ? (categorizedClasses.unused.length / activeClasses * 100)
        : 0.0;
    print(
      'Unused Classes: ${categorizedClasses.unused.length} '
      '(${unusedPercentage.toStringAsFixed(1)}%)',
    );
    
    print(
      'Classes used only internally: '
      '${categorizedClasses.internalOnly.length}',
    );
    print(
      'Classes used only externally: '
      '${categorizedClasses.externalOnly.length}',
    );
    print(
      'Classes used both internally and externally: '
      '${categorizedClasses.bothInternalExternal.length}',
    );
    print('State classes: ${categorizedClasses.state.length}');
    print(
      'Entry-point classes (@pragma("vm:entry-point")): '
      '${categorizedClasses.entryPoint.length}',
    );

    if (analyzeFunctions) {
      final activeFunctions =
          functions.entries.where((entry) => !entry.value.commentedOut).length;
      print('Total functions analyzed: ${functions.length}');
      print('Commented functions: ${categorizedFunctions.commented.length}');
      
      final unusedFuncPercentage = activeFunctions > 0
          ? (categorizedFunctions.unused.length / activeFunctions * 100)
          : 0.0;
      print(
        'Unused functions: ${categorizedFunctions.unused.length} '
        '(${unusedFuncPercentage.toStringAsFixed(1)}%)',
      );
      
      print(
        'Functions used only internally: '
        '${categorizedFunctions.internalOnly.length}',
      );
      print(
        'Functions used only externally: '
        '${categorizedFunctions.externalOnly.length}',
      );
      print(
        'Functions used both internally and externally: '
        '${categorizedFunctions.bothInternalExternal.length}',
      );
      print(
        'Empty prebuilt Flutter functions: '
        '${categorizedFunctions.emptyPrebuilt.length}',
      );
      print(
        'Entry-point functions (@pragma("vm:entry-point")): '
        '${categorizedFunctions.entryPoint.length}',
      );
    }
  }

  /// Prints the unused classes section.
  static void printUnusedClasses(
    List<String> unusedClasses,
    Map<String, ClassInfo> classes,
    String projectPath,
    int maxUnused,
  ) {
    if (unusedClasses.isEmpty) return;

    print('\nUnused Classes:');
    final itemsToShow = min(unusedClasses.length, maxUnused);
    
    for (int i = 0; i < itemsToShow; i++) {
      final className = unusedClasses[i];
      final classInfo = classes[className];
      if (classInfo != null) {
        final definedIn = toLibRelativePath(classInfo.definedInFile, projectPath);
        print(' - $className (in $definedIn)');
      }
    }
    
    if (unusedClasses.length > maxUnused) {
      print(' - ... and ${unusedClasses.length - maxUnused} more');
    }
  }

  /// Prints the commented functions section.
  static void printCommentedFunctions(
    List<String> commentedFunctions,
    Map<String, CodeInfo> functions,
    String projectPath,
    int maxUnused,
  ) {
    if (commentedFunctions.isEmpty) return;

    print('\nCommented Functions:');
    final itemsToShow = min(commentedFunctions.length, maxUnused);
    
    for (int i = 0; i < itemsToShow; i++) {
      final functionName = commentedFunctions[i];
      final cleanName = Helper.cleanFunctionName(functionName);
      final functionInfo = functions[functionName];
      
      if (functionInfo != null) {
        final definedIn = toLibRelativePath(
          functionInfo.definedInFile,
          projectPath,
        );
        print(' - $cleanName (in $definedIn) [COMMENTED OUT]');
      }
    }
    
    if (commentedFunctions.length > maxUnused) {
      print(' - ... and ${commentedFunctions.length - maxUnused} more');
    }
  }

  /// Prints the entry-point classes section.
  static void printEntryPointClasses(
    List<String> entryPointClasses,
    Map<String, ClassInfo> classes,
    String projectPath,
  ) {
    if (entryPointClasses.isEmpty) return;

    print('\nEntry-Point Classes (@pragma("vm:entry-point")):');
    for (final className in entryPointClasses) {
      final classInfo = classes[className];
      if (classInfo != null) {
        final definedIn = toLibRelativePath(classInfo.definedInFile, projectPath);
        final totalUses = classInfo.totalUsages;
        final usageNote = totalUses == 0 ? ' [Used by native code]' : '';
        print(
          ' - $className (in $definedIn, total references: $totalUses)$usageNote',
        );
      }
    }
  }

  /// Prints the unused functions section.
  static void printUnusedFunctions(
    List<String> unusedFunctions,
    Map<String, CodeInfo> functions,
    String projectPath,
    int maxUnused,
  ) {
    if (unusedFunctions.isEmpty) return;

    print('\nUnused Functions:');
    final itemsToShow = min(unusedFunctions.length, maxUnused);
    
    for (int i = 0; i < itemsToShow; i++) {
      final functionName = unusedFunctions[i];
      final functionInfo = functions[functionName];
      
      if (functionInfo != null) {
        final definedIn = toLibRelativePath(
          functionInfo.definedInFile,
          projectPath,
        );
        print(' - $functionName (in $definedIn)');
      }
    }
    
    if (unusedFunctions.length > maxUnused) {
      print(' - ... and ${unusedFunctions.length - maxUnused} more');
    }
  }

  /// Prints the empty prebuilt Flutter functions section.
  static void printEmptyPrebuiltFunctions(
    List<String> emptyPrebuiltFunctions,
    Map<String, CodeInfo> functions,
    String projectPath,
    int maxUnused,
  ) {
    if (emptyPrebuiltFunctions.isEmpty) return;

    print('\nEmpty Prebuilt Flutter Functions:');
    final itemsToShow = min(emptyPrebuiltFunctions.length, maxUnused);
    
    for (int i = 0; i < itemsToShow; i++) {
      final functionName = emptyPrebuiltFunctions[i];
      final functionInfo = functions[functionName];
      
      if (functionInfo != null) {
        final definedIn = toLibRelativePath(
          functionInfo.definedInFile,
          projectPath,
        );
        final totalUses = functionInfo.totalUsages;
        print(
          ' - $functionName (in $definedIn, total references: $totalUses)',
        );
      }
    }
    
    if (emptyPrebuiltFunctions.length > maxUnused) {
      print(' - ... and ${emptyPrebuiltFunctions.length - maxUnused} more');
    }
  }

  /// Prints the entry-point functions section.
  static void printEntryPointFunctions(
    List<String> entryPointFunctions,
    Map<String, CodeInfo> functions,
    String projectPath,
  ) {
    if (entryPointFunctions.isEmpty) return;

    print('\nEntry-Point Functions (@pragma("vm:entry-point")):');
    for (final functionName in entryPointFunctions) {
      final functionInfo = functions[functionName];
      if (functionInfo != null) {
        final definedIn = toLibRelativePath(
          functionInfo.definedInFile,
          projectPath,
        );
        final totalUses = functionInfo.totalUsages;
        final usageNote = totalUses == 0 ? ' [Used by native code]' : '';
        print(
          ' - $functionName (in $definedIn, total references: $totalUses)$usageNote',
        );
      }
    }
  }

  /// Prints detailed class usage information.
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

      final category = _getClassCategory(className, categorizedClasses, classInfo);
      if (category.isNotEmpty) {
        print('  Category: $category');
      }
      
      print('');
    }
  }

  /// Prints detailed function usage information.
  static void printDetailedFunctionUsage(
    Map<String, CodeInfo> functions,
    CategorizedFunctions categorizedFunctions,
    String projectPath,
  ) {
    print('\nDetailed Function Usage:');

    for (final entry in functions.entries) {
      final functionName = entry.key;
      final functionInfo = entry.value;
      final definedIn = toLibRelativePath(
        functionInfo.definedInFile,
        projectPath,
      );
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
        final emptyNote = functionInfo.isEmpty ? ' (Empty)' : '';
        print('  Prebuilt Flutter: Yes$emptyNote');
      }

      if (usageFiles.isNotEmpty) {
        print('  External usage files: $usageFiles');
      }

      final category = _getFunctionCategory(
        functionName,
        categorizedFunctions,
        functionInfo,
      );
      if (category.isNotEmpty) {
        print('  Category: $category');
      }
      
      print('');
    }
  }

  /// Prints recommendations based on analysis results.
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
      final firstUnusedClass = classes[categorizedClasses.unused.first];
      if (firstUnusedClass != null) {
        final relativePath = toLibRelativePath(
          firstUnusedClass.definedInFile,
          projectPath,
        );
        print(
          '- Review unused classes (e.g., in $relativePath) for potential removal.',
        );
      }
    }

    if (categorizedClasses.internalOnly.isNotEmpty) {
      print(
        '- Consider reducing the scope of classes used only internally '
        '(e.g., make them private).',
      );
    }

    if (categorizedClasses.externalOnly.isNotEmpty) {
      print(
        '- Verify classes used only externally are necessary as public APIs.',
      );
    }

    if (categorizedClasses.bothInternalExternal.isNotEmpty) {
      print(
        '- Evaluate classes used both internally and externally for optimization.',
      );
    }

    if (categorizedClasses.state.isNotEmpty) {
      print('- Check state classes for proper widget integration.');
    }

    if (categorizedClasses.entryPoint.isNotEmpty) {
      print(
        '- Verify entry-point classes are correctly referenced by native code, '
        'especially those with no Dart references.',
      );
    }

    if (!analyzeFunctions) return;

    if (categorizedFunctions.commented.isNotEmpty) {
      print(
        '- Review commented functions (${categorizedFunctions.commented.length} found) '
        '- consider removing if no longer needed.',
      );
    }

    if (categorizedFunctions.unused.isNotEmpty) {
      final firstUnusedFunction = functions[categorizedFunctions.unused.first];
      if (firstUnusedFunction != null) {
        final relativePath = toLibRelativePath(
          firstUnusedFunction.definedInFile,
          projectPath,
        );
        print(
          '- Review unused functions (e.g., in $relativePath) for potential removal.',
        );
      }
    }

    if (categorizedFunctions.internalOnly.isNotEmpty) {
      print(
        '- Consider reducing the scope of functions used only internally.',
      );
    }

    if (categorizedFunctions.externalOnly.isNotEmpty) {
      print('- Verify functions used only externally are necessary.');
    }

    if (categorizedFunctions.bothInternalExternal.isNotEmpty) {
      print(
        '- Evaluate functions used both internally and externally for optimization.',
      );
    }

    if (categorizedFunctions.emptyPrebuilt.isNotEmpty) {
      final firstEmptyFunction = functions[categorizedFunctions.emptyPrebuilt.first];
      if (firstEmptyFunction != null) {
        final relativePath = toLibRelativePath(
          firstEmptyFunction.definedInFile,
          projectPath,
        );
        print(
          '- Implement empty prebuilt Flutter functions '
          '(e.g., ${categorizedFunctions.emptyPrebuilt.first} in $relativePath) '
          'to ensure proper functionality.',
        );
      }
    }

    if (categorizedFunctions.entryPoint.isNotEmpty) {
      print(
        '- Verify entry-point functions are correctly referenced by native code.',
      );
    }
  }

  /// Main function that orchestrates the entire printing process.
  static void printResults({
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool showTrace,
    required String projectPath,
    required bool analyzeFunctions,
    int maxUnusedEntities = 10,
  }) {
    // Categorize classes and functions
    final categorizedClasses = categorizeClasses(classes);
    final categorizedFunctions = analyzeFunctions
        ? categorizeFunctions(functions)
        : CategorizedFunctions(
            unused: const [],
            internalOnly: const [],
            externalOnly: const [],
            bothInternalExternal: const [],
            emptyPrebuilt: const [],
            entryPoint: const [],
            commented: const [],
          );

    // Print analysis summary
    printAnalysisSummary(
      classes,
      functions,
      categorizedClasses,
      categorizedFunctions,
      analyzeFunctions,
    );

    // Print specific sections
    printUnusedClasses(
      categorizedClasses.unused,
      classes,
      projectPath,
      maxUnusedEntities,
    );

    if (analyzeFunctions) {
      printCommentedFunctions(
        categorizedFunctions.commented,
        functions,
        projectPath,
        maxUnusedEntities,
      );
    }

    printEntryPointClasses(
      categorizedClasses.entryPoint,
      classes,
      projectPath,
    );

    if (analyzeFunctions) {
      printUnusedFunctions(
        categorizedFunctions.unused,
        functions,
        projectPath,
        maxUnusedEntities,
      );
      printEmptyPrebuiltFunctions(
        categorizedFunctions.emptyPrebuilt,
        functions,
        projectPath,
        maxUnusedEntities,
      );
      printEntryPointFunctions(
        categorizedFunctions.entryPoint,
        functions,
        projectPath,
      );
    }

    // Print verbose details if requested
    if (showTrace) {
      printDetailedClassUsage(classes, categorizedClasses, projectPath);
      if (analyzeFunctions) {
        printDetailedFunctionUsage(
          functions,
          categorizedFunctions,
          projectPath,
        );
      }
    }

    // Print recommendations
    printRecommendations(
      categorizedClasses,
      categorizedFunctions,
      classes,
      functions,
      projectPath,
      analyzeFunctions,
    );

    // Print tip for verbose mode
    if (!showTrace &&
        _shouldShowVerboseTip(
          categorizedClasses,
          categorizedFunctions,
          analyzeFunctions,
        )) {
      print('\nTip: Use --verbose to see detailed code usage information.');
    }
  }

  /// Helper function to determine if verbose tip should be shown.
  static bool _shouldShowVerboseTip(
    CategorizedClasses categorizedClasses,
    CategorizedFunctions categorizedFunctions,
    bool analyzeFunctions,
  ) {
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

  /// Gets the category string for a class.
  static String _getClassCategory(
    String className,
    CategorizedClasses categorizedClasses,
    ClassInfo classInfo,
  ) {
    if (classInfo.type == 'state_class') {
      return 'State Class';
    } else if (categorizedClasses.unused.contains(className)) {
      return 'Unused';
    } else if (categorizedClasses.internalOnly.contains(className)) {
      return 'Internal Only';
    } else if (categorizedClasses.externalOnly.contains(className)) {
      return 'External Only';
    } else if (categorizedClasses.bothInternalExternal.contains(className)) {
      return 'Both Internal and External';
    }
    return '';
  }

  /// Gets the category string for a function.
  static String _getFunctionCategory(
    String functionName,
    CategorizedFunctions categorizedFunctions,
    CodeInfo functionInfo,
  ) {
    if (functionInfo.isPrebuiltFlutter && functionInfo.isEmpty) {
      return 'Empty Prebuilt Flutter Function';
    } else if (categorizedFunctions.unused.contains(functionName)) {
      return 'Unused';
    } else if (categorizedFunctions.internalOnly.contains(functionName)) {
      return 'Internal Only';
    } else if (categorizedFunctions.externalOnly.contains(functionName)) {
      return 'External Only';
    } else if (categorizedFunctions.bothInternalExternal.contains(functionName)) {
      return 'Both Internal and External';
    }
    return '';
  }
}
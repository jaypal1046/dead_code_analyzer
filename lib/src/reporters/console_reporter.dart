import 'dart:math';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:path/path.dart' as path;

void printResults(
    {required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required bool verbose,
    required String projectPath,
    required bool analyzeFunctions,
    int maxUnused = 10}) {
  // Helper function to convert absolute path to lib-relative path
  String toLibRelativePath(String absolutePath, String projectPath) {
    final libPath = path.join(projectPath, 'lib');
    if (absolutePath.startsWith(libPath)) {
      return path.relative(absolutePath, from: libPath);
    }
    return path.relative(absolutePath, from: projectPath);
  }

  // Process classes
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

  // Process functions
  final unusedFunctions = <String>[];
  final internalOnlyFunctions = <String>[];
  final externalOnlyFunctions = <String>[];
  final bothInternalExternalFunctions = <String>[];
  final emptyPrebuiltFunctions = <String>[];
  final entryPointFunctions = <String>[];
  final commentedFunctions = <String>[]; // New: track commented functions

  if (analyzeFunctions) {
    final sortedFunctions = functions.entries.toList()
      ..sort((a, b) => b.value.totalUsages.compareTo(a.value.totalUsages));

    for (final entry in sortedFunctions) {
      final functionName = entry.key;
      final functionInfo = entry.value;
      final internalUsages = functionInfo.internalUsageCount;
      final externalUsages = functionInfo.totalExternalUsages;
      final totalUsages = functionInfo.totalUsages;
      // Handle commented functions separately
      if (functionInfo.commentedOut) {
        commentedFunctions.add(functionName);
        continue;
      }
      if (functionInfo.isPrebuiltFlutter) {
        if (functionInfo.isEmpty) {
          emptyPrebuiltFunctions.add(functionName);
        }
        continue; // Skip non-empty prebuilt functions
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
  }

  // Print summary (add commented functions to existing summary)
  print('\nAnalysis Summary:');
  final activeClasses =
      classes.entries.where((entry) => !entry.value.commentedOut).length;
  print('Total classes analyzed: ${classes.length}');
  // print(
  //     'Unused classes: ${unusedClasses.length} (${(unusedClasses.length / (classes.isNotEmpty ? classes.length : 1) * 100).toStringAsFixed(1)}%)');
  print('Commented Classes: ${commentedFunctions.length}');
  print(
      'Unused Classes: ${unusedFunctions.length} (${(unusedFunctions.length / (activeClasses > 0 ? activeClasses : 1) * 100).toStringAsFixed(1)}%)');
  print('Classes used only internally: ${internalOnlyClasses.length}');
  print('Classes used only externally: ${externalOnlyClasses.length}');
  print(
      'Classes used both internally and externally: ${bothInternalExternalClasses.length}');
  print('State classes: ${stateClasses.length}');
  print(
      'Entry-point classes (@pragma("vm:entry-point")): ${entryPointClasses.length}');
  if (analyzeFunctions) {
    final activeFunctions =
        functions.entries.where((entry) => !entry.value.commentedOut).length;
    print('Total functions analyzed: ${functions.length}');
    // print(
    //     'Unused functions: ${unusedFunctions.length} (${(unusedFunctions.length / (functions.isNotEmpty ? functions.length : 1) * 100).toStringAsFixed(1)}%)');
    print('Commented functions: ${commentedFunctions.length}');
    print(
        'Unused functions: ${unusedFunctions.length} (${(unusedFunctions.length / (activeFunctions > 0 ? activeFunctions : 1) * 100).toStringAsFixed(1)}%)');
    print('Functions used only internally: ${internalOnlyFunctions.length}');
    print('Functions used only externally: ${externalOnlyFunctions.length}');
    print(
        'Functions used both internally and externally: ${bothInternalExternalFunctions.length}');
    print('Empty prebuilt Flutter functions: ${emptyPrebuiltFunctions.length}');
    print(
        'Entry-point functions (@pragma("vm:entry-point")): ${entryPointFunctions.length}');
  }

  // Print unused classes
  if (unusedClasses.isNotEmpty) {
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
  if (analyzeFunctions && commentedFunctions.isNotEmpty) {
    print('\nCommented Functions:');
    for (int i = 0; i < min(commentedFunctions.length, maxUnused); i++) {
      final functionName = commentedFunctions[i];
      final cleanName = getCleanFunctionName(functionName);
      final definedIn = toLibRelativePath(
          functions[functionName]!.definedInFile, projectPath);
      print(' - $cleanName (in $definedIn) [COMMENTED OUT]');
    }
    if (commentedFunctions.length > maxUnused) {
      print(' - ... and ${commentedFunctions.length - maxUnused} more');
    }
  }

  // Print entry-point classes
  if (entryPointClasses.isNotEmpty) {
    print('\nEntry-Point Classes (@pragma("vm:entry-point")):');
    for (final className in entryPointClasses) {
      final classInfo = classes[className]!;
      final definedIn = toLibRelativePath(classInfo.definedInFile, projectPath);
      final totalUses = classInfo.totalUsages;
      print(
          ' - $className (in $definedIn, total references: $totalUses)${totalUses == 0 ? ' [Used by native code]' : ''}');
    }
  }

  // Print unused functions
  if (analyzeFunctions && unusedFunctions.isNotEmpty) {
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

  // Print empty prebuilt Flutter functions
  if (analyzeFunctions && emptyPrebuiltFunctions.isNotEmpty) {
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

  // Print entry-point functions
  if (analyzeFunctions && entryPointFunctions.isNotEmpty) {
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

  // Print verbose details
  if (verbose) {
    print('\nDetailed Class Usage:');
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
      } else if (unusedClasses.contains(className)) {
        print('  Category: Unused');
      } else if (internalOnlyClasses.contains(className)) {
        print('  Category: Internal Only');
      } else if (externalOnlyClasses.contains(className)) {
        print('  Category: External Only');
      } else if (bothInternalExternalClasses.contains(className)) {
        print('  Category: Both Internal and External');
      }
      print('');
    }

    if (analyzeFunctions) {
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
        } else if (unusedFunctions.contains(functionName)) {
          print('  Category: Unused');
        } else if (internalOnlyFunctions.contains(functionName)) {
          print('  Category: Internal Only');
        } else if (externalOnlyFunctions.contains(functionName)) {
          print('  Category: External Only');
        } else if (bothInternalExternalFunctions.contains(functionName)) {
          print('  Category: Both Internal and External');
        }
        print('');
      }
    }
  }

  // Add to recommendations section
  print('\nRecommendations:');
  if (unusedClasses.isNotEmpty) {
    print(
        '- Review unused classes (e.g., in ${toLibRelativePath(classes[unusedClasses.first]!.definedInFile, projectPath)}) for potential removal.');
  }
  if (internalOnlyClasses.isNotEmpty) {
    print(
        '- Consider reducing the scope of classes used only internally (e.g., make them private).');
  }
  if (externalOnlyClasses.isNotEmpty) {
    print(
        '- Verify classes used only externally are necessary as public APIs.');
  }
  if (bothInternalExternalClasses.isNotEmpty) {
    print(
        '- Evaluate classes used both internally and externally for optimization.');
  }
  if (stateClasses.isNotEmpty) {
    print('- Check state classes for proper widget integration.');
  }
  if (entryPointClasses.isNotEmpty) {
    print(
        '- Verify entry-point classes are correctly referenced by native code, especially those with no Dart references.');
  }
  if (analyzeFunctions) {
    if (analyzeFunctions && commentedFunctions.isNotEmpty) {
      print(
          '- Review commented functions (${commentedFunctions.length} found) - consider removing if no longer needed.');
    }
    if (unusedFunctions.isNotEmpty) {
      print(
          '- Review unused functions (e.g., in ${toLibRelativePath(functions[unusedFunctions.first]!.definedInFile, projectPath)}) for potential removal.');
    }
    if (internalOnlyFunctions.isNotEmpty) {
      print('- Consider reducing the scope of functions used only internally.');
    }
    if (externalOnlyFunctions.isNotEmpty) {
      print('- Verify functions used only externally are necessary.');
    }
    if (bothInternalExternalFunctions.isNotEmpty) {
      print(
          '- Evaluate functions used both internally and externally for optimization.');
    }
    if (emptyPrebuiltFunctions.isNotEmpty) {
      print(
          '- Implement empty prebuilt Flutter functions (e.g., ${emptyPrebuiltFunctions.first} in ${toLibRelativePath(functions[emptyPrebuiltFunctions.first]!.definedInFile, projectPath)}) to ensure proper functionality.');
    }
    if (entryPointFunctions.isNotEmpty) {
      print(
          '- Verify entry-point functions are correctly referenced by native code.');
    }
  }

  if (!verbose &&
      (unusedClasses.isNotEmpty ||
          internalOnlyClasses.isNotEmpty ||
          externalOnlyClasses.isNotEmpty ||
          bothInternalExternalClasses.isNotEmpty ||
          (analyzeFunctions &&
              (unusedFunctions.isNotEmpty ||
                  internalOnlyFunctions.isNotEmpty ||
                  externalOnlyFunctions.isNotEmpty ||
                  bothInternalExternalFunctions.isNotEmpty ||
                  emptyPrebuiltFunctions.isNotEmpty)))) {
    print('\nTip: Use --verbose to see detailed code usage information.');
  }
}

String toLibRelativePath(String absolutePath, String projectPath) {
  final libPath = path.join(projectPath, 'lib');
  if (absolutePath.startsWith(libPath)) {
    return path.relative(absolutePath, from: libPath);
  }
  return path.relative(absolutePath, from: projectPath);
}

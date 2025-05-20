import 'dart:convert';
import 'dart:math';
import 'package:code_clean/src/model/class_info.dart';
import 'package:path/path.dart' as path;


/// Prints analysis results to the console
void printResults(
    Map<String, ClassInfo> classes, bool verbose, String outputDir) {
  // Convert to sorted list
  final sortedClasses = classes.entries.toList()
    ..sort((a, b) => b.value.totalUsages.compareTo(a.value.totalUsages));

  final results = <String, dynamic>{};

  for (final entry in sortedClasses) {
    final className = entry.key;
    final classInfo = entry.value;

    // Format locations for easier reading
    final formattedExternalLocations = classInfo.externalUsageFiles.map((loc) {
      final relativePath =
          path.relative(loc, from: path.dirname(classInfo.definedInFile));
      return '$relativePath (${classInfo.externalUsages[loc]} uses)';
    }).toList();

    results[className] = {
      'defined_in': path.basename(classInfo.definedInFile),
      'internal_usage_count': classInfo.internalUsageCount,
      'external_usage_count': classInfo.totalExternalUsages,
      'total_usages': classInfo.totalUsages,
      'external_locations': verbose ? formattedExternalLocations : null,
    };
  }

  // Generate usage categories
  final unusedClasses = <String>[];
  final internalOnlyClasses = <String>[];
  final rarelyUsedClasses = <String>[];
  final frequentlyUsedClasses = <String>[];

  for (final entry in sortedClasses) {
    final className = entry.key;
    final classInfo = entry.value;
    final internalUsages = classInfo.internalUsageCount;
    final externalUsages = classInfo.totalExternalUsages;
    final totalUsages = classInfo.totalUsages;

    if (totalUsages == 0) {
      unusedClasses.add(className);
    } else if (externalUsages == 0) {
      internalOnlyClasses.add(className);
    } else if (externalUsages <= 2) {
      rarelyUsedClasses.add(className);
    } else if (totalUsages > 10) {
      frequentlyUsedClasses.add(className);
    }
  }

  // Print full results if verbose
  if (verbose) {
    print('\nDetailed class usage:');
    print(JsonEncoder.withIndent('  ').convert(results));
  }

  // Print summary
  print('\nSummary:');
  print('Total classes: ${classes.length}');
  print(
      'Unused classes: ${unusedClasses.length} (${(unusedClasses.length / classes.length * 100).toStringAsFixed(1)}%)');
  print('Internal-only classes: ${internalOnlyClasses.length}');
  print('Rarely used externally (1-2 external usages): ${rarelyUsedClasses.length}');
  print(
      'Frequently used classes (>10 total usages): ${frequentlyUsedClasses.length}');

  // Print potentially dead classes
  if (unusedClasses.isNotEmpty) {
    print('\nPotentially dead classes:');
    for (int i = 0; i < min(unusedClasses.length, 10); i++) {
      final className = unusedClasses[i];
      final definedIn = path.basename(classes[className]!.definedInFile);
      print(' - $className (defined in $definedIn)');
    }

    if (unusedClasses.length > 10) {
      print(' - ... and ${unusedClasses.length - 10} more');
    }
  }

  // Print suggestions
  print('\nRecommendations:');
  if (unusedClasses.isNotEmpty) {
    print('- Consider removing the unused classes listed above');
  }
  if (internalOnlyClasses.isNotEmpty) {
    print(
        '- Review classes used only internally to determine if their scope can be reduced');
  }
  if (rarelyUsedClasses.isNotEmpty) {
    print(
        '- Review rarely used classes to determine if they can be consolidated');
  }

  if (!verbose && (unusedClasses.isNotEmpty || rarelyUsedClasses.isNotEmpty)) {
    print('\nTip: Run with --verbose flag to see detailed usage information.');
  }
}
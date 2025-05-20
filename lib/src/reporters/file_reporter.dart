
import 'dart:io';

import 'package:code_clean/src/model/class_info.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

void saveResultsToFile(Map<String, ClassInfo> classes, String outputDir) {
  try {
    // Create timestamp for filename
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    final timestamp = formatter.format(now);
    final filename = 'flutter_class_analysis_$timestamp.txt';
    final filePath = path.join(outputDir, filename);

    // Prepare content for file
    final buffer = StringBuffer();
    buffer.writeln('Flutter Class Usage Analysis - ${formatter.format(now)}');
    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln('POTENTIALLY UNUSED OR DEAD CLASSES:');
    buffer.writeln('=' * 50);

    // Sort classes by total usage count (ascending)
    final sortedClasses = classes.entries.toList()
      ..sort((a, b) {
        // First compare external usage
        final externalComparison = a.value.totalExternalUsages.compareTo(b.value.totalExternalUsages);
        if (externalComparison != 0) return externalComparison;
        
        // If external usage is same, compare total usage
        return a.value.totalUsages.compareTo(b.value.totalUsages);
      });

    // First list all unused classes (0 usages)
    buffer.writeln('\nUNUSED CLASSES (0 total usages):');
    buffer.writeln('-' * 30);
    int unusedCount = 0;
    int stateClassCount = 0;

    // First, separate regular classes and state classes
    final List<MapEntry<String, ClassInfo>> mainClassEntries = [];
    final List<MapEntry<String, ClassInfo>> stateClassEntries = [];

    for (final entry in sortedClasses) {
      final className = entry.key;
      
      // Check if this is a State class, which either:
      // 1. Ends with "State" and has a corresponding class without "State" suffix
      // 2. Starts with an underscore and ends with "State"
      bool isStateClass = false;
      
      if (className.endsWith('State')) {
        // Check if there's a corresponding widget class
        final possibleWidgetName = className.substring(0, className.length - 5);
        if (classes.containsKey(possibleWidgetName)) {
          isStateClass = true;
        } else if (className.startsWith('_')) {
          isStateClass = true;
        }
      }
      
      if (isStateClass) {
        stateClassEntries.add(entry);
      } else {
        mainClassEntries.add(entry);
      }
    }

    // Process main classes (unused)
    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;
      final totalUses = internalUses + externalUses;

      if (totalUses == 0) {
        unusedCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        buffer.writeln(' - $className (defined in $definedIn, internal uses: 0, external uses: 0)');
      }
    }

    if (unusedCount == 0) {
      buffer.writeln('No unused regular classes found.');
    }

    // Process state classes (unused) - separate section
    buffer.writeln('\nUNUSED STATE CLASSES (0 total usages):');
    buffer.writeln('-' * 30);
    
    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;
      final totalUses = internalUses + externalUses;

      if (totalUses == 0) {
        stateClassCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        buffer.writeln(' - $className (defined in $definedIn, internal uses: 0, external uses: 0)');
      }
    }

    if (stateClassCount == 0) {
      buffer.writeln('No unused state classes found.');
    }

    // Next list internal-only classes (only used in same file)
    buffer.writeln('\nINTERNAL-ONLY MAIN CLASSES (used only in the file they are defined):');
    buffer.writeln('-' * 30);
    int internalOnlyCount = 0;

    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;

      if (internalUses > 0 && externalUses == 0) {
        internalOnlyCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        buffer.writeln(' - $className (defined in $definedIn, internal uses: $internalUses, external uses: 0)');
      }
    }

    if (internalOnlyCount == 0) {
      buffer.writeln('No internal-only main classes found.');
    }

    // Next list rarely used classes externally (1-2 external usages)
    buffer.writeln('\nRARELY USED EXTERNALLY MAIN CLASSES (1-2 external usages):');
    buffer.writeln('-' * 30);
    int rarelyUsedCount = 0;

    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;

      if (externalUses > 0 && externalUses <= 2) {
        rarelyUsedCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        
        // Format the usage files list with counts
        final usageFiles = classInfo.externalUsageFiles.map((filePath) {
          final fileName = path.basename(filePath);
          final count = classInfo.externalUsages[filePath] ?? 0;
          return '$fileName ($count uses)';
        }).toList();
        final usageFilesStr = usageFiles.toString();
        
        buffer.writeln(
            ' - $className (defined in $definedIn, internal uses: $internalUses, external uses: $externalUses) $usageFilesStr');
      }
    }

    if (rarelyUsedCount == 0) {
      buffer.writeln('No rarely used externally main classes found.');
    }

    // Next list rarely used state classes externally (1-2 usages)
    buffer.writeln('\nRARELY USED EXTERNALLY STATE CLASSES (1-2 external usages):');
    buffer.writeln('-' * 30);
    int rarelyUsedStateCount = 0;

    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;

      if (externalUses > 0 && externalUses <= 2) {
        rarelyUsedStateCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        
        // Format the usage files list with counts
        final usageFiles = classInfo.externalUsageFiles.map((filePath) {
          final fileName = path.basename(filePath);
          final count = classInfo.externalUsages[filePath] ?? 0;
          return '$fileName ($count uses)';
        }).toList();
        final usageFilesStr = usageFiles.toString();
        
        buffer.writeln(
            ' - $className (defined in $definedIn, internal uses: $internalUses, external uses: $externalUses) $usageFilesStr');
      }
    }

    if (rarelyUsedStateCount == 0) {
      buffer.writeln('No rarely used externally state classes found.');
    }

    // Complete class listing - main classes
    buffer.writeln('\nCOMPLETE MAIN CLASS USAGE LIST:');
    buffer.writeln('-' * 30);

    // Sort by external usage first, then total usage for the complete listing
    mainClassEntries.sort((a, b) {
      final externalA = a.value.totalExternalUsages;
      final externalB = b.value.totalExternalUsages;
      
      if (externalB != externalA) {
        return externalB.compareTo(externalA); // Primary sort: external usages descending
      }
      
      final internalA = a.value.internalUsageCount;
      final internalB = b.value.internalUsageCount;
      
      return (internalB + externalB).compareTo(internalA + externalA); // Secondary sort: total usages descending
    });

    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      final definedIn = path.basename(classInfo.definedInFile);
      
      // Format the usage files list - empty for unused classes
      String usageFilesStr = '';
      if (externalUses > 0) {
        final usageFiles = classInfo.externalUsageFiles.map((filePath) {
          final fileName = path.basename(filePath);
          final count = classInfo.externalUsages[filePath] ?? 0;
          return '$fileName ($count uses)';
        }).toList();
        usageFilesStr = usageFiles.toString();
      }
      
      buffer.writeln(
          ' - $className (defined in $definedIn, internal uses: $internalUses, external uses: $externalUses, total: $totalUses)${externalUses > 0 ? ' $usageFilesStr' : ''}');
    }

    // Complete class listing - state classes
    buffer.writeln('\nCOMPLETE STATE CLASS USAGE LIST:');
    buffer.writeln('-' * 30);

    // Sort state classes by usage similarly to main classes
    stateClassEntries.sort((a, b) {
      final externalA = a.value.totalExternalUsages;
      final externalB = b.value.totalExternalUsages;
      
      if (externalB != externalA) {
        return externalB.compareTo(externalA); // Primary sort: external usages descending
      }
      
      final internalA = a.value.internalUsageCount;
      final internalB = b.value.internalUsageCount;
      
      return (internalB + externalB).compareTo(internalA + externalA); // Secondary sort: total usages descending
    });

    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsageCount;
      final externalUses = classInfo.totalExternalUsages;
      final totalUses = internalUses + externalUses;
      final definedIn = path.basename(classInfo.definedInFile);
      
      // Format the usage files list - empty for unused classes
      String usageFilesStr = '';
      if (externalUses > 0) {
        final usageFiles = classInfo.externalUsageFiles.map((filePath) {
          final fileName = path.basename(filePath);
          final count = classInfo.externalUsages[filePath] ?? 0;
          return '$fileName ($count uses)';
        }).toList();
        usageFilesStr = usageFiles.toString();
      }
      
      buffer.writeln(
          ' - $className (defined in $definedIn, internal uses: $internalUses, external uses: $externalUses, total: $totalUses)${externalUses > 0 ? ' $usageFilesStr' : ''}');
    }

    // Add summary
    buffer.writeln('\nSUMMARY:');
    buffer.writeln('-' * 30);
    buffer.writeln('Total classes: ${classes.length}');
    buffer.writeln('Main classes: ${mainClassEntries.length}');
    buffer.writeln('State classes: ${stateClassEntries.length}');
    buffer.writeln(
        'Unused main classes: $unusedCount (${(unusedCount / mainClassEntries.length * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Unused state classes: $stateClassCount (${(stateClassCount / (stateClassEntries.length > 0 ? stateClassEntries.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Internal-only main classes: $internalOnlyCount (${(internalOnlyCount / mainClassEntries.length * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Rarely used externally main classes (1-2 external usages): $rarelyUsedCount (${(rarelyUsedCount / mainClassEntries.length * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Rarely used externally state classes (1-2 external usages): $rarelyUsedStateCount (${(rarelyUsedStateCount / (stateClassEntries.length > 0 ? stateClassEntries.length : 1) * 100).toStringAsFixed(1)}%)');

    // Write to file
    final file = File(filePath);
    file.writeAsStringSync(buffer.toString());

    print('\nFull analysis saved to: $filePath');
  } catch (e) {
    print('\nError saving results to file: $e');
  }
}
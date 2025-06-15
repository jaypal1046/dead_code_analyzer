import 'dart:io';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:path/path.dart' as path;

class DeadCodeCleaner {
  static void deadCodeCleaner({
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required String projectPath,
    required bool analyzeFunctions,
  }) {
    // Group classes and functions by file
    final Map<String, List<dynamic>> entitiesByFile = {};

    // Add classes to the map
    for (final entry in classes.entries) {
      final classInfo = entry.value;
      entitiesByFile
          .putIfAbsent(classInfo.definedInFile, () => [])
          .add(classInfo);
    }

    // Add functions to the map if analyzing functions
    if (analyzeFunctions) {
      for (final entry in functions.entries) {
        final functionInfo = entry.value;
        entitiesByFile
            .putIfAbsent(functionInfo.definedInFile, () => [])
            .add(functionInfo);
      }
    }

    // Collect files with only dead or commented entities
    final filesToDelete = <String>[];
    final filesWithIssues = <String, String>{};

    for (final entry in entitiesByFile.entries) {
      final filePath = entry.key;
      final entities = entry.value;

      // Check if all entities in the file are either commented-out or unused
      bool allDeadOrCommented = entities.every((entity) {
        if (entity is ClassInfo) {
          return entity.totalUsages == 0 || entity.commentedOut;
        } else if (entity is CodeInfo) {
          return entity.totalUsages == 0 ||
              entity.commentedOut ||
              entity.isPrebuiltFlutter;
        }
        return false;
      });

      if (allDeadOrCommented) {
        // Check for other used entities (variables or non-analyzed entities)
        if (!_hasUsedEntities(filePath, classes, functions, analyzeFunctions)) {
          filesToDelete.add(filePath);
        } else {
          filesWithIssues[filePath] =
              'Contains other used entities (e.g., variables).';
        }
      } else {
        filesWithIssues[filePath] =
            'Contains used classes or functions that are not commented out.';
      }
    }

    // Print files that cannot be deleted
    if (filesWithIssues.isNotEmpty) {
      print('\nThe following files cannot be deleted:');
      for (final entry in filesWithIssues.entries) {
        final relativePath = toLibRelativePath(entry.key, projectPath);
        print(' - $relativePath: ${entry.value}');
      }
    }

    // Prompt for confirmation if there are files to delete
    if (filesToDelete.isNotEmpty) {
      print(
          '\nThe following files contain only dead or commented-out classes/functions and are eligible for deletion:');
      for (final filePath in filesToDelete) {
        final relativePath = toLibRelativePath(filePath, projectPath);
        print(' - $relativePath');
      }
      print(
          '\nWARNING: Deleting files may affect useful code due to edge cases (e.g., dynamic calls, reflection, or external references not detected by the analyzer).');
      print('We strongly recommend reviewing and deleting files manually.');
      print('Are you sure you want to delete these files? (y/N): ');

      final response = stdin.readLineSync()?.trim().toLowerCase();
      if (response != 'y') {
        print('Deletion cancelled.');
        return;
      }

      // Perform deletion
      for (final filePath in filesToDelete) {
        try {
          File(filePath).deleteSync();
          print('Deleted: ${toLibRelativePath(filePath, projectPath)}');
        } catch (e) {
          print('Error deleting $filePath: $e');
        }
      }
      print('Cleanup completed.');
    } else {
      print(
          '\nNo files eligible for deletion (all files with dead or commented classes/functions contain other used entities).');
    }
  }

// Helper function to check for used entities (classes, functions, variables)
  static bool _hasUsedEntities(String filePath, Map<String, ClassInfo> classes,
      Map<String, CodeInfo> functions, bool analyzeFunctions) {
    // Check for used classes in the file
    for (final classInfo in classes.values) {
      if (classInfo.definedInFile == filePath &&
          classInfo.totalUsages > 0 &&
          !classInfo.commentedOut) {
        return true;
      }
    }

    // Check for used functions in the file (if analyzeFunctions is true)
    if (analyzeFunctions) {
      for (final functionInfo in functions.values) {
        if (functionInfo.definedInFile == filePath &&
            functionInfo.totalUsages > 0 &&
            !functionInfo.commentedOut &&
            !functionInfo.isPrebuiltFlutter) {
          return true;
        }
      }
    }

    // Check for variables or other entities
    try {
      final content = File(filePath).readAsStringSync();
      final lines = content.split('\n');
      final variableRegex = RegExp(
          r'^(?:\s*(?:\/\/.*|\/\*.*\*\/)?\s*)*(?:var|final|const)?\s*([A-Za-z_][A-Za-z0-9_]*)\s*[=;]',
          multiLine: true);
      for (final line in lines) {
        if (variableRegex.hasMatch(line.trim()) &&
            !line.trim().startsWith('//') &&
            !line.trim().startsWith('/*')) {
          return true; // Found a variable declaration
        }
      }
    } catch (e) {
      print('Warning: Could not read $filePath for variable check: $e');
    }

    return false;
  }

// Reuse toLibRelativePath from console_reporter.dart
  static String toLibRelativePath(String absolutePath, String projectPath) {
    final libPath = path.join(projectPath, 'lib');
    if (absolutePath.startsWith(libPath)) {
      return path.relative(absolutePath, from: libPath);
    }
    return path.relative(absolutePath, from: projectPath);
  }
}

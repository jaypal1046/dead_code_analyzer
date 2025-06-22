import 'dart:io';
import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:path/path.dart' as path;

/// Handles cleanup of dead code files
class DeadCodeCleaner {
  /// Performs cleanup of files containing only dead or commented-out code
  static Future<void> performCleanup({
    required Map<String, ClassInfo> classes,
    required Map<String, CodeInfo> functions,
    required String projectPath,
    required bool analyzeFunctions,
  }) async {
    final cleaner = DeadCodeCleaner._(
      classes: classes,
      functions: functions,
      projectPath: projectPath,
      analyzeFunctions: analyzeFunctions,
    );

    await cleaner._executeCleanup();
  }

  const DeadCodeCleaner._({
    required this.classes,
    required this.functions,
    required this.projectPath,
    required this.analyzeFunctions,
  });

  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;
  final String projectPath;
  final bool analyzeFunctions;

  /// Executes the cleanup process
  Future<void> _executeCleanup() async {
    final entitiesByFile = _groupEntitiesByFile();
    final analysisResult = _analyzeFiles(entitiesByFile);

    _printFilesWithIssues(analysisResult.filesWithIssues);

    if (analysisResult.filesToDelete.isNotEmpty) {
      await _handleFileDeletion(analysisResult.filesToDelete);
    } else {
      _printNoFilesEligible();
    }
  }

  /// Groups all entities (classes and functions) by their file paths
  Map<String, List<dynamic>> _groupEntitiesByFile() {
    final Map<String, List<dynamic>> entitiesByFile = {};

    // Group classes by file
    for (final classInfo in classes.values) {
      entitiesByFile
          .putIfAbsent(classInfo.definedInFile, () => [])
          .add(classInfo);
    }

    // Group functions by file if analyzing functions
    if (analyzeFunctions) {
      for (final functionInfo in functions.values) {
        entitiesByFile
            .putIfAbsent(functionInfo.definedInFile, () => [])
            .add(functionInfo);
      }
    }

    return entitiesByFile;
  }

  /// Analyzes files to determine which can be deleted
  FileAnalysisResult _analyzeFiles(Map<String, List<dynamic>> entitiesByFile) {
    final filesToDelete = <String>[];
    final filesWithIssues = <String, String>{};

    for (final entry in entitiesByFile.entries) {
      final filePath = entry.key;
      final entities = entry.value;

      if (_areAllEntitiesDeadOrCommented(entities)) {
        if (!_hasUsedEntities(filePath)) {
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

    return FileAnalysisResult(
      filesToDelete: filesToDelete,
      filesWithIssues: filesWithIssues,
    );
  }

  /// Checks if all entities in a list are either dead or commented out
  bool _areAllEntitiesDeadOrCommented(List<dynamic> entities) {
    return entities.every((entity) {
      if (entity is ClassInfo) {
        return entity.totalUsages == 0 || entity.commentedOut;
      } else if (entity is CodeInfo) {
        return entity.totalUsages == 0 ||
            entity.commentedOut ||
            entity.isPrebuiltFlutter;
      }
      return false;
    });
  }

  /// Checks if a file contains any used entities (classes, functions, or variables)
  bool _hasUsedEntities(String filePath) {
    return _hasUsedClasses(filePath) ||
        _hasUsedFunctions(filePath) ||
        _hasUsedVariables(filePath);
  }

  /// Checks for used classes in the specified file
  bool _hasUsedClasses(String filePath) {
    return classes.values.any((classInfo) =>
        classInfo.definedInFile == filePath &&
        classInfo.totalUsages > 0 &&
        !classInfo.commentedOut);
  }

  /// Checks for used functions in the specified file
  bool _hasUsedFunctions(String filePath) {
    if (!analyzeFunctions) return false;

    return functions.values.any((functionInfo) =>
        functionInfo.definedInFile == filePath &&
        functionInfo.totalUsages > 0 &&
        !functionInfo.commentedOut &&
        !functionInfo.isPrebuiltFlutter);
  }

  /// Checks for used variables in the specified file
  bool _hasUsedVariables(String filePath) {
    try {
      final content = File(filePath).readAsStringSync();
      return _containsVariableDeclarations(content);
    } on FileSystemException catch (e) {
      print('Warning: Could not read $filePath for variable check: $e');
      return false;
    }
  }

  /// Checks if content contains variable declarations
  bool _containsVariableDeclarations(String content) {
    final lines = content.split('\n');
    final variableRegex = RegExp(
      r'^(?:\s*(?:\/\/.*|\/\*.*\*\/)?\s*)*(?:var|final|const)?\s*([A-Za-z_][A-Za-z0-9_]*)\s*[=;]',
      multiLine: true,
    );

    return lines.any((line) {
      final trimmedLine = line.trim();
      return variableRegex.hasMatch(trimmedLine) &&
          !trimmedLine.startsWith('//') &&
          !trimmedLine.startsWith('/*');
    });
  }

  /// Prints files that have issues and cannot be deleted
  void _printFilesWithIssues(Map<String, String> filesWithIssues) {
    if (filesWithIssues.isEmpty) return;

    print('\nThe following files cannot be deleted:');
    for (final entry in filesWithIssues.entries) {
      final relativePath = _toLibRelativePath(entry.key);
      print(' - $relativePath: ${entry.value}');
    }
  }

  /// Handles the file deletion process with user confirmation
  Future<void> _handleFileDeletion(List<String> filesToDelete) async {
    _printFilesEligibleForDeletion(filesToDelete);
    _printDeletionWarning();

    if (await _getUserConfirmation()) {
      await _deleteFiles(filesToDelete);
      print('Cleanup completed.');
    } else {
      print('Deletion cancelled.');
    }
  }

  /// Prints files that are eligible for deletion
  void _printFilesEligibleForDeletion(List<String> filesToDelete) {
    print(
        '\nThe following files contain only dead or commented-out classes/functions and are eligible for deletion:');
    for (final filePath in filesToDelete) {
      final relativePath = _toLibRelativePath(filePath);
      print(' - $relativePath');
    }
  }

  /// Prints deletion warning message
  void _printDeletionWarning() {
    print('\nWARNING: Deleting files may affect useful code due to edge cases '
        '(e.g., dynamic calls, reflection, or external references not detected by the analyzer).');
    print('We strongly recommend reviewing and deleting files manually.');
  }

  /// Gets user confirmation for file deletion
  Future<bool> _getUserConfirmation() async {
    print('Are you sure you want to delete these files? (y/N): ');
    final response = stdin.readLineSync()?.trim().toLowerCase();
    return response == 'y';
  }

  /// Deletes the specified files
  Future<void> _deleteFiles(List<String> filesToDelete) async {
    for (final filePath in filesToDelete) {
      try {
        await File(filePath).delete();
        print('Deleted: ${_toLibRelativePath(filePath)}');
      } on FileSystemException catch (e) {
        print('Error deleting $filePath: $e');
      }
    }
  }

  /// Prints message when no files are eligible for deletion
  void _printNoFilesEligible() {
    print('\nNo files eligible for deletion (all files with dead or commented '
        'classes/functions contain other used entities).');
  }

  /// Converts absolute path to lib-relative path
  String _toLibRelativePath(String absolutePath) {
    final libPath = path.join(projectPath, 'lib');
    if (absolutePath.startsWith(libPath)) {
      return path.relative(absolutePath, from: libPath);
    }
    return path.relative(absolutePath, from: projectPath);
  }
}

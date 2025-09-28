import 'package:dead_code_analyzer/dead_code_analyzer.dart';

class ClassUsage {
  static void analyzeClassUsages({
    required String content,
    required String filePath,
    required Map<String, ClassInfo> classes,
    required List<ImportInfo> exportList,
  }) {
    // Parse all imports in the current file
    final imports = parseImports(content);

    for (final entry in classes.entries) {
      final className = entry.key;
      final classInfo = entry.value;

      // If analyzing the same file where class is defined
      if (filePath == classInfo.definedInFile) {
        final usageCount = _countClassUsages(
          content,
          className,
          isInternalFile: true,
        );
        classInfo.internalUsageCount = usageCount;
      } else {
        // Check if class is accessible via imports or exports
        if (!isClassAccessibleInFile(
          className,
          classInfo.definedInFile,
          filePath, // Added missing parameter
          imports,
          exportList,
        )) {
          continue; // Skip if class is not accessible
        }

        // Get the effective class name (with alias if applicable)
        final effectiveClassName = getEffectiveClassName(
          className,
          classInfo.definedInFile,
          imports,
          exportList,
        );

        final usageCount = _countClassUsages(
          content,
          effectiveClassName,
          isInternalFile: false,
        );

        if (usageCount > 0) {
          classInfo.externalUsages[filePath] = usageCount;
        }
      }
    }
  }

  static int _countClassUsages(
    String content,
    String className, {
    required bool isInternalFile,
  }) {
    final lines = content.split('\n');
    int totalUsages = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip empty lines and comments
      if (line.isEmpty || line.startsWith('//') || line.startsWith('/*')) {
        continue;
      }

      // Skip class definition line if it's internal file
      if (isInternalFile && _isClassDefinitionLine(line, className)) {
        continue;
      }

      final usageCount = _countUsagesInLine(line, className);
      totalUsages += usageCount;
    }

    return totalUsages;
  }

  static int _countUsagesInLine(String line, String className) {
    // Remove strings and comments from the line for accurate counting
    final cleanLine = _removeStringsAndComments(line);

    if (cleanLine.isEmpty) return 0;

    int usageCount = 0;

    // Pattern 1: Variable declaration with initialization
    // Example: MyWidget widget = MyWidget();
    final declarationWithInitPattern = RegExp(
      r'\b' +
          RegExp.escape(className) +
          r'\s+\w+\s*=\s*' +
          RegExp.escape(className) +
          r'\s*\(',
    );
    if (declarationWithInitPattern.hasMatch(cleanLine)) {
      usageCount += 1; // Count as single usage
      // Remove this pattern to avoid double counting
      final updatedLine = cleanLine.replaceAll(declarationWithInitPattern, '');
      return usageCount + _countRemainingUsages(updatedLine, className);
    }

    // Pattern 2: Constructor calls (standalone)
    // Example: MyWidget(), new MyWidget()
    final constructorPattern = RegExp(
      r'(?:new\s+)?' + RegExp.escape(className) + r'\s*\(',
    );
    final constructorMatches = constructorPattern.allMatches(cleanLine);
    usageCount += constructorMatches.length;

    // Pattern 3: Type declarations (without constructor)
    // Example: MyWidget widget; List<MyWidget> widgets;
    final typeDeclarationPattern = RegExp(
      r'\b' +
          RegExp.escape(className) +
          r'(?:\s+\w+\s*[;,]|\s*>\s*|\s+\w+\s*(?:=(?!' +
          RegExp.escape(className) +
          r'\s*\()))',
    );
    final typeMatches = typeDeclarationPattern.allMatches(cleanLine);
    usageCount += typeMatches.length;

    // Pattern 4: Static method/property access
    // Example: MyWidget.staticMethod(), MyWidget.staticProperty
    final staticAccessPattern = RegExp(
      r'\b' + RegExp.escape(className) + r'\.\w+',
    );
    final staticMatches = staticAccessPattern.allMatches(cleanLine);
    usageCount += staticMatches.length;

    // Pattern 5: Type casting and is/as checks
    // Example: widget as MyWidget, widget is MyWidget
    final castingPattern = RegExp(
      r'\b(?:as|is)\s+' + RegExp.escape(className) + r'\b',
    );
    final castingMatches = castingPattern.allMatches(cleanLine);
    usageCount += castingMatches.length;

    // Pattern 6: Generic type parameters
    // Example: List<MyWidget>, Map<String, MyWidget>
    final genericPattern = RegExp(
      r'<[^>]*\b' + RegExp.escape(className) + r'\b[^>]*>',
    );
    final genericMatches = genericPattern.allMatches(cleanLine);
    usageCount += genericMatches.length;

    // Pattern 7: Function parameters and return types
    // Example: void method(MyWidget widget), MyWidget getWidget()
    final functionParamPattern = RegExp(
      r'\(\s*[^)]*\b' + RegExp.escape(className) + r'\s+\w+[^)]*\)',
    );
    final returnTypePattern = RegExp(
      r'\b' + RegExp.escape(className) + r'\s+\w+\s*\(',
    );

    final paramMatches = functionParamPattern.allMatches(cleanLine);
    final returnMatches = returnTypePattern.allMatches(cleanLine);
    usageCount += paramMatches.length + returnMatches.length;

    return usageCount;
  }

  static int _countRemainingUsages(String line, String className) {
    // Count any remaining usages after removing the main pattern
    final remainingPattern = RegExp(r'\b' + RegExp.escape(className) + r'\b');
    final matches = remainingPattern.allMatches(line);

    int count = 0;
    for (final match in matches) {
      // Additional context checks can be added here
      if (!_isInStringLiteral(line, match.start)) {
        count++;
      }
    }

    return count;
  }

  static String _removeStringsAndComments(String line) {
    // Remove string literals (both single and double quotes)
    String cleaned = line.replaceAll(RegExp(r"'[^']*'"), '');
    cleaned = cleaned.replaceAll(RegExp(r'"[^"]*"'), '');

    // Remove single-line comments
    final commentIndex = cleaned.indexOf('//');
    if (commentIndex != -1) {
      cleaned = cleaned.substring(0, commentIndex);
    }

    return cleaned.trim();
  }

  static bool _isClassDefinitionLine(String line, String className) {
    // Check for class definition patterns
    final classDefPatterns = [
      RegExp(r'\bclass\s+' + RegExp.escape(className) + r'\b'),
      RegExp(r'\babstract\s+class\s+' + RegExp.escape(className) + r'\b'),
      RegExp(r'\bmixin\s+' + RegExp.escape(className) + r'\b'),
      RegExp(r'\benum\s+' + RegExp.escape(className) + r'\b'),
    ];

    return classDefPatterns.any((pattern) => pattern.hasMatch(line));
  }

  static bool _isInStringLiteral(String line, int position) {
    // Simple check to see if position is within string literals
    final beforePosition = line.substring(0, position);
    final singleQuoteCount = beforePosition.split("'").length - 1;
    final doubleQuoteCount = beforePosition.split('"').length - 1;

    // If odd number of quotes before position, we're inside a string
    return (singleQuoteCount % 2 == 1) || (doubleQuoteCount % 2 == 1);
  }

  static List<ImportInfo> parseImports(String content) {
    final imports = <ImportInfo>[];

    // Parse regular imports
    final importRegex = RegExp(
      r'''import\s+['\"]([^'\"]+)['\"]\s*(?:as\s+(\w+))?\s*(?:(show|hide)\s+([^;]+))?\s*;''',
      multiLine: true,
    );

    final importMatches = importRegex.allMatches(content);

    for (final match in importMatches) {
      final path = match.group(1)!;
      final asAlias = match.group(2);
      final showHideKeyword = match.group(3);
      final showHideItems = match.group(4);

      List<String> hiddenClasses = [];
      List<String> shownClasses = [];
      List<String> hiddenFunctions = [];
      List<String> shownFunctions = [];

      if (showHideKeyword != null && showHideItems != null) {
        final itemsList = showHideItems
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        // For simplicity, treating all items as classes. In real implementation,
        // you might want to distinguish between classes and functions
        if (showHideKeyword == 'hide') {
          hiddenClasses = itemsList;
        } else if (showHideKeyword == 'show') {
          shownClasses = itemsList;
        }
      }

      imports.add(
        ImportInfo(
          path: path,
          asAlias: asAlias,
          hiddenClasses: hiddenClasses,
          shownClasses: shownClasses,
          hiddenFunctions: hiddenFunctions,
          shownFunctions: shownFunctions,
          isExport: false,
          isWildcardExport: false,
        ),
      );
    }

    // Parse exports
    final exportRegex = RegExp(
      r'''export\s+['\"]([^'\"]+)['\"]\s*(?:(show|hide)\s+([^;]+))?\s*;''',
      multiLine: true,
    );

    final exportMatches = exportRegex.allMatches(content);

    for (final match in exportMatches) {
      final path = match.group(1)!;
      final showHideKeyword = match.group(2);
      final showHideItems = match.group(3);

      List<String> hiddenClasses = [];
      List<String> shownClasses = [];
      List<String> hiddenFunctions = [];
      List<String> shownFunctions = [];

      if (showHideKeyword != null && showHideItems != null) {
        final itemsList = showHideItems
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (showHideKeyword == 'hide') {
          hiddenClasses = itemsList;
        } else if (showHideKeyword == 'show') {
          shownClasses = itemsList;
        }
      }

      imports.add(
        ImportInfo(
          path: path,
          hiddenClasses: hiddenClasses,
          shownClasses: shownClasses,
          hiddenFunctions: hiddenFunctions,
          shownFunctions: shownFunctions,
          isExport: true,
          isWildcardExport: false,
        ),
      );
    }

    return imports;
  }

  static bool isClassAccessibleInFile(
    String className,
    String classDefinedInFile,
    String currentFile,
    List<ImportInfo> imports,
    List<ImportInfo> exportList, {
    LibraryInfo? currentLibraryInfo,
    Map<String, LibraryInfo>? libraryCache,
    bool checkPrivateMembers = true,
  }) {
    print(
      "Checking accessibility: $className from $classDefinedInFile in $currentFile",
    );

    // Rule 0: Check if class name suggests it's private (starts with _)
    if (checkPrivateMembers && className.startsWith('_')) {
      // Private classes are only accessible within the same library
      if (!_areInSameLibrary(
        classDefinedInFile,
        currentFile,
        currentLibraryInfo,
      )) {
        print("Private class access denied: different libraries");
        return false;
      }
    }

    // Rule 1: If class is defined in the same file, it's always accessible
    if (_pathsAreEquivalent(classDefinedInFile, currentFile)) {
      print("Same file access: true");
      return true;
    }

    // Rule 2: Check part/library relationships
    if (currentLibraryInfo != null) {
      if (_areInSameLibrary(
        classDefinedInFile,
        currentFile,
        currentLibraryInfo,
      )) {
        print("Same library access (part/library): true");
        return true;
      }
    }

    // Rule 3: Check if class is accessible through imports
    for (final importItem in imports) {
      if (!importItem.isExport &&
          _isImportMatching(importItem, classDefinedInFile)) {
        bool accessible = _isClassAccessibleThroughImport(
          className,
          importItem,
        );
        print("Import check for ${importItem.path}: $accessible");
        if (accessible) return true;
      }
    }

    // Rule 4: Check transitive exports (library re-exports)
    for (final export in exportList) {
      if (export.isExport && _isImportMatching(export, classDefinedInFile)) {
        bool accessible = _isClassAccessibleThroughImport(className, export);
        print("Export check for ${export.path}: $accessible");
        if (accessible) return true;
      }
    }

    // Rule 5: Check if it's a core Dart/Flutter library (implicitly available)
    if (_isCoreLibrary(classDefinedInFile)) {
      print("Core library access: true");
      return true;
    }

    // Rule 6: Check if it's available through implicit dart:core imports
    if (_isImplicitlyAvailable(className)) {
      print("Implicitly available class: true");
      return true;
    }

    print("Class not accessible");
    return false;
  }

  // Check if an import/export matches the file where class is defined
  static bool _isImportMatching(
    ImportInfo importInfo,
    String classDefinedInFile,
  ) {
    // Try multiple comparison methods

    // Method 1: Direct path comparison
    if (_pathsAreEquivalent(importInfo.path, classDefinedInFile)) {
      return true;
    }

    // Method 2: Use sourceFile if available
    if (importInfo.sourceFile != null &&
        _pathsAreEquivalent(importInfo.sourceFile!, classDefinedInFile)) {
      return true;
    }

    // Method 3: Convert both to package URI and compare
    String importPackageUri = _convertFilePathToPackageUri(importInfo.path);
    String filePackageUri = _convertFilePathToPackageUri(classDefinedInFile);
    if (importPackageUri == filePackageUri) {
      return true;
    }

    return false;
  }

  // Check if a class is accessible through a specific import/export
  static bool _isClassAccessibleThroughImport(
    String className,
    ImportInfo importInfo,
  ) {
    // Handle different import types

    // Case 1: import 'package:foo/bar.dart' as prefix;
    // In this case, class is accessible as prefix.ClassName
    if (importInfo.asAlias != null && importInfo.asAlias!.isNotEmpty) {
      // For prefixed imports, we need to check if the usage includes the prefix
      // This is complex to handle here, might need context from usage site
      return true; // Assume accessible for now, but this needs refinement
    }

    // Case 2: import 'package:foo/bar.dart' hide ClassName1, ClassName2;
    if (importInfo.hiddenClasses.contains(className)) {
      return false; // Explicitly hidden
    }

    // Case 3: import 'package:foo/bar.dart' show ClassName1, ClassName2;
    if (importInfo.shownClasses.isNotEmpty) {
      return importInfo.shownClasses.contains(className);
    }

    // Case 4: Check if it's a wildcard export
    if (importInfo.isWildcardExport) {
      return true; // All items are exported
    }

    // Case 5: import 'package:foo/bar.dart'; (no restrictions)
    return true;
  }

  // Check if two files are in the same library (considering part files)
  static bool _areInSameLibrary(
    String file1,
    String file2,
    LibraryInfo? libraryInfo,
  ) {
    if (libraryInfo == null) return false;

    // String normalizedFile1 = _normalizePath(file1);
    // String normalizedFile2 = _normalizePath(file2);

    // Check if both files are the main library file
    if (_pathsAreEquivalent(file1, libraryInfo.path) &&
        _pathsAreEquivalent(file2, libraryInfo.path)) {
      return true;
    }

    // Check if both files are in the parts list
    bool file1IsPart = libraryInfo.parts.any(
      (part) => _pathsAreEquivalent(part, file1),
    );
    bool file2IsPart = libraryInfo.parts.any(
      (part) => _pathsAreEquivalent(part, file2),
    );

    if (file1IsPart && file2IsPart) return true;

    // Check if one is main library and other is part
    bool file1IsMain = _pathsAreEquivalent(file1, libraryInfo.path);
    bool file2IsMain = _pathsAreEquivalent(file2, libraryInfo.path);

    return (file1IsMain && file2IsPart) || (file2IsMain && file1IsPart);
  }

  // Check if class is implicitly available (from dart:core)
  static bool _isImplicitlyAvailable(String className) {
    // Common dart:core classes that are always available
    const dartCoreClasses = [
      'Object',
      'String',
      'int',
      'double',
      'bool',
      'List',
      'Map',
      'Set',
      'Iterable',
      'Iterator',
      'Function',
      'Symbol',
      'Type',
      'Null',
      'dynamic',
      'void',
      'Never',
      'Future',
      'Stream',
      'Duration',
      'DateTime',
      'RegExp',
      'StringBuffer',
      'Exception',
      'Error',
      'ArgumentError',
      'StateError',
      'UnsupportedError',
      'UnimplementedError',
      'FormatException',
      'IntegerDivisionByZeroException',
      'RangeError',
      'IndexError',
      'NoSuchMethodError',
      'AbstractClassInstantiationError',
      'CyclicInitializationError',
      'UnsupportedError',
    ];

    return dartCoreClasses.contains(className);
  }

  // Check if two paths refer to the same file
  static bool _pathsAreEquivalent(String path1, String path2) {
    // Normalize both paths
    String normalized1 = _normalizePath(path1);
    String normalized2 = _normalizePath(path2);

    // Direct comparison
    if (normalized1 == normalized2) return true;

    // Try converting both to package URIs and compare
    String packageUri1 = _convertFilePathToPackageUri(normalized1);
    String packageUri2 = _convertFilePathToPackageUri(normalized2);

    return packageUri1 == packageUri2;
  }

  // Normalize path for comparison
  static String _normalizePath(String path) {
    return path
        .replaceAll('\\', '/')
        .replaceAll('//', '/')
        .toLowerCase(); // Case-insensitive comparison for Windows
  }

  // Check if it's a core library that's implicitly available
  static bool _isCoreLibrary(String filePath) {
    String normalized = _normalizePath(filePath);

    return normalized.startsWith('dart:') ||
        normalized.contains('package:flutter/') ||
        normalized.contains('package:dart/');
  }

  // Improved path to package URI conversion
  static String _convertFilePathToPackageUri(String filePath) {
    String normalizedPath = _normalizePath(filePath);

    // If it's already a package URI, return as is
    if (normalizedPath.startsWith('package:') ||
        normalizedPath.startsWith('dart:')) {
      return normalizedPath;
    }

    // Handle different project structures

    // Pattern 1: Standard Flutter/Dart project structure
    // Example: C:/Jay/confidencial/il_takecare/lib/utils/route/route_name.dart
    // Should become: package:il_takecare/utils/route/route_name.dart
    RegExp standardPattern = RegExp(r'.*[/\\]([^/\\]+)[/\\]lib[/\\](.*)');
    Match? match = standardPattern.firstMatch(normalizedPath);

    if (match != null) {
      String packageName = match.group(1)!;
      String relativePath = match.group(2)!;
      return 'package:$packageName/$relativePath';
    }

    // Pattern 2: Nested project structure
    // Handle cases where there might be multiple nested folders
    RegExp nestedPattern = RegExp(r'.*[/\\]lib[/\\](.*)');
    match = nestedPattern.firstMatch(normalizedPath);

    if (match != null) {
      // Try to extract package name from path
      String beforeLib = normalizedPath.substring(
        0,
        normalizedPath.lastIndexOf('/lib/'),
      );
      String packageName = beforeLib.split('/').last;
      String relativePath = match.group(1)!;
      return 'package:$packageName/$relativePath';
    }

    // If no pattern matches, return normalized path
    return normalizedPath;
  }

  static String getEffectiveClassName(
    String originalClassName,
    String classDefinedInFile,
    List<ImportInfo> imports,
    List<ImportInfo> exportList,
  ) {
    // Check imports first
    for (final import in imports) {
      if (!import.isExport && import.path == classDefinedInFile) {
        // If import has 'as' alias, the class should be accessed via alias
        if (import.asAlias != null) {
          return '${import.asAlias}.$originalClassName';
        }
        return originalClassName;
      }
    }

    // Check exports
    for (final export in exportList) {
      if (export.isExport && export.sourceFile == classDefinedInFile) {
        // If export has 'as' alias, the class should be accessed via alias
        if (export.asAlias != null) {
          return '${export.asAlias}.$originalClassName';
        }
        return originalClassName;
      }
    }

    return originalClassName;
  }
}

class LibraryInfo {
  final String name;
  final String path;
  final List<ImportInfo> imports;
  final List<ExportInfo> exports;
  final List<String> parts; // For part files
  final String? partOf; // If this file is part of another library

  LibraryInfo({
    required this.name,
    required this.path,
    this.imports = const [],
    this.exports = const [],
    this.parts = const [],
    this.partOf,
  });
}

class ExportInfo extends ImportInfo {
  final List<String> exportedClasses; // Specific classes being exported
  final bool isReExport; // Whether this is re-exporting from another library

  ExportInfo({
    required String path,
    String? sourceFile,
    String? asAlias, // Changed from 'prefix' to match parent class
    List<String> shownClasses = const [],
    List<String> hiddenClasses = const [],
    List<String> shownFunctions = const [], // Added to match parent class
    List<String> hiddenFunctions = const [], // Added to match parent class
    bool isWildcardExport = false, // Added to match parent class
    this.exportedClasses = const [],
    this.isReExport = false,
  }) : super(
         path: path,
         sourceFile: sourceFile,
         asAlias: asAlias, // Fixed parameter name
         shownClasses: shownClasses,
         hiddenClasses: hiddenClasses,
         shownFunctions: shownFunctions, // Added
         hiddenFunctions: hiddenFunctions, // Added
         isExport: true, // Always true for ExportInfo
         isWildcardExport: isWildcardExport, // Added
       );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['exportedClasses'] = exportedClasses;
    json['isReExport'] = isReExport;
    return json;
  }

  factory ExportInfo.fromJson(Map<String, dynamic> json) {
    return ExportInfo(
      path: json['path'] as String,
      asAlias: json['asAlias'] as String?,
      shownClasses: List<String>.from(json['shownClasses'] ?? []),
      hiddenClasses: List<String>.from(json['hiddenClasses'] ?? []),
      shownFunctions: List<String>.from(json['shownFunctions'] ?? []),
      hiddenFunctions: List<String>.from(json['hiddenFunctions'] ?? []),
      sourceFile: json['sourceFile'] as String?,
      isWildcardExport: json['isWildcardExport'] as bool? ?? false,
      exportedClasses: List<String>.from(json['exportedClasses'] ?? []),
      isReExport: json['isReExport'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'ExportInfo(path: $path, isReExport: $isReExport, '
        'exportedClasses: $exportedClasses, '
        'shownClasses: $shownClasses, hiddenClasses: $hiddenClasses, '
        'shownFunctions: $shownFunctions, hiddenFunctions: $hiddenFunctions, '
        'asAlias: $asAlias, sourceFile: $sourceFile, isWildcardExport: $isWildcardExport)';
  }
}

import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/import_info.dart';

void analyzeClassUsages(
    String content, String filePath, Map<String, ClassInfo> classes) {
  // Parse all imports in the current file
  final imports = parseImports(content);

  for (final entry in classes.entries) {
    final className = entry.key;
    final classInfo = entry.value;

    // If analyzing the same file where class is defined
    if (filePath == classInfo.definedInFile) {
      final usageCount =
          _countClassUsages(content, className, isInternalFile: true);
      classInfo.internalUsageCount = usageCount;
    } else {
      // For external files, check if there's a matching import
      if (!isClassAccessibleInFile(
          className, classInfo.definedInFile, imports)) {
        continue; // Skip if class is not accessible via imports
      }

      // Get the effective class name (with alias if applicable)
      final effectiveClassName =
          getEffectiveClassName(className, classInfo.definedInFile, imports);

      final usageCount =
          _countClassUsages(content, effectiveClassName, isInternalFile: false);

      if (usageCount > 0) {
        classInfo.externalUsages[filePath] = usageCount;
      }
    }
  }
}

int _countClassUsages(String content, String className,
    {required bool isInternalFile}) {
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

int _countUsagesInLine(String line, String className) {
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
  final constructorPattern =
      RegExp(r'(?:new\s+)?' + RegExp.escape(className) + r'\s*\(');
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
  final staticAccessPattern =
      RegExp(r'\b' + RegExp.escape(className) + r'\.\w+');
  final staticMatches = staticAccessPattern.allMatches(cleanLine);
  usageCount += staticMatches.length;

  // Pattern 5: Type casting and is/as checks
  // Example: widget as MyWidget, widget is MyWidget
  final castingPattern =
      RegExp(r'\b(?:as|is)\s+' + RegExp.escape(className) + r'\b');
  final castingMatches = castingPattern.allMatches(cleanLine);
  usageCount += castingMatches.length;

  // Pattern 6: Generic type parameters
  // Example: List<MyWidget>, Map<String, MyWidget>
  final genericPattern =
      RegExp(r'<[^>]*\b' + RegExp.escape(className) + r'\b[^>]*>');
  final genericMatches = genericPattern.allMatches(cleanLine);
  usageCount += genericMatches.length;

  // Pattern 7: Function parameters and return types
  // Example: void method(MyWidget widget), MyWidget getWidget()
  final functionParamPattern =
      RegExp(r'\(\s*[^)]*\b' + RegExp.escape(className) + r'\s+\w+[^)]*\)');
  final returnTypePattern =
      RegExp(r'\b' + RegExp.escape(className) + r'\s+\w+\s*\(');

  final paramMatches = functionParamPattern.allMatches(cleanLine);
  final returnMatches = returnTypePattern.allMatches(cleanLine);
  usageCount += paramMatches.length + returnMatches.length;

  return usageCount;
}

int _countRemainingUsages(String line, String className) {
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

String _removeStringsAndComments(String line) {
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

bool _isClassDefinitionLine(String line, String className) {
  // Check for class definition patterns
  final classDefPatterns = [
    RegExp(r'\bclass\s+' + RegExp.escape(className) + r'\b'),
    RegExp(r'\babstract\s+class\s+' + RegExp.escape(className) + r'\b'),
    RegExp(r'\bmixin\s+' + RegExp.escape(className) + r'\b'),
    RegExp(r'\benum\s+' + RegExp.escape(className) + r'\b'),
  ];

  return classDefPatterns.any((pattern) => pattern.hasMatch(line));
}

bool _isInStringLiteral(String line, int position) {
  // Simple check to see if position is within string literals
  final beforePosition = line.substring(0, position);
  final singleQuoteCount = beforePosition.split("'").length - 1;
  final doubleQuoteCount = beforePosition.split('"').length - 1;

  // If odd number of quotes before position, we're inside a string
  return (singleQuoteCount % 2 == 1) || (doubleQuoteCount % 2 == 1);
}

// Keep your existing helper functions
List<ImportInfo> parseImports(String content) {
  final imports = <ImportInfo>[];

  // Regex to match import statements with optional as, show, hide
  final importRegex = RegExp(
      r'''import\s+['\"]([^'\"]+)['\"]\s*(?:as\s+(\w+))?\s*(?:(show|hide)\s+([^;]+))?\s*;''',
      multiLine: true);

  final matches = importRegex.allMatches(content);

  for (final match in matches) {
    final path = match.group(1)!;
    final asAlias = match.group(2);
    final showHideKeyword = match.group(3);
    final showHideClasses = match.group(4);

    List<String> hiddenClasses = [];
    List<String> shownClasses = [];

    if (showHideKeyword != null && showHideClasses != null) {
      final classesList = showHideClasses
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (showHideKeyword == 'hide') {
        hiddenClasses = classesList;
      } else if (showHideKeyword == 'show') {
        shownClasses = classesList;
      }
    }

    imports.add(ImportInfo(
      path: path,
      asAlias: asAlias,
      hiddenClasses: hiddenClasses,
      shownClasses: shownClasses,
    ));
  }

  return imports;
}

bool isClassAccessibleInFile(
    String className, String classDefinedInFile, List<ImportInfo> imports) {
  // Check if there's an import that makes this class accessible
  for (final import in imports) {
    if (import.path == classDefinedInFile) {
      // Check if class is hidden
      if (import.hiddenClasses.contains(className)) {
        return false;
      }

      // Check if using 'show' and class is not in the show list
      if (import.shownClasses.isNotEmpty &&
          !import.shownClasses.contains(className)) {
        return false;
      }

      return true;
    }
  }

  return false;
}

String getEffectiveClassName(String originalClassName,
    String classDefinedInFile, List<ImportInfo> imports) {
  // Find the import that brings this class
  for (final import in imports) {
    if (import.path == classDefinedInFile) {
      // If import has 'as' alias, the class should be accessed via alias
      if (import.asAlias != null) {
        return '${import.asAlias}.$originalClassName';
      }
    }
  }

  return originalClassName;
}

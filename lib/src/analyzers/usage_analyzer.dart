import 'dart:io';
import 'dart:math';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:dead_code_analyzer/src/utils/progress_bar.dart';
import 'package:path/path.dart' as path;

void findUsages({
  required Directory dir,
  required Map<String, ClassInfo> classes,
  required Map<String, CodeInfo> functions,
  required bool showProgress,
  required bool analyzeFunctions,
}) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar =
        ProgressBar(dartFiles.length, description: 'Analyzing code usage');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = path.absolute(file.path);

    try {
      final content = File(filePath).readAsStringSync();

      // Analyze class usages
      _analyzeClassUsages(content, filePath, classes);

      // Analyze function usages
      if (analyzeFunctions) {
        _analyzeFunctionUsages(content, filePath, functions);
      }
    } catch (e) {
      print('\nWarning: Could not read file $filePath: $e');
    }

    count++;
    if (showProgress) {
      progressBar!.update(count);
    }
  }

  if (showProgress) {
    progressBar!.done();
  }
}

void _analyzeClassUsages(
    String content, String filePath, Map<String, ClassInfo> classes) {
  for (final entry in classes.entries) {
    final className = entry.key;
    final classInfo = entry.value;

    // Find all matches of the class name
    final usageRegex = RegExp(r'\b' + RegExp.escape(className) + r'\b');
    final matches = usageRegex.allMatches(content);

    if (matches.isEmpty) continue;

    // Get positions to exclude (definitions, constructors, etc.)
    final excludePositions = _getClassExcludePositions(content, className);

    // Filter matches by removing excluded positions
    final validMatches = matches.where((match) {
      return !_isPositionExcluded(match.start, match.end, excludePositions) &&
          !_isInComment(content, match.start) &&
          !_isInString(content, match.start);
    }).toList();

    final usageCount = validMatches.length;

    if (filePath == classInfo.definedInFile) {
      classInfo.internalUsageCount = usageCount;
    } else if (usageCount > 0) {
      classInfo.externalUsages[filePath] = usageCount;
    }
  }
}

void _analyzeFunctionUsages(
    String content, String filePath, Map<String, CodeInfo> functions) {
  for (final entry in functions.entries) {
    final functionName = entry.key;
    final functionInfo = entry.value;

    // Find all matches of the function name
    final usageRegex = RegExp(r'\b' + RegExp.escape(functionName) + r'\b');
    final matches = usageRegex.allMatches(content);

    if (matches.isEmpty) continue;

    // Get positions to exclude (function definitions)
    final excludePositions =
        _getFunctionExcludePositions(content, functionName);

    // Filter matches by removing excluded positions
    final validMatches = matches.where((match) {
      return !_isPositionExcluded(match.start, match.end, excludePositions) &&
          !_isInComment(content, match.start) &&
          !_isInString(content, match.start);
    }).toList();

    final usageCount = validMatches.length;

    if (filePath == functionInfo.definedInFile) {
      functionInfo.internalUsageCount = usageCount;
    } else if (usageCount > 0) {
      functionInfo.externalUsages[filePath] = usageCount;
    }
  }
}

List<_ExcludeRange> _getClassExcludePositions(
    String content, String className) {
  final excludePositions = <_ExcludeRange>[];

  // 1. Class declaration: class ClassName extends/implements/with
  final classDeclarationRegex = RegExp(
    r'\bclass\s+' +
        RegExp.escape(className) +
        r'\b(?:\s+(?:extends|implements|with)\s+[^{]*)?',
    multiLine: true,
  );
  for (final match in classDeclarationRegex.allMatches(content)) {
    final classNameStart =
        match.group(0)!.indexOf(className, match.group(0)!.indexOf('class'));
    excludePositions.add(_ExcludeRange(
      match.start + classNameStart,
      match.start + classNameStart + className.length,
    ));
  }

  // 2. Constructor definitions: ClassName(...) or const ClassName(...)
  final constructorRegex = RegExp(
    r'(?:^|\s)(?:const\s+)?' +
        RegExp.escape(className) +
        r'\s*\([^)]*\)\s*(?::\s*[^{]*)?(?:\{|;)',
    multiLine: true,
  );
  for (final match in constructorRegex.allMatches(content)) {
    final constructorStart = match.group(0)!.indexOf(className);
    if (constructorStart >= 0) {
      excludePositions.add(_ExcludeRange(
        match.start + constructorStart,
        match.start + constructorStart + className.length,
      ));
    }
  }

  // 3. State class definitions: _ClassNameState or State<ClassName>
  final stateClassRegex = RegExp(
    r'\b_' +
        RegExp.escape(className) +
        r'State\b|\bState\s*<\s*' +
        RegExp.escape(className) +
        r'\s*>',
    multiLine: true,
  );
  for (final match in stateClassRegex.allMatches(content)) {
    final stateMatch = match.group(0)!;
    final classNameIndex = stateMatch.indexOf(className);
    if (classNameIndex >= 0) {
      excludePositions.add(_ExcludeRange(
        match.start + classNameIndex,
        match.start + classNameIndex + className.length,
      ));
    }
  }

  // 4. createState method that might reference the class
  final createStateRegex = RegExp(
    r'\bcreateState\s*\(\s*\)\s*(?:=>\s*_?' +
        RegExp.escape(className) +
        r'State\s*\(\s*\)|{\s*return\s+_?' +
        RegExp.escape(className) +
        r'State\s*\(\s*\))',
    multiLine: true,
  );
  for (final match in createStateRegex.allMatches(content)) {
    final createStateMatch = match.group(0)!;
    final classNameIndex = createStateMatch.indexOf(className);
    if (classNameIndex >= 0) {
      excludePositions.add(_ExcludeRange(
        match.start + classNameIndex,
        match.start + classNameIndex + className.length,
      ));
    }
  }

  // 5. Factory constructors: factory ClassName.named()
  final factoryRegex = RegExp(
    r'\bfactory\s+' + RegExp.escape(className) + r'\.',
    multiLine: true,
  );
  for (final match in factoryRegex.allMatches(content)) {
    final factoryMatch = match.group(0)!;
    final classNameIndex = factoryMatch.indexOf(className);
    if (classNameIndex >= 0) {
      excludePositions.add(_ExcludeRange(
        match.start + classNameIndex,
        match.start + classNameIndex + className.length,
      ));
    }
  }

  return excludePositions;
}

List<_ExcludeRange> _getFunctionExcludePositions(
    String content, String functionName) {
  final excludePositions = <_ExcludeRange>[];

  // Function declarations with various return types
  final functionDeclarationRegex = RegExp(
    r'(?:^|\s)(?:static\s+)?(?:(?:void|int|double|String|bool|dynamic|List(?:<[^>]*>)?|Map(?:<[^,>]*,\s*[^>]*>)?|Set(?:<[^>]*>)?|Future(?:<[^>]*>)?|Stream(?:<[^>]*>)?|[A-Z][a-zA-Z0-9_]*(?:<[^>]*>)?)\s+)?' +
        RegExp.escape(functionName) +
        r'\s*\([^)]*\)\s*(?:async\s*)?(?:\{|=>|;)',
    multiLine: true,
  );

  for (final match in functionDeclarationRegex.allMatches(content)) {
    final functionMatch = match.group(0)!;
    final functionNameIndex = functionMatch.indexOf(functionName);
    if (functionNameIndex >= 0) {
      excludePositions.add(_ExcludeRange(
        match.start + functionNameIndex,
        match.start + functionNameIndex + functionName.length,
      ));
    }
  }

  // Getter/Setter declarations
  final getterSetterRegex = RegExp(
    r'(?:get|set)\s+' +
        RegExp.escape(functionName) +
        r'\s*(?:\([^)]*\))?\s*(?:=>|{)',
    multiLine: true,
  );

  for (final match in getterSetterRegex.allMatches(content)) {
    final getterSetterMatch = match.group(0)!;
    final functionNameIndex = getterSetterMatch.indexOf(functionName);
    if (functionNameIndex >= 0) {
      excludePositions.add(_ExcludeRange(
        match.start + functionNameIndex,
        match.start + functionNameIndex + functionName.length,
      ));
    }
  }

  return excludePositions;
}

bool _isPositionExcluded(
    int start, int end, List<_ExcludeRange> excludeRanges) {
  for (final range in excludeRanges) {
    if (start >= range.start && end <= range.end) {
      return true;
    }
  }
  return false;
}

bool _isInComment(String content, int position) {
  // Find the line containing this position
  final beforePosition = content.substring(0, position);
  final lastNewline = beforePosition.lastIndexOf('\n');
  final line = content.substring(
    lastNewline + 1,
    content.indexOf('\n', position) == -1
        ? content.length
        : content.indexOf('\n', position),
  );
  final positionInLine = position - lastNewline - 1;

  // Check for single-line comments
  final singleLineComment = line.indexOf('//');
  if (singleLineComment != -1 && singleLineComment <= positionInLine) {
    return true;
  }

  // Check for multi-line comments
  final beforePositionContent = content.substring(0, position);
  int commentStart = -1;
  int searchIndex = 0;

  while (true) {
    final start = beforePositionContent.indexOf('/*', searchIndex);
    if (start == -1) break;

    final end = content.indexOf('*/', start);
    if (end == -1 || end > position) {
      commentStart = start;
      break;
    }

    searchIndex = end + 2;
  }

  return commentStart != -1;
}

bool _isInString(String content, int position) {
  // Simple string detection - check if we're between quotes
  final beforePosition = content.substring(0, position);

  // Count unescaped quotes
  int singleQuotes = 0;
  int doubleQuotes = 0;
  bool escaped = false;

  for (int i = 0; i < beforePosition.length; i++) {
    final char = beforePosition[i];

    if (escaped) {
      escaped = false;
      continue;
    }

    if (char == '\\') {
      escaped = true;
      continue;
    }

    if (char == "'") singleQuotes++;
    if (char == '"') doubleQuotes++;
  }

  // If we have an odd number of quotes, we're inside a string
  return (singleQuotes % 2 == 1) || (doubleQuotes % 2 == 1);
}

class _ExcludeRange {
  final int start;
  final int end;

  _ExcludeRange(this.start, this.end);

  @override
  String toString() => 'ExcludeRange($start, $end)';
}

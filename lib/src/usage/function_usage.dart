import 'package:dead_code_analyzer/src/models/code_info.dart';

class FunctionUsage {
  static void analyzeFunctionUsages(
      String content, String filePath, Map<String, CodeInfo> functions) {
    for (final entry in functions.entries) {
      final functionName = entry.key;
      final functionInfo = entry.value;

      if (functionInfo.isPrebuiltFlutterCommentedOut) continue;

      // Enhanced regex patterns to catch all function call types
      final usagePatterns = _buildUsagePatterns(functionName);
      final validMatches = <RegExpMatch>[];

      for (final pattern in usagePatterns) {
        final matches = pattern.allMatches(content).toList();

        for (final match in matches) {
          if (_isValidFunctionUsage(content, match, functionName)) {
            validMatches.add(match);
          }
        }
      }

      // Remove duplicates (same position matches from different patterns)
      final uniqueMatches = _removeDuplicateMatches(validMatches);
      final usageCount = uniqueMatches.length;

      if (filePath == functionInfo.definedInFile) {
        functionInfo.internalUsageCount = usageCount;
      } else if (usageCount > 0) {
        functionInfo.externalUsages[filePath] = usageCount;
      }
    }
  }

  static List<RegExp> _buildUsagePatterns(String functionName) {
    final escapedName = RegExp.escape(functionName);

    return [
      // 1. Direct function calls: functionName()
      RegExp(r'(?:^|\s|\(|\[|\{|,|;|=|\+|\-|\*|\/|!|&|\||\?|:|>|<)\s*' +
          escapedName +
          r'\s*\('),

      // 2. Method calls: object.functionName()
      RegExp(r'\.s*' + escapedName + r'\s*\('),

      // 3. Static method calls: ClassName.functionName()
      RegExp(r'\w+\.\s*' + escapedName + r'\s*\('),

      // 4. Constructor calls: new ClassName() or ClassName()
      RegExp(r'(?:new\s+)?\b' + escapedName + r'\s*\('),

      // 5. Named constructor calls: ClassName.constructorName()
      RegExp(r'\w+\.\s*' + escapedName + r'\s*\('),

      // 6. Function as parameter: callback(functionName)
      RegExp(r'[\(\[,\s]\s*' + escapedName + r'(?=\s*[\),\]]|\s*$)'),

      // 7. Function assignment: var x = functionName
      RegExp(r'=\s*' + escapedName + r'(?=\s*[;,\n\)\]}]|\s*$)'),

      // 8. Arrow function calls: => functionName()
      RegExp(r'=>\s*' + escapedName + r'\s*\('),

      // 9. Await calls: await functionName()
      RegExp(r'await\s+' + escapedName + r'\s*\('),

      // 10. Extension method calls: string.functionName()
      RegExp(r'''[\w\)\]"\']\.\s*' + escapedName + r'\s*\('''),

      // 11. Cascade calls: object..functionName()
      RegExp(r'\.\.\s*' + escapedName + r'\s*\('),

      // 12. Null-aware calls: object?.functionName()
      RegExp(r'\?\.\s*' + escapedName + r'\s*\('),

      // 13. Function reference in higher-order functions
      RegExp(
          r'(?:map|where|forEach|fold|reduce|any|every|firstWhere|lastWhere|singleWhere)\s*\(\s*' +
              escapedName +
              r'\s*\)'),

      // 14. Callback assignment: onPressed: functionName
      RegExp(r':\s*' + escapedName + r'(?=\s*[,\)\n\]}]|\s*$)'),

      // 15. Function in collections: [functionName] or {functionName}
      RegExp(r'[\[\{,]\s*' + escapedName + r'(?=\s*[\],}]|\s*$)'),

      // 16. Conditional calls: condition ? functionName() : other
      RegExp(r'\?\s*' + escapedName + r'\s*\('),

      // 17. Null coalescing: functionName() ?? other
      RegExp(r'\?\?\s*' + escapedName + r'\s*\('),

      // 18. Function chaining: .then(functionName)
      RegExp(r'\.(?:then|catchError|whenComplete|timeout)\s*\(\s*' +
          escapedName +
          r'\s*\)'),

      // 19. Stream operations: stream.listen(functionName)
      RegExp(
          r'\.(?:listen|map|where|transform|expand|asyncMap|asyncExpand|handleError)\s*\(\s*' +
              escapedName +
              r'\s*\)'),

      // 20. Timer and Future calls
      RegExp(
          r'(?:Timer|Future|Stream)\.(?:run|sync|periodic|delayed)\s*\(\s*(?:[^,\)]*,\s*)?' +
              escapedName +
              r'\s*\)'),

      // 21. Isolate spawn calls
      RegExp(r'Isolate\.spawn\s*\(\s*' + escapedName + r'\s*,'),

      // 22. Test function calls (test, testWidgets, group, etc.)
      RegExp(
          r'(?:test|testWidgets|group|setUp|tearDown|expect)\s*\([^,\)]*,\s*' +
              escapedName +
              r'\s*\)'),

      // 23. Animation listener calls
      RegExp(
          r'\.(?:addListener|addStatusListener|removeListener|removeStatusListener)\s*\(\s*' +
              escapedName +
              r'\s*\)'),

      // 24. Event handler in widgets
      RegExp(
          r'(?:onPressed|onTap|onChanged|onSubmitted|onEditingComplete|onFieldSubmitted|validator|builder|itemBuilder)\s*:\s*' +
              escapedName +
              r'(?=\s*[,\)\n\]}]|\s*$)'),

      // 25. Navigator calls with function
      RegExp(
          r'Navigator\.(?:push|pushReplacement|pushNamed|pushAndRemoveUntil).*?builder\s*:\s*' +
              escapedName),

      // 26. Getter calls (property access without parentheses)
      RegExp(r'\.s*' + escapedName + r'(?!\s*[\(\.]|\w)'),

      // 27. Setter calls (assignment to property)
      RegExp(r'\.s*' + escapedName + r'\s*='),

      // 28. Operator calls (if functionName is an operator)
      RegExp(
          r'(?:operator\s+)?(?:\+|\-|\*|\/|\%|\~|==|!=|<|>|<=|>=|\[\]|\[\]=)\s*' +
              escapedName),

      // 29. Function in return statement
      RegExp(r'return\s+' + escapedName + r'(?:\s*\(|\s*$|\s*[;,\n\)\]}])'),

      // 30. Function in throw statement
      RegExp(r'throw\s+' + escapedName + r'(?:\s*\(|\s*$|\s*[;,\n\)\]}])'),
    ];
  }

  static bool _isValidFunctionUsage(
      String content, RegExpMatch match, String functionName) {
    // Skip if in comment or string
    if (isInComment(content, match.start) || isInString(content, match.start)) {
      return false;
    }

    // Skip if it's a function definition
    if (isFunctionDefinition(content, match, functionName)) {
      return false;
    }

    // Skip if it's a variable declaration
    if (_isVariableDeclaration(content, match, functionName)) {
      return false;
    }

    // Skip if it's in import/export statement
    if (_isInImportExport(content, match)) {
      return false;
    }

    // Skip if it's in class/enum/typedef declaration
    if (_isInTypeDeclaration(content, match)) {
      return false;
    }

    // Skip if it's a parameter name in function signature
    if (_isParameterName(content, match, functionName)) {
      return false;
    }

    // Skip if it's a field/property declaration
    if (_isFieldDeclaration(content, match, functionName)) {
      return false;
    }

    return true;
  }

  static bool _isVariableDeclaration(
      String content, RegExpMatch match, String functionName) {
    final beforeMatch = content.substring(0, match.start);
    final lines = beforeMatch.split('\n');
    final currentLine = lines.isNotEmpty ? lines.last : '';

    // Check for variable declaration patterns
    final varPatterns = [
      RegExp(r'(?:var|final|const|late)\s+' +
          RegExp.escape(functionName) +
          r'\s*[=;]'),
      RegExp(
          r'(?:int|double|String|bool|List|Map|Set|Function|Object|dynamic)\s+' +
              RegExp.escape(functionName) +
              r'\s*[=;]'),
      RegExp(
          r'(?:int|double|String|bool|List|Map|Set|Function|Object|dynamic)\?\s+' +
              RegExp.escape(functionName) +
              r'\s*[=;]'),
    ];

    return varPatterns.any((pattern) => pattern.hasMatch(currentLine));
  }

  static bool _isInImportExport(String content, RegExpMatch match) {
    final beforeMatch = content.substring(0, match.start);
    final lines = beforeMatch.split('\n');
    final currentLine = lines.isNotEmpty ? lines.last : '';

    return currentLine.trimLeft().startsWith('import ') ||
        currentLine.trimLeft().startsWith('export ');
  }

  static bool _isInTypeDeclaration(String content, RegExpMatch match) {
    final beforeMatch = content.substring(0, match.start);
    final lines = beforeMatch.split('\n');
    final currentLine = lines.isNotEmpty ? lines.last : '';

    final typeDeclarationPatterns = [
      RegExp(r'^\s*(?:abstract\s+)?class\s+'),
      RegExp(r'^\s*enum\s+'),
      RegExp(r'^\s*typedef\s+'),
      RegExp(r'^\s*mixin\s+'),
      RegExp(r'^\s*extension\s+'),
      RegExp(r'\s+extends\s+'),
      RegExp(r'\s+implements\s+'),
      RegExp(r'\s+with\s+'),
    ];

    return typeDeclarationPatterns
        .any((pattern) => pattern.hasMatch(currentLine));
  }

  static bool _isParameterName(
      String content, RegExpMatch match, String functionName) {
    final beforeMatch = content.substring(0, match.start);
    final afterMatch = content.substring(match.end);

    // Check if we're inside function parameters
    final lastOpenParen = beforeMatch.lastIndexOf('(');
    final lastCloseParen = beforeMatch.lastIndexOf(')');

    if (lastOpenParen > lastCloseParen) {
      // We're inside parentheses, check if it's a parameter
      final afterText = afterMatch.trim();
      return afterText.startsWith(',') ||
          afterText.startsWith(')') ||
          afterText.startsWith('=') ||
          afterText.isEmpty;
    }

    return false;
  }

  static bool _isFieldDeclaration(
      String content, RegExpMatch match, String functionName) {
    final beforeMatch = content.substring(0, match.start);
    final lines = beforeMatch.split('\n');
    final currentLine = lines.isNotEmpty ? lines.last : '';

    // Check for field declaration patterns
    final fieldPatterns = [
      RegExp(
          r'^\s*(?:static\s+)?(?:final\s+|const\s+)?(?:late\s+)?(?:\w+\s+)+' +
              RegExp.escape(functionName) +
              r'\s*[=;]'),
      RegExp(r'^\s*(?:public|private|protected)?\s*(?:static\s+)?(?:\w+\s+)+' +
          RegExp.escape(functionName) +
          r'\s*[=;]'),
    ];

    return fieldPatterns.any((pattern) => pattern.hasMatch(currentLine));
  }

  static List<RegExpMatch> _removeDuplicateMatches(List<RegExpMatch> matches) {
    final uniqueMatches = <RegExpMatch>[];
    final positions = <int>{};

    for (final match in matches) {
      if (!positions.contains(match.start)) {
        positions.add(match.start);
        uniqueMatches.add(match);
      }
    }

    return uniqueMatches;
  }

// Enhanced function definition detection
  static bool isFunctionDefinition(
      String content, RegExpMatch match, String functionName) {
    final matchStart = match.start;
    final beforeMatch = content.substring(0, matchStart);
    final lines = beforeMatch.split('\n');
    final currentLine = lines.isNotEmpty ? lines.last : '';
    final previousLine = lines.length > 1 ? lines[lines.length - 2] : '';
    final contextLine = '$previousLine $currentLine'.trim();

    // Enhanced function definition patterns
    final definitionPatterns = [
      // Regular function definitions
      RegExp(r'^\s*(?:static\s+)?(?:async\s+)?(?:\w+\s+)?' +
          RegExp.escape(functionName) +
          r'\s*\('),

      // Constructor definitions
      RegExp(r'^\s*(?:const\s+)?(?:factory\s+)?' +
          RegExp.escape(functionName) +
          r'\s*\('),

      // Named constructor definitions
      RegExp(r'^\s*(?:const\s+)?(?:factory\s+)?\w+\.' +
          RegExp.escape(functionName) +
          r'\s*\('),

      // Getter/Setter definitions
      RegExp(r'^\s*(?:static\s+)?(?:get|set)\s+' + RegExp.escape(functionName)),

      // Operator definitions
      RegExp(
          r'^\s*(?:static\s+)?\w+\s+operator\s+' + RegExp.escape(functionName)),

      // Function type definitions
      RegExp(r'^\s*typedef\s+\w*\s*' + RegExp.escape(functionName)),

      // Method definitions in classes
      RegExp(r'^\s*@override\s*(?:\w+\s+)?' +
          RegExp.escape(functionName) +
          r'\s*\('),

      // Extension method definitions
      RegExp(r'^\s*(?:static\s+)?(?:\w+\s+)?' +
          RegExp.escape(functionName) +
          r'\s*\(.*\)\s*(?:\{|=>)'),
    ];

    // Check against all patterns
    for (final pattern in definitionPatterns) {
      if (pattern.hasMatch(currentLine) || pattern.hasMatch(contextLine)) {
        return true;
      }
    }

    // Check for function body indicators
    final afterMatch = content.substring(match.end);
    final functionBodyPattern =
        RegExp(r'^\s*\([^)]*\)\s*(?:\{|=>|async\s*\{|async\s*=>)');

    if (functionBodyPattern.hasMatch(afterMatch)) {
      // Additional context check to avoid false positives
      final trimmedLine = currentLine.trim();
      if (trimmedLine.startsWith('return ') ||
          trimmedLine.contains(' = ') ||
          trimmedLine.contains(': ')) {
        return false; // It's likely a function call, not definition
      }
      return true;
    }

    return false;
  }

// Keep existing helper functions for comment and string detection
  static bool isInComment(String content, int position) {
    final beforePosition = content.substring(0, position);
    final lines = beforePosition.split('\n');
    final currentLine = lines.last;

    // Check for single line comment
    final singleLineCommentIndex = currentLine.indexOf('//');
    if (singleLineCommentIndex != -1) {
      final positionInLine =
          position - (beforePosition.length - currentLine.length);
      if (positionInLine > singleLineCommentIndex) {
        return true;
      }
    }

    // Check for multi-line comment
    final multiLineCommentStart = beforePosition.lastIndexOf('/*');
    final multiLineCommentEnd = beforePosition.lastIndexOf('*/');

    if (multiLineCommentStart != -1 &&
        (multiLineCommentEnd == -1 ||
            multiLineCommentStart > multiLineCommentEnd)) {
      return true;
    }

    return false;
  }

  static bool isInString(String content, int position) {
    final beforePosition = content.substring(0, position);

    // Count unescaped quotes
    int singleQuoteCount = 0;
    int doubleQuoteCount = 0;
    bool inRawString = false;
    bool inTripleQuote = false;

    for (int i = 0; i < beforePosition.length; i++) {
      final char = beforePosition[i];
      final prevChar = i > 0 ? beforePosition[i - 1] : '';
      final nextChar =
          i + 1 < beforePosition.length ? beforePosition[i + 1] : '';
      final nextNextChar =
          i + 2 < beforePosition.length ? beforePosition[i + 2] : '';
      final isEscaped = prevChar == '\\';

      // Check for triple quotes
      if (!isEscaped && char == '"' && nextChar == '"' && nextNextChar == '"') {
        inTripleQuote = !inTripleQuote;
        i += 2; // Skip next two quotes
        continue;
      }

      if (!isEscaped && char == "'" && nextChar == "'" && nextNextChar == "'") {
        inTripleQuote = !inTripleQuote;
        i += 2; // Skip next two quotes
        continue;
      }

      if (inTripleQuote) continue;

      // Check for raw strings
      if (char == 'r' &&
          i + 1 < beforePosition.length &&
          (beforePosition[i + 1] == '"' || beforePosition[i + 1] == "'")) {
        inRawString = true;
        continue;
      }

      if (!isEscaped && !inRawString) {
        if (char == "'") singleQuoteCount++;
        if (char == '"') doubleQuoteCount++;
      }

      if (inRawString && (char == '"' || char == "'")) {
        inRawString = false;
      }
    }

    return (singleQuoteCount % 2 == 1) ||
        (doubleQuoteCount % 2 == 1) ||
        inTripleQuote;
  }
}

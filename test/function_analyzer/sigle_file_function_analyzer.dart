import 'package:dead_code_analyzer/src/collectors/function_collector.dart';
import 'package:dead_code_analyzer/src/models/code_info.dart';

import 'text_function_sigle_file.dart';

void functionAnalyzerTest() {
  final lines = functionTestFile.split('\n');
  final pragmaRegex =
      RegExp(r'''@\s*pragma\s*\(\s*[\'"]vm:entry-point[\'"]\s*\)''');
  Map<String, CodeInfo> functions = {};
  bool insideStateClass = false;
  Set<String> prebuiltFlutterMethods = {'build'}; // Example Flutter method

  for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    String line = lines[lineIndex];

    FunctionCollector.collectFunctions(
      analyzeFunctions: true,
      line: line,
      insideStateClass: insideStateClass,
      prebuiltFlutterMethods: prebuiltFlutterMethods,
      lineIndex: lineIndex,
      pragmaRegex: pragmaRegex,
      lines: lines,
      functions: functions,
      filePath: 'text_function_file.dart',
      currentClassName:
          line.contains('class ') ? line.split('class ')[1].split(' ')[0] : '',
    );

    // Update insideStateClass
    var classMatch = RegExp(
      r'^(?:sealed\s+|abstract\s+|mixin\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:extends\s+[A-Za-z_][A-Za-z0-9_]*\s*)?(?:implements\s+[A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\s*)?(?:with\s+[A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\s*)?{',
      multiLine: true,
    ).firstMatch(line.replaceFirst(RegExp(r'^\s*//+\s*'), ''));

    if (classMatch != null &&
        line
            .replaceFirst(RegExp(r'^\s*//+\s*'), '')
            .contains('extends State<')) {
      insideStateClass = true;
    } else if (insideStateClass && line.trim().contains('}')) {
      insideStateClass = false;
    }
  }

  print('Commented Functions');
  print('------------------------------');
  functions.forEach((name, info) {
    if (info.commentedOut) {
      print(
          ' - $name (in ${info.definedInFile}, type: ${info.type}, entryPoint: ${info.isEntryPoint}, prebuiltFlutter: ${info.isPrebuiltFlutter}, empty: ${info.isEmpty}, constructor: ${info.isConstructor})');
    }
  });

  print('\nNon-Commented Functions');
  print('------------------------------');
  functions.forEach((name, info) {
    if (!info.commentedOut) {
      print(
          ' - $name (in ${info.definedInFile}, type: ${info.type}, entryPoint: ${info.isEntryPoint}, prebuiltFlutter: ${info.isPrebuiltFlutter}, empty: ${info.isEmpty}, constructor: ${info.isConstructor})');
    }
  });

  print('\nState Class Functions');
  print('------------------------------');
  functions.forEach((name, info) {
    if (insideStateClass || info.isPrebuiltFlutter) {
      print(
          ' - $name (in ${info.definedInFile}, type: ${info.type}, entryPoint: ${info.isEntryPoint}, prebuiltFlutter: ${info.isPrebuiltFlutter}, empty: ${info.isEmpty}, constructor: ${info.isConstructor})');
    }
  });

  // Assertions to verify correctness
  assert(
      functions.length == 5, 'Expected 5 functions, got ${functions.length}');

  // Commented functions
  assert(functions.containsKey('commentedFunction_commented_2_8'),
      'Expected commentedFunction to be detected');
  assert(functions['commentedFunction_commented_2_8']!.commentedOut,
      'Expected commentedFunction to be marked as commented');
  assert(functions.containsKey('commentedFunction1_commented_3_0'),
      'Expected commentedFunction1 to be detected');
  assert(functions['commentedFunction1_commented_3_0']!.commentedOut,
      'Expected commentedFunction1 to be marked as commented');
  assert(functions.containsKey('commentedFunction2_commented_4_0'),
      'Expected commentedFunction2 to be detected');
  assert(functions['commentedFunction2_commented_4_0']!.commentedOut,
      'Expected commentedFunction2 to be marked as commented');

  // Non-commented functions
  assert(functions.containsKey('activeFunction'),
      'Expected activeFunction to be detected');
  assert(!functions['activeFunction']!.commentedOut,
      'Expected activeFunction to be marked as not commented');
  assert(functions.containsKey('entryPointFunction'),
      'Expected entryPointFunction to be detected');
  assert(!functions['entryPointFunction']!.commentedOut,
      'Expected entryPointFunction to be marked as not commented');
  assert(functions['entryPointFunction']!.isEntryPoint,
      'Expected entryPointFunction to be marked as entry point');
  assert(functions.containsKey('emptyFunction'),
      'Expected emptyFunction to be detected');
  assert(!functions['emptyFunction']!.commentedOut,
      'Expected emptyFunction to be marked as not commented');
  assert(functions['emptyFunction']!.isEmpty,
      'Expected emptyFunction to be marked as empty');
  assert(functions.containsKey('TestClass_commented_7_4'),
      'Expected TestClass._privateConstructor to be detected');
  assert(functions['TestClass_commented_7_4']!.isConstructor,
      'Expected TestClass._privateConstructor to be marked as constructor');
}

import 'package:dead_code_analyzer/src/collecter/function_collector.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';

import 'text_function_multi_file.dart';

void multifilefunctionAnalyzerTest() {
  final files = {
    'lib/src/file1.dart': functionTestFile1,
    'lib/src/file2.dart': functionTestFile2,
  };
  final pragmaRegex =
      RegExp(r'''@\s*pragma\s*\(\s*[\'"]vm:entry-point[\'"]\s*\)''');
  Map<String, CodeInfo> functions = {};
  bool insideStateClass = false;
  Set<String> prebuiltFlutterMethods = {'build'};

  // Process both files
  for (var filePath in files.keys) {
    final lines = files[filePath]!.split('\n');
    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      String line = lines[lineIndex];

      FunctionCollector.functionCollecter(
        analyzeFunctions: true,
        line: line,
        insideStateClass: insideStateClass,
        prebuiltFlutterMethods: prebuiltFlutterMethods,
        lineIndex: lineIndex,
        pragmaRegex: pragmaRegex,
        lines: lines,
        functions: functions,
        filePath: filePath,
        currentClassName: line.contains('class ')
            ? line.split('class ')[1].split(' ')[0]
            : '',
      );

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
  }

  print('Commented Functions');
  print('------------------------------');
  functions.forEach((name, info) {
    if (info.commentedOut) {
      print(
          ' - $name (in ${info.definedInFile}, line: ${info.lineIndex}, pos: ${info.startPosition}, type: ${info.type}, entryPoint: ${info.isEntryPoint}, prebuiltFlutter: ${info.isPrebuiltFlutter}, empty: ${info.isEmpty}, constructor: ${info.isConstructor})');
    }
  });

  print('\nNon-Commented Functions');
  print('------------------------------');
  functions.forEach((name, info) {
    if (!info.commentedOut) {
      print(
          ' - $name (in ${info.definedInFile}, line: ${info.lineIndex}, pos: ${info.startPosition}, type: ${info.type}, entryPoint: ${info.isEntryPoint}, prebuiltFlutter: ${info.isPrebuiltFlutter}, empty: ${info.isEmpty}, constructor: ${info.isConstructor})');
    }
  });

  print('\nState Class Functions');
  print('------------------------------');
  functions.forEach((name, info) {
    if (insideStateClass || info.isPrebuiltFlutter) {
      print(
          ' - $name (in ${info.definedInFile}, line: ${info.lineIndex}, pos: ${info.startPosition}, type: ${info.type}, entryPoint: ${info.isEntryPoint}, prebuiltFlutter: ${info.isPrebuiltFlutter}, empty: ${info.isEmpty}, constructor: ${info.isConstructor})');
    }
  });

  // Assertions
  assert(
      functions.length == 10, 'Expected 10 functions, got ${functions.length}');

  // Commented functions from file1.dart
  assert(
      functions
          .containsKey('commentedFunction_commented_lib_src_file1_dart_2_8'),
      'Expected commentedFunction from file1.dart to be detected');
  assert(
      functions['commentedFunction_commented_lib_src_file1_dart_2_8']!
          .commentedOut,
      'Expected commentedFunction from file1.dart to be marked as commented');
  assert(
      functions['commentedFunction_commented_lib_src_file1_dart_2_8']!
              .definedInFile ==
          'lib/src/file1.dart',
      'Expected commentedFunction from file1.dart to have correct file path');
  assert(
      functions['commentedFunction_commented_lib_src_file1_dart_2_8']!
              .lineIndex ==
          2,
      'Expected commentedFunction from file1.dart at line 2');
  assert(
      functions
          .containsKey('commentedFunction1_commented_lib_src_file1_dart_3_0'),
      'Expected commentedFunction1 from file1.dart to be detected');
  assert(
      functions['commentedFunction1_commented_lib_src_file1_dart_3_0']!
          .commentedOut,
      'Expected commentedFunction1 from file1.dart to be marked as commented');
  assert(
      functions
          .containsKey('commentedFunction2_commented_lib_src_file1_dart_4_0'),
      'Expected commentedFunction2 from file1.dart to be detected');
  assert(
      functions['commentedFunction2_commented_lib_src_file1_dart_4_0']!
          .commentedOut,
      'Expected commentedFunction2 from file1.dart to be marked as commented');

  // Commented functions from file2.dart
  assert(
      functions
          .containsKey('commentedFunction_commented_lib_src_file2_dart_2_8'),
      'Expected commentedFunction from file2.dart to be detected');
  assert(
      functions['commentedFunction_commented_lib_src_file2_dart_2_8']!
          .commentedOut,
      'Expected commentedFunction from file2.dart to be marked as commented');
  assert(
      functions['commentedFunction_commented_lib_src_file2_dart_2_8']!
              .definedInFile ==
          'lib/src/file2.dart',
      'Expected commentedFunction from file2.dart to have correct file path');
  assert(
      functions['commentedFunction_commented_lib_src_file2_dart_2_8']!
              .lineIndex ==
          2,
      'Expected commentedFunction from file2.dart at line 2');
  assert(
      functions
          .containsKey('commentedFunction1_commented_lib_src_file2_dart_3_0'),
      'Expected commentedFunction1 from file2.dart to be detected');
  assert(
      functions['commentedFunction1_commented_lib_src_file2_dart_3_0']!
          .commentedOut,
      'Expected commentedFunction1 from file2.dart to be marked as commented');
  assert(
      functions
          .containsKey('commentedFunction2_commented_lib_src_file2_dart_4_0'),
      'Expected commentedFunction2 from file2.dart to be detected');
  assert(
      functions['commentedFunction2_commented_lib_src_file2_dart_4_0']!
          .commentedOut,
      'Expected commentedFunction2 from file2.dart to be marked as commented');

  // Non-commented functions (assuming collision handling)
  assert(functions.containsKey('activeFunction'),
      'Expected activeFunction from file1.dart to be detected');
  assert(!functions['activeFunction']!.commentedOut,
      'Expected activeFunction to be marked as not commented');
  assert(functions['activeFunction']!.definedInFile == 'lib/src/file1.dart',
      'Expected activeFunction from file1.dart to have correct file path');
  assert(functions.containsKey('activeFunction_lib_src_file2_dart'),
      'Expected activeFunction from file2.dart to be detected');
  assert(!functions['activeFunction_lib_src_file2_dart']!.commentedOut,
      'Expected activeFunction from file2.dart to be marked as not commented');
  assert(functions.containsKey('entryPointFunction'),
      'Expected entryPointFunction from file1.dart to be detected');
  assert(functions['entryPointFunction']!.isEntryPoint,
      'Expected entryPointFunction from file1.dart to be marked as entry point');
  assert(functions.containsKey('entryPointFunction_lib_src_file2_dart'),
      'Expected entryPointFunction from file2.dart to be detected');
}

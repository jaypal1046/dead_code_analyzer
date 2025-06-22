import 'package:dead_code_analyzer/src/collectors/class_collector.dart';
import 'package:dead_code_analyzer/src/models/class_info.dart';
import 'text_class_file.dart';

void classAnalyzerTest() {
  final lines = ckassTestFile.split('\n');
  final pragmaRegex =
      RegExp(r'''@\s*pragma\s*\(\s*[\'"]vm:entry-point[\'"]\s*\)''');
  Map<String, ClassInfo> classes = {};
  bool insideStateClass = false;

  for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    String line = lines[lineIndex];
    var classMatch = RegExp(
      r'^(?:sealed\s+|abstract\s+|mixin\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:extends\s+[A-Za-z_][A-Za-z0-9_]*\s*)?(?:implements\s+[A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\s*)?(?:with\s+[A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\s*)?{',
      multiLine: true,
    ).firstMatch(line.replaceFirst(RegExp(r'^\s*//+\s*'), ''));

    ClassCollector.classCollector(
      classMatch,
      lineIndex,
      pragmaRegex,
      lines,
      classes,
      'text_class_file.dart',
      insideStateClass,
    );

    // Update insideStateClass
    if (classMatch != null &&
        line
            .replaceFirst(RegExp(r'^\s*//+\s*'), '')
            .contains('extends State<')) {
      insideStateClass = true;
    } else if (insideStateClass && line.trim().contains('}')) {
      insideStateClass = false;
    }
  }

  print('Commented Classes');
  print('------------------------------');
  classes.forEach((name, info) {
    if (info.commentedOut) {
      print(
          ' - $name (in ${info.definedInFile}, internal references: 0, external references: 0, total: 0) []');
    }
  });

  print('\nNon-Commented Classes');
  print('------------------------------');
  classes.forEach((name, info) {
    if (!info.commentedOut) {
      print(
          ' - $name (in ${info.definedInFile}, type: ${info.type}, entryPoint: ${info.isEntryPoint})');
    }
  });

  print('\nNon-Commented State Classes');
  print('------------------------------');
  classes.forEach((name, info) {
    if (info.type == 'state_class') {
      print(
          ' - $name (in ${info.definedInFile}, type: ${info.type}, entryPoint: ${info.isEntryPoint})');
    }
  });
}

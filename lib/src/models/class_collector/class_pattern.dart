import 'package:dead_code_analyzer/dead_code_analyzer.dart' show PatternType;

/// Pattern definition for class matching
class ClassPattern {
  ClassPattern({
    required String regex,
    required this.type,
  }) : regex = RegExp(regex, multiLine: false);

  final RegExp regex;
  final PatternType type;
}

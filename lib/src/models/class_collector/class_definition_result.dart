import 'package:dead_code_analyzer/dead_code_analyzer.dart' show ClassInfo;

/// Result of complete class definition analysis
class ClassDefinitionResult {
  const ClassDefinitionResult({
    required this.name,
    required this.info,
  });

  final String name;
  final ClassInfo info;
}

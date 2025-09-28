import 'package:dead_code_analyzer/dead_code_analyzer.dart';

/// Result of the code analysis
class AnalysisResult {
  const AnalysisResult({required this.classes, required this.functions});

  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;
}

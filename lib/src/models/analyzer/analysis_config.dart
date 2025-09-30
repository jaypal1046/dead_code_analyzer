import '../../reporters/file_reporter.dart' show OutType;

class AnalysisConfig {
  final String projectPath;
  final String outputDir;
  final int maxUnusedEntities;
  final bool includeFunctions;
  final bool shouldClean;
  final bool showTrace;
  final bool showProgress;
  final OutType outType; // Add this field

  AnalysisConfig({
    required this.projectPath,
    required this.outputDir,
    required this.maxUnusedEntities,
    required this.includeFunctions,
    required this.shouldClean,
    required this.showTrace,
    required this.showProgress,
    required this.outType, // Add this parameter
  });
}

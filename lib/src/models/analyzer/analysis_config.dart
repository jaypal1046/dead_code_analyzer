/// Configuration for the analysis process
class AnalysisConfig {
  const AnalysisConfig({
    required this.projectPath,
    required this.outputDir,
    required this.maxUnusedEntities,
    required this.includeFunctions,
    required this.shouldClean,
    required this.showTrace,
    required this.showProgress,
  });

  final String projectPath;
  final String outputDir;
  final int maxUnusedEntities;
  final bool includeFunctions;
  final bool shouldClean;
  final bool showTrace;
  final bool showProgress;
}

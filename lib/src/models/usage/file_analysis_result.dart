/// Result of file analysis for cleanup
class FileAnalysisResult {
  const FileAnalysisResult({
    required this.filesToDelete,
    required this.filesWithIssues,
  });

  final List<String> filesToDelete;
  final Map<String, String> filesWithIssues;
}

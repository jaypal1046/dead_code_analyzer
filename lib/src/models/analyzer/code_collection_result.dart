import '../class_info.dart';
import '../code_info.dart';
import '../usage/import_info.dart';

/// Result class to hold collection results
class CodeCollectionResult {
  final String filePath;
  final bool success;
  final String? error;
  final Map<String, ClassInfo>? collectedClasses;
  final Map<String, CodeInfo>? collectedFunctions;
  final List<ImportInfo>? collectedExports;

  CodeCollectionResult({
    required this.filePath,
    required this.success,
    this.error,
    this.collectedClasses,
    this.collectedFunctions,
    this.collectedExports,
  });
}

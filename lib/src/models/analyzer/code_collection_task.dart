import '../class_info.dart';
import '../code_info.dart';
import '../usage/import_info.dart';

/// Data class to hold file processing parameters for collection
class CodeCollectionTask {
  final String filePath;
  final bool analyzeFunctions;
  final Map<String, ClassInfo> classes;
  final Map<String, CodeInfo> functions;
  final List<ImportInfo> exportList;

  CodeCollectionTask({
    required this.filePath,
    required this.analyzeFunctions,
    required this.classes,
    required this.functions,
    required this.exportList,
  });
}

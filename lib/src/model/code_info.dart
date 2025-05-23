class CodeInfo {
  final String definedInFile; // Absolute path
  int internalUsageCount = 0;
  final Map<String, int> externalUsages = {}; // Keys are absolute paths
  final bool isEntryPoint;
  final String type; // 'class', 'state_class', 'function'
  final bool isPrebuiltFlutter; // True for Flutter State class methods
  final bool isEmpty; // True for empty body ({} or ;)
  final bool isConstructor; // True for constructor
  final bool commentedOut; // New field to track commented out
  CodeInfo(
    this.definedInFile, {
    this.isEntryPoint = false,
    required this.type,
    this.isPrebuiltFlutter = false,
    this.isEmpty = false,
    this.isConstructor = false,
    this.commentedOut = false,
  });

  int get totalExternalUsages =>
      externalUsages.values.fold(0, (sum, count) => sum + count);

  int get totalUsages => internalUsageCount + totalExternalUsages;

  List<String> get externalUsageFiles => externalUsages.keys.toList();
}

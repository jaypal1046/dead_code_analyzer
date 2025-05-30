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
  final int lineIndex; // New field
  final int startPosition; // New field
  final bool isAbstract;
  final bool
      isPrebuiltFlutterCommentedOut; // New field to track commented out prebuilt Flutter methods
  final String className; // New field to track class name
  final bool isStaticFunction; // New field to track static functions
  CodeInfo(
    this.definedInFile, {
    this.isEntryPoint = false,
    required this.type,
    this.isPrebuiltFlutter = false,
    this.isEmpty = false,
    this.isConstructor = false,
    this.commentedOut = false,
    required this.lineIndex,
    required this.startPosition,
    this.isAbstract = false,
    this.isPrebuiltFlutterCommentedOut = false,
    this.className = '',
    this.isStaticFunction = false,
  });

  int get totalExternalUsages =>
      externalUsages.values.fold(0, (sum, count) => sum + count);

  int get totalUsages => internalUsageCount + totalExternalUsages;

  List<String> get externalUsageFiles => externalUsages.keys.toList();
}

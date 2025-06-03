class ClassInfo {
  final String definedInFile;
  final String type; // 'class', 'state_class', 'function'
  int internalUsageCount =
      0; // Usage count within own file (excluding definition)
  final Map<String, int> externalUsages = {}; // Map of file path to usage count
  final bool isEntryPoint; // New field to track @pragma('vm:entry-point')
  final bool commentedOut; // New field to track commented out
  ClassInfo(
    this.definedInFile, {
    this.isEntryPoint = false,
    required this.type,
    this.commentedOut = false,
  });

  int get totalExternalUsages =>
      externalUsages.values.fold(0, (sum, count) => sum + count);

  int get totalUsages => internalUsageCount + totalExternalUsages;

  List<String> get externalUsageFiles => externalUsages.keys.toList();
}

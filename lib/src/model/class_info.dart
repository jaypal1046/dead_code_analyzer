class ClassInfo {
  final String definedInFile;
  int internalUsageCount = 0; // Usage count within own file (excluding definition)
  final Map<String, int> externalUsages = {}; // Map of file path to usage count

  ClassInfo(this.definedInFile);
  
  int get totalExternalUsages => 
      externalUsages.values.fold(0, (sum, count) => sum + count);
  
  int get totalUsages => internalUsageCount + totalExternalUsages;
  
  List<String> get externalUsageFiles => externalUsages.keys.toList();
}
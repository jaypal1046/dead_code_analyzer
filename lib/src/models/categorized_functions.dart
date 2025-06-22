// Data class to hold categorized functions
class CategorizedFunctions {
  final List<String> unused;
  final List<String> internalOnly;
  final List<String> externalOnly;
  final List<String> bothInternalExternal;
  final List<String> emptyPrebuilt;
  final List<String> entryPoint;
  final List<String> commented;

  CategorizedFunctions({
    required this.unused,
    required this.internalOnly,
    required this.externalOnly,
    required this.bothInternalExternal,
    required this.emptyPrebuilt,
    required this.entryPoint,
    required this.commented,
  });
}

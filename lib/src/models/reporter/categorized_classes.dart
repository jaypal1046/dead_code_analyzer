// Data class to hold categorized classes
class CategorizedClasses {
  final List<String> unused;
  final List<String> internalOnly;
  final List<String> externalOnly;
  final List<String> bothInternalExternal;
  final List<String> state;
  final List<String> entryPoint;
  final List<String> commented;

  CategorizedClasses({
    required this.unused,
    required this.internalOnly,
    required this.externalOnly,
    required this.bothInternalExternal,
    required this.state,
    required this.entryPoint,
    required this.commented,
  });
}

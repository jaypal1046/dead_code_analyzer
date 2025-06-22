class ImportInfo {
  final String path;
  final String? asAlias;
  final List<String> hiddenClasses;
  final List<String> shownClasses; // for 'show' keyword
  final String? sourceFile;
  ImportInfo({
    required this.path,
    this.asAlias,
    this.hiddenClasses = const [],
    this.shownClasses = const [],
    this.sourceFile,
  });
}

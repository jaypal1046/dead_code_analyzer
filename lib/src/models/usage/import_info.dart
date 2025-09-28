class ImportInfo {
  final String path;
  final String? asAlias;
  final List<String> hiddenClasses;
  final List<String> shownClasses; // for 'show' keyword
  final List<String> hiddenFunctions;
  final List<String> shownFunctions; // for 'show' keyword with functions
  final String? sourceFile;
  final bool isExport; // New field to distinguish exports from imports
  final bool isWildcardExport; // New field for export * statements

  ImportInfo({
    required this.path,
    this.asAlias,
    this.hiddenClasses = const [],
    this.shownClasses = const [],
    this.hiddenFunctions = const [],
    this.shownFunctions = const [],
    this.sourceFile,
    this.isExport = false, // Default to false for backward compatibility
    this.isWildcardExport = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'asAlias': asAlias,
      'hiddenClasses': hiddenClasses,
      'shownClasses': shownClasses,
      'hiddenFunctions': hiddenFunctions,
      'shownFunctions': shownFunctions,
      'sourceFile': sourceFile,
      'isExport': isExport,
      'isWildcardExport': isWildcardExport,
    };
  }

  factory ImportInfo.fromJson(Map<String, dynamic> json) {
    return ImportInfo(
      path: json['path'] as String,
      asAlias: json['asAlias'] as String?,
      hiddenClasses: List<String>.from(json['hiddenClasses'] ?? []),
      shownClasses: List<String>.from(json['shownClasses'] ?? []),
      hiddenFunctions: List<String>.from(json['hiddenFunctions'] ?? []),
      shownFunctions: List<String>.from(json['shownFunctions'] ?? []),
      sourceFile: json['sourceFile'] as String?,
      isExport: json['isExport'] as bool? ?? false,
      isWildcardExport: json['isWildcardExport'] as bool? ?? false,
    );
  }

  // Helper method to check if this is a selective export
  bool get isSelectiveExport =>
      isExport && (shownClasses.isNotEmpty || shownFunctions.isNotEmpty);

  // Helper method to check if this is a hiding export
  bool get isHidingExport =>
      isExport && (hiddenClasses.isNotEmpty || hiddenFunctions.isNotEmpty);

  // Helper method to check if this is a simple export (no show/hide/wildcard)
  bool get isSimpleExport =>
      isExport &&
      !isWildcardExport &&
      shownClasses.isEmpty &&
      hiddenClasses.isEmpty &&
      shownFunctions.isEmpty &&
      hiddenFunctions.isEmpty;

  // Helper methods to get all shown/hidden items
  List<String> get allShownItems => [...shownClasses, ...shownFunctions];
  List<String> get allHiddenItems => [...hiddenClasses, ...hiddenFunctions];

  @override
  String toString() {
    return 'ImportInfo(path: $path, isExport: $isExport, isWildcardExport: $isWildcardExport, '
        'shownClasses: $shownClasses, hiddenClasses: $hiddenClasses, '
        'shownFunctions: $shownFunctions, hiddenFunctions: $hiddenFunctions, '
        'asAlias: $asAlias, sourceFile: $sourceFile)';
  }
}

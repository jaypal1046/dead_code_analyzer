class ClassInfo {
  final String definedInFile;
  final String type; // 'class', 'state_class', 'function'
  int internalUsageCount =
      0; // Usage count within own file (excluding definition)
  final Map<String, int> externalUsages = {}; // Map of file path to usage count
  final bool isEntryPoint; // New field to track @pragma('vm:entry-point')
  final bool commentedOut; // New field to track commented out
  final int lineIndex; // New field
  final int startPosition; // New field
  ClassInfo(
    this.definedInFile, {
    this.isEntryPoint = false,
    required this.type,
    this.commentedOut = false,
    required this.lineIndex,
    required this.startPosition,
  });

  Map<String, dynamic> toJson() {
    return {
      'definedInFile': definedInFile,
      'type': type,
      'internalUsageCount': internalUsageCount,
      'externalUsages': externalUsages,
      'isEntryPoint': isEntryPoint,
      'commentedOut': commentedOut,
      'lineIndex': lineIndex,
      'startPosition': startPosition,
    };
  }

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    return ClassInfo(
        json['definedInFile'] as String,
        type: json['type'] as String,
        isEntryPoint: json['isEntryPoint'] as bool? ?? false,
        commentedOut: json['commentedOut'] as bool? ?? false,
        lineIndex: json['lineIndex'] as int,
        startPosition: json['startPosition'] as int,
      )
      ..internalUsageCount = json['internalUsageCount'] as int? ?? 0
      ..externalUsages.addAll(
        (json['externalUsages'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v as int),
        ),
      );
  }

  int get totalExternalUsages =>
      externalUsages.values.fold(0, (sum, count) => sum + count);

  int get totalUsages => internalUsageCount + totalExternalUsages;

  List<String> get externalUsageFiles => externalUsages.keys.toList();
}

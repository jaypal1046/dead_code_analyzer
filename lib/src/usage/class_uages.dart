import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/usage/uages_helper.dart';

void analyzeClassUsages(
    String content, String filePath, Map<String, ClassInfo> classes) {
  for (final entry in classes.entries) {
    final className = entry.key;
    final classInfo = entry.value;

    // Find all occurrences of the class name
    final usageRegex = RegExp(r'\b' + RegExp.escape(className) + r'\b');
    final allMatches = usageRegex.allMatches(content).toList();

    if (allMatches.isEmpty) continue;

    // Filter out definition-related matches
    final validMatches = <RegExpMatch>[];

    for (final match in allMatches) {
      if (shouldExcludeClassMatch(content, match, className)) {
        continue;
      }

      if (isInComment(content, match.start) ||
          isInString(content, match.start)) {
        continue;
      }

      validMatches.add(match);
    }

    final usageCount = validMatches.length;

    if (filePath == classInfo.definedInFile) {
      classInfo.internalUsageCount = usageCount;
    } else if (usageCount > 0) {
      classInfo.externalUsages[filePath] = usageCount;
    }
  }
}

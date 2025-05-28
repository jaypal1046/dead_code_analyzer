import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/usage/uages_helper.dart';

void analyzeFunctionUsages(
    String content, String filePath, Map<String, CodeInfo> functions) {
  for (final entry in functions.entries) {
    final functionName = entry.key;
    final functionInfo = entry.value;

    // Find all occurrences of the function name
    final usageRegex = RegExp(r'\b' + RegExp.escape(functionName) + r'\b');
    final allMatches = usageRegex.allMatches(content).toList();

    if (allMatches.isEmpty) continue;

    // Filter out definition-related matches
    final validMatches = <RegExpMatch>[];

    for (final match in allMatches) {
      if (shouldExcludeFunctionMatch(content, match, functionName)) {
        continue;
      }

      if (isInComment(content, match.start) ||
          isInString(content, match.start)) {
        continue;
      }

      validMatches.add(match);
    }

    final usageCount = validMatches.length;

    if (filePath == functionInfo.definedInFile) {
      functionInfo.internalUsageCount = usageCount;
    } else if (usageCount > 0) {
      functionInfo.externalUsages[filePath] = usageCount;
    }
  }
}

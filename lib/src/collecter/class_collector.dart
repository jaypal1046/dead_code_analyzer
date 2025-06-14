import 'package:dead_code_analyzer/src/model/class_info.dart';

void classCollector(
  RegExpMatch? classMatch,
  int lineIndex,
  RegExp pragmaRegex,
  List<String> lines,
  Map<String, ClassInfo> classes,
  String filePath,
  bool insideStateClass,
) {
  String line = lines[lineIndex];
  String trimmedLine = line.trim();
  
  // Skip empty lines
  if (trimmedLine.isEmpty) return;
  
  // More robust patterns with better spacing and generic handling
  List<RegExp> classPatterns = [
    // 0. Regular class declarations (including all modifiers and commented ones)
    RegExp(r'^\s*(?:\/\/+\s*)?(?:sealed\s+|abstract\s+|base\s+|final\s+|interface\s+)*class\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
    
    // 1. Enum declarations - simplified and more flexible
    RegExp(r'^\s*(?:\/\/+\s*)?enum\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
    
    // 2. Mixin declarations - simplified pattern, removed complex lookahead
    RegExp(r'^\s*(?:\/\/+\s*)?mixin\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
    
    // 3. Extension with name - improved to handle generics better
    RegExp(r'^\s*(?:\/\/+\s*)?extension\s+([A-Za-z_][A-Za-z0-9_]*(?:<[^>]*>)?)\s+on\s+', multiLine: false),
    
    // 4. Anonymous extension
    RegExp(r'^\s*(?:\/\/+\s*)?extension\s+on\s+([A-Za-z_][A-Za-z0-9_<>,\s]*)', multiLine: false),
    
    // 5. Typedef declarations
    RegExp(r'^\s*(?:\/\/+\s*)?typedef\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
    
    // 6. Mixin class declarations (Dart 3.0+) - must be before regular mixin
    RegExp(r'^\s*(?:\/\/+\s*)?mixin\s+class\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
  ];
  
  String? className;
  String classType = 'class';
  bool isCommentedOut = false;
  
  // Check mixin class first (specific case before general mixin)
  if (trimmedLine.contains('mixin class') || trimmedLine.contains('mixin')) {
    for (RegExp pattern in classPatterns) {
      RegExpMatch? match = pattern.firstMatch(trimmedLine);
      if (match != null && pattern == classPatterns[6]) { // mixin class pattern
        className = match.group(1)!;
        classType = 'mixin_class';
        isCommentedOut = trimmedLine.startsWith('//') || _isInMultiLineComment(lines, lineIndex);
        break;
      }
    }
  }
  
  // If not found yet, check other patterns
  if (className == null) {
    for (int i = 0; i < classPatterns.length; i++) {
      if (i == 6) continue; // Skip mixin class as we handled it above
      
      RegExp pattern = classPatterns[i];
      RegExpMatch? match = pattern.firstMatch(trimmedLine);
      
      if (match != null) {
        className = match.group(1)!;
        isCommentedOut = trimmedLine.startsWith('//') || _isInMultiLineComment(lines, lineIndex);
        
        // Don't match mixin class with regular mixin pattern
        if (i == 2 && trimmedLine.contains('mixin class')) {
          continue;
        }
        
        switch (i) {
          case 0: classType = _determineClassType(trimmedLine, insideStateClass); break;
          case 1: classType = 'enum'; break;
          case 2: classType = 'mixin'; break;
          case 3: classType = 'extension'; break;
          case 4: 
            classType = 'extension';
            className = 'ExtensionOn' + className!.replaceAll(RegExp(r'[<>,\s]'), '');
            break;
          case 5: classType = 'typedef'; break;
        }
        break;
      }
    }
  }

  if (className != null) {
    // Skip if it's a Dart keyword or built-in type
    if (_isDartKeyword(className)) {
      return;
    }
    
    // Entry point check
    bool isEntryPoint = _checkEntryPoint(lines, lineIndex, pragmaRegex);

    // Store class information
    classes[className] = ClassInfo(
      filePath,
      isEntryPoint: isEntryPoint,
      commentedOut: isCommentedOut,
      type: classType,
    );
  }
}

/// Check if we're inside a multi-line comment
bool _isInMultiLineComment(List<String> lines, int lineIndex) {
  bool inComment = false;
  
  for (int i = 0; i <= lineIndex; i++) {
    String line = lines[i];
    
    // Process line character by character to handle nested comments
    for (int j = 0; j < line.length - 1; j++) {
      if (line.substring(j, j + 2) == '/*') {
        inComment = true;
        j++; // Skip next character
      } else if (line.substring(j, j + 2) == '*/') {
        inComment = false;
        j++; // Skip next character
      }
    }
  }
  
  return inComment;
}

/// Determine the specific type of class with improved detection
String _determineClassType(String line, bool insideStateClass) {
  String lowerLine = line.toLowerCase();
  
  // Check for mixin class first (Dart 3.0+)
  if (lowerLine.contains('mixin class')) {
    return 'mixin_class';
  } else if (lowerLine.contains('sealed class') || lowerLine.contains('sealed')) {
    return 'sealed_class';
  } else if (lowerLine.contains('base class') || lowerLine.contains('base')) {
    return 'base_class';
  } else if (lowerLine.contains('final class') || lowerLine.contains('final')) {
    return 'final_class';
  } else if (lowerLine.contains('interface class') || lowerLine.contains('interface')) {
    return 'interface_class';
  } else if (lowerLine.contains('abstract class') || lowerLine.contains('abstract')) {
    return 'abstract_class';
  } else if (lowerLine.contains('extends state<') || lowerLine.contains('state<')) {
    return 'state_class';
  } else if (lowerLine.contains('extends statelesswidget')) {
    return 'stateless_widget';
  } else if (lowerLine.contains('extends statefulwidget')) {
    return 'stateful_widget';
  } else {
    return 'class';
  }
}

/// Check if the class has an entry point pragma
bool _checkEntryPoint(List<String> lines, int lineIndex, RegExp pragmaRegex) {
  // Check the previous 5 lines for pragma annotations
  for (int i = 1; i <= 5 && lineIndex - i >= 0; i++) {
    String prevLine = lines[lineIndex - i].trim();
    if (pragmaRegex.hasMatch(prevLine)) {
      return true;
    }
    // Continue checking even if we hit comments or annotations
    if (prevLine.isNotEmpty && 
        !prevLine.startsWith('//') && 
        !prevLine.startsWith('/*') &&
        !prevLine.startsWith('*') &&
        !prevLine.startsWith('*/') &&
        !prevLine.startsWith('@') &&
        !prevLine.startsWith('///')) {
      // Only stop if we hit actual code (not comments or annotations)
      if (!prevLine.contains('class') && 
          !prevLine.contains('enum') && 
          !prevLine.contains('mixin') &&
          !prevLine.contains('extension') &&
          !prevLine.contains('typedef')) {
        break;
      }
    }
  }
  return false;
}

/// Check if the identifier is a Dart keyword that should be ignored
bool _isDartKeyword(String identifier) {
  const keywords = {
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'default', 'deferred', 'do', 'dynamic',
    'else', 'enum', 'export', 'extends', 'external', 'factory', 'false',
    'final', 'finally', 'for', 'Function', 'get', 'hide', 'if', 'implements',
    'import', 'in', 'interface', 'is', 'late', 'library', 'mixin', 'new',
    'null', 'on', 'operator', 'part', 'required', 'rethrow', 'return',
    'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this',
    'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with', 'yield'
  };
  return keywords.contains(identifier.toLowerCase());
}

// Enhanced debug function
void debugPatternMatching(String line) {
  print('Testing line: "$line"');
  
  List<String> patternNames = [
    'Regular class (with modifiers)',
    'Enum',
    'Mixin',
    'Extension with name',
    'Anonymous extension',
    'Typedef',
    'Mixin class'
  ];
  
  List<RegExp> patterns = [
    RegExp(r'^\s*(?:\/\/+\s*)?(?:sealed\s+|abstract\s+|base\s+|final\s+|interface\s+)*class\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
    RegExp(r'^\s*(?:\/\/+\s*)?enum\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
    RegExp(r'^\s*(?:\/\/+\s*)?mixin\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:on\s+[^{]+)?(?:\s*{|\s*$)', multiLine: false),
    RegExp(r'^\s*(?:\/\/+\s*)?extension\s+([A-Za-z_][A-Za-z0-9_]*(?:<[^>]*>)?)\s+on\s+', multiLine: false),
    RegExp(r'^\s*(?:\/\/+\s*)?extension\s+on\s+([A-Za-z_][A-Za-z0-9_<>]*)', multiLine: false),
    RegExp(r'^\s*(?:\/\/+\s*)?typedef\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
    RegExp(r'^\s*(?:\/\/+\s*)?mixin\s+class\s+([A-Za-z_][A-Za-z0-9_]*)', multiLine: false),
  ];
  
  bool foundMatch = false;
  for (int i = 0; i < patterns.length; i++) {
    RegExpMatch? match = patterns[i].firstMatch(line.trim());
    if (match != null) {
      print('  ✓ ${patternNames[i]}: "${match.group(1)}"');
      foundMatch = true;
    }
  }
  
  if (!foundMatch) {
    print('  ✗ No patterns matched');
  }
}
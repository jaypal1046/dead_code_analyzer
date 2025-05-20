import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

void main(List<String> arguments) {
  // Create argument parser
  final parser = ArgParser()
    ..addOption('project-path',
        abbr: 'p',
        help: 'Path to the Flutter project to analyze',
        defaultsTo: '.')
    ..addOption('output-dir',
        abbr: 'o',
        help: 'Directory to save the report file (default: Desktop)',
        defaultsTo: '')
    ..addFlag('help',
        abbr: 'h', help: 'Show usage information', negatable: false)
    ..addFlag('verbose',
        abbr: 'v', help: 'Show detailed output', negatable: false)
    ..addFlag('no-progress',
        help: 'Disable progress indicators', negatable: false);

  // Parse arguments
  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    _printUsage(parser);
    exit(1);
  }

  // Show help if requested
  if (args['help']) {
    _printUsage(parser);
    return;
  }

  // Get project path
  final projectPathStr = args['project-path'];
  final projectPath = path.normalize(path.absolute(projectPathStr));
  final projectDir = Directory(projectPath);

  // Get output directory
  String outputDir = args['output-dir'];
  if (outputDir.isEmpty) {
    // Default to Desktop if not specified
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    outputDir = path.join(home, 'Desktop');
  }

  // Verify project directory exists
  if (!projectDir.existsSync()) {
    print('Error: Project directory not found: $projectPath');
    exit(1);
  }

  print('Analyzing Flutter project at: $projectPath');

  final verbose = args['verbose'];
  final showProgress = !args['no-progress'];

  if (verbose) {
    print('Collecting class information...');
  }

  final classes = <String, ClassInfo>{};

  // First pass: collect all class names
  collectClassNames(projectDir, classes, showProgress);

  if (verbose) {
    print('\nFound ${classes.length} classes.');
    print('Finding class usages...');
  }

  // Second pass: find usages
  findUsages(projectDir, classes, showProgress);

  // Print results and save to file
  printResults(classes, verbose, outputDir);
}

void _printUsage(ArgParser parser) {
  print('Usage: dart bin/flutter_class_analyzer.dart [options]');
  print(parser.usage);
  print('\nExample:');
  print(
      '  dart bin/flutter_class_analyzer.dart -p /path/to/flutter/project -o /path/to/save/report');
}

class ClassInfo {
  final String definedInFile;
  final List<String> internalUsages = []; // Usage within own file
  final List<String> externalUsages = []; // Usage in other files

  ClassInfo(this.definedInFile);
  
  int get totalUsages => internalUsages.length + externalUsages.length;
}

/// Progress bar display class
class ProgressBar {
  final int total;
  final int width;
  final String description;
  int _current = 0;
  bool _done = false;

  ProgressBar(this.total, {this.width = 40, this.description = 'Processing'});

  void update(int current) {
    _current = min(current, total);
    _draw();
  }

  void increment() {
    update(_current + 1);
  }

  void done() {
    if (!_done) {
      _current = total;
      _draw();
      stdout.writeln();
      _done = true;
    }
  }

  void _draw() {
    if (total <= 0) return;

    final ratio = _current / total;
    final percentage = (ratio * 100).toInt();
    final completedWidth = (width * ratio).floor();

    final bar = '[' +
        '=' * completedWidth +
        (completedWidth < width ? '>' : '') +
        ' ' * (width - completedWidth - (completedWidth < width ? 1 : 0)) +
        ']';

    final progressText = '$_current/$total ($percentage%)';
    final line = '\r$description: $bar $progressText';

    stdout.write(line);
  }
}

List<File> getDartFiles(Directory dir) {
  return dir
      .listSync(recursive: true)
      .where((entity) =>
          entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.contains('/.dart_tool/') &&
          !entity.path.contains('/build/'))
      .cast<File>()
      .toList();
}

void collectClassNames(
    Directory dir, Map<String, ClassInfo> classes, bool showProgress) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar = ProgressBar(dartFiles.length,
        description: 'Scanning files for classes');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = file.path;

    try {
      final content = File(filePath).readAsStringSync();

      // Find class definitions using regex
      final classRegex = RegExp(r'class\s+(\w+)[\s{<]');
      final matches = classRegex.allMatches(content);

      for (final match in matches) {
        final className = match.group(1)!;
        classes[className] = ClassInfo(filePath);
      }
    } catch (e) {
      // Skip files that can't be read
      print('\nWarning: Could not read file $filePath: $e');
    }

    count++;
    if (showProgress) {
      progressBar!.update(count);
    }
  }

  if (showProgress) {
    progressBar!.done();
  }
}

void findUsages(
    Directory dir, Map<String, ClassInfo> classes, bool showProgress) {
  final dartFiles = getDartFiles(dir);

  ProgressBar? progressBar;
  if (showProgress) {
    progressBar =
        ProgressBar(dartFiles.length, description: 'Analyzing class usage');
  }

  var count = 0;
  for (final file in dartFiles) {
    final filePath = file.path;

    try {
      final content = File(filePath).readAsStringSync();

      for (final entry in classes.entries) {
        final className = entry.key;
        final classInfo = entry.value;

        // Look for usages (references to the class name)
        final usageRegex = RegExp('\\b$className\\b');
        if (usageRegex.hasMatch(content)) {
          // Check if this is the file where the class is defined
          if (filePath == classInfo.definedInFile) {
            classInfo.internalUsages.add(filePath);
          } else {
            classInfo.externalUsages.add(filePath);
          }
        }
      }
    } catch (e) {
      // Skip files that can't be read
      print('\nWarning: Could not read file $filePath: $e');
    }

    count++;
    if (showProgress) {
      progressBar!.update(count);
    }
  }

  if (showProgress) {
    progressBar!.done();
  }
}

void printResults(
    Map<String, ClassInfo> classes, bool verbose, String outputDir) {
  // Convert to sorted list
  final sortedClasses = classes.entries.toList()
    ..sort((a, b) => b.value.totalUsages.compareTo(a.value.totalUsages));

  final results = <String, dynamic>{};

  for (final entry in sortedClasses) {
    final className = entry.key;
    final classInfo = entry.value;

    // Format locations for easier reading
    final formattedExternalLocations = classInfo.externalUsages.map((loc) {
      final relativePath =
          path.relative(loc, from: path.dirname(classInfo.definedInFile));
      return relativePath;
    }).toList();
    
    // Count internal references (minus 1 for the definition itself)
    final internalReferences = classInfo.internalUsages.length > 0 ? 
        classInfo.internalUsages.length - 1 : 0;

    results[className] = {
      'defined_in': path.basename(classInfo.definedInFile),
      'internal_usage_count': internalReferences,
      'external_usage_count': classInfo.externalUsages.length,
      'total_usages': internalReferences + classInfo.externalUsages.length,
      'external_locations': verbose ? formattedExternalLocations : null,
    };
  }

  // Generate usage categories
  final unusedClasses = <String>[];
  final internalOnlyClasses = <String>[];
  final rarelyUsedClasses = <String>[];
  final frequentlyUsedClasses = <String>[];

  for (final entry in sortedClasses) {
    final className = entry.key;
    final classInfo = entry.value;
    final internalUsages = classInfo.internalUsages.isEmpty ? 0 : classInfo.internalUsages.length - 1;
    final externalUsages = classInfo.externalUsages.length;
    final totalUsages = internalUsages + externalUsages;

    if (totalUsages == 0) {
      unusedClasses.add(className);
    } else if (externalUsages == 0) {
      internalOnlyClasses.add(className);
    } else if (externalUsages <= 2) {
      rarelyUsedClasses.add(className);
    } else if (totalUsages > 10) {
      frequentlyUsedClasses.add(className);
    }
  }

  // Print full results if verbose
  if (verbose) {
    print('\nDetailed class usage:');
    print(JsonEncoder.withIndent('  ').convert(results));
  }

  // Print summary
  print('\nSummary:');
  print('Total classes: ${classes.length}');
  print(
      'Unused classes: ${unusedClasses.length} (${(unusedClasses.length / classes.length * 100).toStringAsFixed(1)}%)');
  print('Internal-only classes: ${internalOnlyClasses.length}');
  print('Rarely used externally (1-2 external usages): ${rarelyUsedClasses.length}');
  print(
      'Frequently used classes (>10 total usages): ${frequentlyUsedClasses.length}');

  // Print potentially dead classes
  if (unusedClasses.isNotEmpty) {
    print('\nPotentially dead classes:');
    for (int i = 0; i < min(unusedClasses.length, 10); i++) {
      final className = unusedClasses[i];
      final definedIn = path.basename(classes[className]!.definedInFile);
      print(' - $className (defined in $definedIn)');
    }

    if (unusedClasses.length > 10) {
      print(' - ... and ${unusedClasses.length - 10} more');
    }
  }

  // Save results to file
  saveResultsToFile(classes, outputDir);

  // Print suggestions
  print('\nRecommendations:');
  if (unusedClasses.isNotEmpty) {
    print('- Consider removing the unused classes listed above');
  }
  if (internalOnlyClasses.isNotEmpty) {
    print(
        '- Review classes used only internally to determine if their scope can be reduced');
  }
  if (rarelyUsedClasses.isNotEmpty) {
    print(
        '- Review rarely used classes to determine if they can be consolidated');
  }

  if (!verbose && (unusedClasses.isNotEmpty || rarelyUsedClasses.isNotEmpty)) {
    print('\nTip: Run with --verbose flag to see detailed usage information.');
  }
}

void saveResultsToFile(Map<String, ClassInfo> classes, String outputDir) {
  try {
    // Create timestamp for filename
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    final timestamp = formatter.format(now);
    final filename = 'flutter_class_analysis_$timestamp.txt';
    final filePath = path.join(outputDir, filename);

    // Prepare content for file
    final buffer = StringBuffer();
    buffer.writeln('Flutter Class Usage Analysis - ${formatter.format(now)}');
    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln('POTENTIALLY UNUSED OR DEAD CLASSES:');
    buffer.writeln('=' * 50);

    // Sort classes by total usage count (ascending)
    final sortedClasses = classes.entries.toList()
      ..sort((a, b) {
        // First compare external usage
        final externalComparison = a.value.externalUsages.length.compareTo(b.value.externalUsages.length);
        if (externalComparison != 0) return externalComparison;
        
        // If external usage is same, compare total usage
        return (a.value.internalUsages.length - 1 + a.value.externalUsages.length)
            .compareTo(b.value.internalUsages.length - 1 + b.value.externalUsages.length);
      });

    // First list all unused classes (0 usages)
    buffer.writeln('\nUNUSED CLASSES (0 total usages):');
    buffer.writeln('-' * 30);
    int unusedCount = 0;
    int stateClassCount = 0;

    // First, separate regular classes and state classes
    final List<MapEntry<String, ClassInfo>> mainClassEntries = [];
    final List<MapEntry<String, ClassInfo>> stateClassEntries = [];

    for (final entry in sortedClasses) {
      final className = entry.key;
      
      // Check if this is a State class, which either:
      // 1. Ends with "State" and has a corresponding class without "State" suffix
      // 2. Starts with an underscore and ends with "State"
      bool isStateClass = false;
      
      if (className.endsWith('State')) {
        // Check if there's a corresponding widget class
        final possibleWidgetName = className.substring(0, className.length - 5);
        if (classes.containsKey(possibleWidgetName)) {
          isStateClass = true;
        } else if (className.startsWith('_')) {
          isStateClass = true;
        }
      }
      
      if (isStateClass) {
        stateClassEntries.add(entry);
      } else {
        mainClassEntries.add(entry);
      }
    }

    // Process main classes (unused)
    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsages.isEmpty ? 0 : classInfo.internalUsages.length - 1;
      final externalUses = classInfo.externalUsages.length;
      final totalUses = internalUses + externalUses;

      if (totalUses == 0) {
        unusedCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        buffer.writeln(' - $className (defined in $definedIn, internal uses: 0, external uses: 0)');
      }
    }

    if (unusedCount == 0) {
      buffer.writeln('No unused regular classes found.');
    }

    // Process state classes (unused) - separate section
    buffer.writeln('\nUNUSED STATE CLASSES (0 total usages):');
    buffer.writeln('-' * 30);
    
    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsages.isEmpty ? 0 : classInfo.internalUsages.length - 1;
      final externalUses = classInfo.externalUsages.length;
      final totalUses = internalUses + externalUses;

      if (totalUses == 0) {
        stateClassCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        buffer.writeln(' - $className (defined in $definedIn, internal uses: 0, external uses: 0)');
      }
    }

    if (stateClassCount == 0) {
      buffer.writeln('No unused state classes found.');
    }

    // Next list internal-only classes (only used in same file)
    buffer.writeln('\nINTERNAL-ONLY MAIN CLASSES (used only in the file they are defined):');
    buffer.writeln('-' * 30);
    int internalOnlyCount = 0;

    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsages.isEmpty ? 0 : classInfo.internalUsages.length - 1;
      final externalUses = classInfo.externalUsages.length;

      if (internalUses > 0 && externalUses == 0) {
        internalOnlyCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        buffer.writeln(' - $className (defined in $definedIn, internal uses: $internalUses, external uses: 0)');
      }
    }

    if (internalOnlyCount == 0) {
      buffer.writeln('No internal-only main classes found.');
    }

    // Next list rarely used classes externally (1-2 external usages)
    buffer.writeln('\nRARELY USED EXTERNALLY MAIN CLASSES (1-2 external usages):');
    buffer.writeln('-' * 30);
    int rarelyUsedCount = 0;

    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsages.isEmpty ? 0 : classInfo.internalUsages.length - 1;
      final externalUses = classInfo.externalUsages.length;

      if (externalUses > 0 && externalUses <= 2) {
        rarelyUsedCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        
        // Format the usage files list
        final usageFiles = classInfo.externalUsages.map((filePath) => path.basename(filePath)).toList();
        final usageFilesStr = usageFiles.toString(); // This will be in format [file1.dart, file2.dart]
        
        buffer.writeln(
            ' - $className (defined in $definedIn, internal uses: $internalUses, external uses: $externalUses) $usageFilesStr');
      }
    }

    if (rarelyUsedCount == 0) {
      buffer.writeln('No rarely used externally main classes found.');
    }

    // Next list rarely used state classes externally (1-2 usages)
    buffer.writeln('\nRARELY USED EXTERNALLY STATE CLASSES (1-2 external usages):');
    buffer.writeln('-' * 30);
    int rarelyUsedStateCount = 0;

    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsages.isEmpty ? 0 : classInfo.internalUsages.length - 1;
      final externalUses = classInfo.externalUsages.length;

      if (externalUses > 0 && externalUses <= 2) {
        rarelyUsedStateCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        
        // Format the usage files list
        final usageFiles = classInfo.externalUsages.map((filePath) => path.basename(filePath)).toList();
        final usageFilesStr = usageFiles.toString(); // This will be in format [file1.dart, file2.dart]
        
        buffer.writeln(
            ' - $className (defined in $definedIn, internal uses: $internalUses, external uses: $externalUses) $usageFilesStr');
      }
    }

    if (rarelyUsedStateCount == 0) {
      buffer.writeln('No rarely used externally state classes found.');
    }

    // Complete class listing - main classes
    buffer.writeln('\nCOMPLETE MAIN CLASS USAGE LIST:');
    buffer.writeln('-' * 30);

    // Sort by external usage first, then total usage for the complete listing
    mainClassEntries.sort((a, b) {
      final externalA = a.value.externalUsages.length;
      final externalB = b.value.externalUsages.length;
      
      if (externalB != externalA) {
        return externalB.compareTo(externalA); // Primary sort: external usages descending
      }
      
      final internalA = a.value.internalUsages.isEmpty ? 0 : a.value.internalUsages.length - 1;
      final internalB = b.value.internalUsages.isEmpty ? 0 : b.value.internalUsages.length - 1;
      
      return (internalB + externalB).compareTo(internalA + externalA); // Secondary sort: total usages descending
    });

    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsages.isEmpty ? 0 : classInfo.internalUsages.length - 1;
      final externalUses = classInfo.externalUsages.length;
      final totalUses = internalUses + externalUses;
      final definedIn = path.basename(classInfo.definedInFile);
      
      // Format the usage files list - empty for unused classes
      String usageFilesStr = '';
      if (externalUses > 0) {
        final usageFiles = classInfo.externalUsages.map((filePath) => path.basename(filePath)).toList();
        usageFilesStr = usageFiles.toString(); // This will be in format [file1.dart, file2.dart]
      }
      
      buffer.writeln(
          ' - $className (defined in $definedIn, internal uses: $internalUses, external uses: $externalUses, total: $totalUses)${externalUses > 0 ? ' $usageFilesStr' : ''}');
    }

    // Complete class listing - state classes
    buffer.writeln('\nCOMPLETE STATE CLASS USAGE LIST:');
    buffer.writeln('-' * 30);

    // Sort state classes by usage similarly to main classes
    stateClassEntries.sort((a, b) {
      final externalA = a.value.externalUsages.length;
      final externalB = b.value.externalUsages.length;
      
      if (externalB != externalA) {
        return externalB.compareTo(externalA); // Primary sort: external usages descending
      }
      
      final internalA = a.value.internalUsages.isEmpty ? 0 : a.value.internalUsages.length - 1;
      final internalB = b.value.internalUsages.isEmpty ? 0 : b.value.internalUsages.length - 1;
      
      return (internalB + externalB).compareTo(internalA + externalA); // Secondary sort: total usages descending
    });

    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final internalUses = classInfo.internalUsages.isEmpty ? 0 : classInfo.internalUsages.length - 1;
      final externalUses = classInfo.externalUsages.length;
      final totalUses = internalUses + externalUses;
      final definedIn = path.basename(classInfo.definedInFile);
      
      // Format the usage files list - empty for unused classes
      String usageFilesStr = '';
      if (externalUses > 0) {
        final usageFiles = classInfo.externalUsages.map((filePath) => path.basename(filePath)).toList();
        usageFilesStr = usageFiles.toString(); // This will be in format [file1.dart, file2.dart]
      }
      
      buffer.writeln(
          ' - $className (defined in $definedIn, internal uses: $internalUses, external uses: $externalUses, total: $totalUses)${externalUses > 0 ? ' $usageFilesStr' : ''}');
    }

    // Add summary
    buffer.writeln('\nSUMMARY:');
    buffer.writeln('-' * 30);
    buffer.writeln('Total classes: ${classes.length}');
    buffer.writeln('Main classes: ${mainClassEntries.length}');
    buffer.writeln('State classes: ${stateClassEntries.length}');
    buffer.writeln(
        'Unused main classes: $unusedCount (${(unusedCount / mainClassEntries.length * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Unused state classes: $stateClassCount (${(stateClassCount / (stateClassEntries.length > 0 ? stateClassEntries.length : 1) * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Internal-only main classes: $internalOnlyCount (${(internalOnlyCount / mainClassEntries.length * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Rarely used externally main classes (1-2 external usages): $rarelyUsedCount (${(rarelyUsedCount / mainClassEntries.length * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Rarely used externally state classes (1-2 external usages): $rarelyUsedStateCount (${(rarelyUsedStateCount / (stateClassEntries.length > 0 ? stateClassEntries.length : 1) * 100).toStringAsFixed(1)}%)');

    // Write to file
    final file = File(filePath);
    file.writeAsStringSync(buffer.toString());

    print('\nFull analysis saved to: $filePath');
  } catch (e) {
    print('\nError saving results to file: $e');
  }
}
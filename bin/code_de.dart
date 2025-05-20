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
  final List<String> usages = [];

  ClassInfo(this.definedInFile);
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

        // Skip self-references (where class is only referenced in its own file)
        if (filePath == classInfo.definedInFile) {
          continue;
        }

        // Look for usages (references to the class name)
        final usageRegex = RegExp('\\b$className\\b');
        if (usageRegex.hasMatch(content)) {
          classInfo.usages.add(filePath);
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
    ..sort((a, b) => b.value.usages.length.compareTo(a.value.usages.length));

  final results = <String, dynamic>{};

  for (final entry in sortedClasses) {
    final className = entry.key;
    final classInfo = entry.value;

    // Format locations for easier reading
    final formattedLocations = classInfo.usages.map((loc) {
      final relativePath =
          path.relative(loc, from: path.dirname(classInfo.definedInFile));
      return relativePath;
    }).toList();

    results[className] = {
      'defined_in': path.basename(classInfo.definedInFile),
      'usage_count': classInfo.usages.length,
      'locations': verbose ? formattedLocations : null,
    };
  }

  // Generate usage categories
  final unusedClasses = <String>[];
  final rarelyUsedClasses = <String>[];
  final frequentlyUsedClasses = <String>[];

  for (final entry in sortedClasses) {
    final className = entry.key;
    final usageCount = entry.value.usages.length;

    if (usageCount == 0) {
      unusedClasses.add(className);
    } else if (usageCount <= 2) {
      rarelyUsedClasses.add(className);
    } else if (usageCount > 10) {
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
  print('Rarely used classes (1-2 usages): ${rarelyUsedClasses.length}');
  print(
      'Frequently used classes (>10 usages): ${frequentlyUsedClasses.length}');

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

    // Sort classes by usage count (ascending)
    final sortedClasses = classes.entries.toList()
      ..sort((a, b) => a.value.usages.length.compareTo(b.value.usages.length));

    // First list all unused classes (0 usages)
    buffer.writeln('\nUNUSED CLASSES (0 usages):');
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

      if (classInfo.usages.isEmpty) {
        unusedCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        buffer.writeln(' - $className (defined in $definedIn, called 0 times)');
      }
    }

    if (unusedCount == 0) {
      buffer.writeln('No unused regular classes found.');
    }

    // Process state classes (unused) - separate section
    buffer.writeln('\nUNUSED STATE CLASSES (0 usages):');
    buffer.writeln('-' * 30);
    
    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;

      if (classInfo.usages.isEmpty) {
        stateClassCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        buffer.writeln(' - $className (defined in $definedIn, called 0 times)');
      }
    }

    if (stateClassCount == 0) {
      buffer.writeln('No unused state classes found.');
    }

    // Next list rarely used classes (1-2 usages)
    buffer.writeln('\nRARELY USED MAIN CLASSES (1-2 usages):');
    buffer.writeln('-' * 30);
    int rarelyUsedCount = 0;

    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final usageCount = classInfo.usages.length;

      if (usageCount > 0 && usageCount <= 2) {
        rarelyUsedCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        
        // Format the usage files list
        final usageFiles = classInfo.usages.map((filePath) => path.basename(filePath)).toList();
        final usageFilesStr = usageFiles.toString(); // This will be in format [file1.dart, file2.dart]
        
        buffer.writeln(
            ' - $className (defined in $definedIn, called $usageCount time${usageCount == 1 ? '' : 's'}) $usageFilesStr');
      }
    }

    if (rarelyUsedCount == 0) {
      buffer.writeln('No rarely used main classes found.');
    }

    // Next list rarely used state classes (1-2 usages)
    buffer.writeln('\nRARELY USED STATE CLASSES (1-2 usages):');
    buffer.writeln('-' * 30);
    int rarelyUsedStateCount = 0;

    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final usageCount = classInfo.usages.length;

      if (usageCount > 0 && usageCount <= 2) {
        rarelyUsedStateCount++;
        final definedIn = path.basename(classInfo.definedInFile);
        
        // Format the usage files list
        final usageFiles = classInfo.usages.map((filePath) => path.basename(filePath)).toList();
        final usageFilesStr = usageFiles.toString(); // This will be in format [file1.dart, file2.dart]
        
        buffer.writeln(
            ' - $className (defined in $definedIn, called $usageCount time${usageCount == 1 ? '' : 's'}) $usageFilesStr');
      }
    }

    if (rarelyUsedStateCount == 0) {
      buffer.writeln('No rarely used state classes found.');
    }

    // Complete class listing - main classes
    buffer.writeln('\nCOMPLETE MAIN CLASS USAGE LIST:');
    buffer.writeln('-' * 30);

    for (final entry in mainClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final usageCount = classInfo.usages.length;
      final definedIn = path.basename(classInfo.definedInFile);
      
      // Format the usage files list - empty for unused classes
      String usageFilesStr = '';
      if (usageCount > 0) {
        final usageFiles = classInfo.usages.map((filePath) => path.basename(filePath)).toList();
        usageFilesStr = usageFiles.toString(); // This will be in format [file1.dart, file2.dart]
      }
      
      buffer.writeln(
          ' - $className (defined in $definedIn, called $usageCount time${usageCount == 1 ? '' : 's'})${usageCount > 0 ? ' $usageFilesStr' : ''}');
    }

    // Complete class listing - state classes
    buffer.writeln('\nCOMPLETE STATE CLASS USAGE LIST:');
    buffer.writeln('-' * 30);

    for (final entry in stateClassEntries) {
      final className = entry.key;
      final classInfo = entry.value;
      final usageCount = classInfo.usages.length;
      final definedIn = path.basename(classInfo.definedInFile);
      
      // Format the usage files list - empty for unused classes
      String usageFilesStr = '';
      if (usageCount > 0) {
        final usageFiles = classInfo.usages.map((filePath) => path.basename(filePath)).toList();
        usageFilesStr = usageFiles.toString(); // This will be in format [file1.dart, file2.dart]
      }
      
      buffer.writeln(
          ' - $className (defined in $definedIn, called $usageCount time${usageCount == 1 ? '' : 's'})${usageCount > 0 ? ' $usageFilesStr' : ''}');
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
        'Rarely used main classes (1-2 usages): $rarelyUsedCount (${(rarelyUsedCount / mainClassEntries.length * 100).toStringAsFixed(1)}%)');
    buffer.writeln(
        'Rarely used state classes (1-2 usages): $rarelyUsedStateCount (${(rarelyUsedStateCount / (stateClassEntries.length > 0 ? stateClassEntries.length : 1) * 100).toStringAsFixed(1)}%)');

    // Write to file
    final file = File(filePath);
    file.writeAsStringSync(buffer.toString());

    print('\nFull analysis saved to: $filePath');
  } catch (e) {
    print('\nError saving results to file: $e');
  }
}
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) {
  // Create argument parser
  final parser = ArgParser()
    ..addOption('project-path',
        abbr: 'p',
        help: 'Path to the Flutter project to analyze',
        defaultsTo: '.')
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

  // Print results
  printResults(classes, verbose);
}

void _printUsage(ArgParser parser) {
  print('Usage: dart bin/flutter_class_analyzer.dart [options]');
  print(parser.usage);
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

void printResults(Map<String, ClassInfo> classes, bool verbose) {
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

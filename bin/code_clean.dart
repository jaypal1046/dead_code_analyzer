import 'dart:io';
import 'package:args/args.dart';
import 'package:code_clean/src/analyzers/class_collector.dart';
import 'package:code_clean/src/analyzers/usage_analyzer.dart';
import 'package:code_clean/src/model/class_info.dart';
import 'package:code_clean/src/reporters/console_reporter.dart';
import 'package:path/path.dart' as path;

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

  // First pass: collect all class names and their definition locations
  collectClassNames(projectDir, classes, showProgress);

  if (verbose) {
    print('\nFound ${classes.length} classes.');
    print('Finding class usages...');
  }

  // Second pass: find usages - completely revamped to count actual occurrences
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

import 'dart:io';
import 'package:args/args.dart';
import 'package:dead_code_analyzer/src/analyzers/code_analyzer.dart';
import 'package:dead_code_analyzer/src/analyzers/usage_analyzer.dart';
import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';
import 'package:dead_code_analyzer/src/reporters/dead_code_cleaner.dart';
import 'package:dead_code_analyzer/src/reporters/console_reporter.dart';
import 'package:dead_code_analyzer/src/reporters/file_reporter.dart';
import 'package:dead_code_analyzer/src/utils/healper.dart';
import 'package:dead_code_analyzer/src/utils/varsion_info.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('project-path',
        abbr: 'p',
        help: 'Path to the Flutter project to analyze',
        defaultsTo: '.')
    ..addOption('output-dir',
        abbr: 'o',
        help: 'Directory to save the report file (default: Desktop)',
        defaultsTo: '')
    ..addOption('max-unused',
        help: 'Maximum number of unused entities to display in console',
        defaultsTo: '10')
    ..addFlag('analyze-functions',
        help: 'Include function usage analysis', defaultsTo: false)
    ..addFlag('clean',
        help: 'Clean up files containing only dead or commented-out classes',
        negatable: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show usage information', negatable: false)
    ..addFlag('verbose',
        abbr: 'v', help: 'Show detailed output', negatable: false)
    ..addFlag('no-progress',
        help: 'Disable progress indicators', negatable: false);

  // Try to get version from version file or pubspec.yaml
  versionfind(parser, arguments);

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error parsing arguments: $e');
    printUsage(parser);
    exit(1);
  }

  if (args['help']) {
    printUsage(parser);
    return;
  }

  final projectPathStr = args['project-path'];
  final projectPath = path.normalize(path.absolute(projectPathStr));
  final projectDir = Directory(projectPath);

  String outputDir = args['output-dir'];
  if (outputDir.isEmpty) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    outputDir = path.join(home, 'Desktop');
  }

  if (!projectDir.existsSync()) {
    print('Error: Project directory not found at $projectPath');
    exit(1);
  }

  print('Analyzing Flutter project at: $projectPath');

  final verbose = args['verbose'];
  final showProgress = !args['no-progress'];
  final maxUnused = int.parse(args['max-unused']);
  final analyzeFunctions = args['analyze-functions'];
  final clean = args['clean'];

  if (verbose) {
    print('Collecting code entities...');
  }

  final classes = <String, ClassInfo>{};
  final functions = <String, CodeInfo>{};
  // Collect all code entities (classes and functions) from the project directory
  collectCodeEntities(
      dir: projectDir,
      classes: classes,
      functions: functions,
      showProgress: showProgress,
      analyzeFunctions: analyzeFunctions);

  if (verbose) {
    print(
        '\nFound ${classes.length} classes${analyzeFunctions ? ' and ${functions.length} functions' : ''}.');
    print('Analyzing code references...');
  }

  // Find all usages/references of the collected code entities
  findUsages(
      dir: projectDir,
      classes: classes,
      functions: functions,
      showProgress: showProgress,
      analyzeFunctions: analyzeFunctions);

  // Print analysis results to console
  printResults(
      classes: classes,
      functions: functions,
      verbose: verbose,
      projectPath: projectPath,
      analyzeFunctions: analyzeFunctions,
      maxUnused: maxUnused);

  // Save analysis results to output file
  saveResultsToFile(
      classes: classes,
      functions: functions,
      outputDir: outputDir,
      projectPath: projectPath,
      analyzeFunctions: analyzeFunctions);

  // Perform cleanup if --clean flag is provided
  if (clean) {
    print('\nStarting cleanup of dead and commented-out classes...');
    deadCodeCleaner(
      classes: classes,
      functions: functions,
      projectPath: projectPath,
      analyzeFunctions: analyzeFunctions,
    );
  }
}

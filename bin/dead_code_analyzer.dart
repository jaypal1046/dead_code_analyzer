import 'dart:io';
import 'package:args/args.dart';
import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('path',
        abbr: 'p',
        help: 'Path to the Flutter project to analyze',
        defaultsTo: '.')
    ..addOption('out',
        abbr: 'o',
        help: 'Directory to save the report file (default: Desktop)',
        defaultsTo: '')
    ..addOption('limit',
        abbr: 'l',
        help: 'Maximum number of unused entities to display in console',
        defaultsTo: '10')
    ..addFlag('funcs',
        abbr: 'f', help: 'Include function usage analysis', defaultsTo: false)
    ..addFlag('clean',
        abbr: 'c',
        help: 'Clean up files containing only dead or commented-out classes',
        negatable: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show usage information', negatable: false)
    ..addFlag('trace',
        abbr: 't', help: 'Show detailed execution trace', defaultsTo: false)
    ..addFlag('quiet',
        abbr: 'q', help: 'Disable progress indicators', negatable: false);

  // Try to get version from version file or pubspec.yaml
  VersionInfo.versionfind(parser, arguments);

  //  if (results['help'] as bool) {
  //     showHelp(parser);
  //     return;
  //   }
    

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error parsing arguments: $e');
    Healper.printUsage(parser);
    exit(1);
  }

  if (args['help']) {
    Healper.printUsage(parser);
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
  CodeAnalyzer.collectCodeEntities(
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
  UsageAnalyzer.findUsages(
      dir: projectDir,
      classes: classes,
      functions: functions,
      showProgress: showProgress,
      analyzeFunctions: analyzeFunctions);

  // Print analysis results to console
  ConsoleReporter.printResults(
      classes: classes,
      functions: functions,
      verbose: verbose,
      projectPath: projectPath,
      analyzeFunctions: analyzeFunctions,
      maxUnused: maxUnused);

  // Save analysis results to output file
  FileReporter.saveResultsToFile(
      classes: classes,
      functions: functions,
      outputDir: outputDir,
      projectPath: projectPath,
      analyzeFunctions: analyzeFunctions);

  // Perform cleanup if --clean flag is provided
  if (clean) {
    print('\nStarting cleanup of dead and commented-out classes...');
    DeadCodeCleaner.deadCodeCleaner(
      classes: classes,
      functions: functions,
      projectPath: projectPath,
      analyzeFunctions: analyzeFunctions,
    );
  }
}

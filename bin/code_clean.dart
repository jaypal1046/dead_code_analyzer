import 'dart:io';
import 'package:args/args.dart';
import 'package:code_clean/src/analyzers/code_collector.dart';
import 'package:code_clean/src/analyzers/usage_analyzer.dart';
import 'package:code_clean/src/model/code_info.dart';
import 'package:code_clean/src/reporters/console_reporter.dart';
import 'package:code_clean/src/reporters/file_reporter.dart';
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
    ..addFlag('help',
        abbr: 'h', help: 'Show usage information', negatable: false)
    ..addFlag('verbose',
        abbr: 'v', help: 'Show detailed output', negatable: false)
    ..addFlag('no-progress',
        help: 'Disable progress indicators', negatable: false);

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error parsing arguments: $e');
    _printUsage(parser);
    exit(1);
  }

  if (args['help']) {
    _printUsage(parser);
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

  if (verbose) {
    print('Collecting code entities...');
  }

  final classes = <String, CodeInfo>{};
  final functions = <String, CodeInfo>{};
  collectCodeEntities(
      projectDir, classes, functions, showProgress, analyzeFunctions);

  if (verbose) {
    print(
        '\nFound ${classes.length} classes${analyzeFunctions ? ' and ${functions.length} functions' : ''}.');
    print('Analyzing code references...');
  }

  findUsages(projectDir, classes, functions, showProgress, analyzeFunctions);
  printResults(classes, functions, verbose, projectPath, analyzeFunctions,
      maxUnused: maxUnused);
  saveResultsToFile(
      classes, functions, outputDir, projectPath, analyzeFunctions);
}

void _printUsage(ArgParser parser) {
  print('Usage: dart bin/code_clean.dart [options]');
  print(parser.usage);
  print('\nExample:');
  print(
      '  dart bin/code_clean.dart -p /path/to/flutter/project -o /path/to/save/report --analyze-functions --max-unused 20');
}

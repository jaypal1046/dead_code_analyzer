import 'dart:io';
import 'package:args/args.dart';
import 'package:dead_code_analyzer/dead_code_analyzer.dart';
import 'package:path/path.dart' as path;

/// Entry point for the dead code analyzer CLI tool
void main(List<String> arguments) async {
  final parser = _createArgParser();

  // Handle version display
  VersionInfo.findAndDisplayVersion(parser, arguments);

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    print('Error parsing arguments: $e');
    Helper.printUsage(parser);
    exit(1);
  }

  if (args['help'] as bool) {
    Helper.printUsage(parser);
    return;
  }

  final config = _createAnalysisConfig(args);

  if (!await _validateProjectDirectory(config.projectPath)) {
    exit(1);
  }

  await _runAnalysis(config);
}

/// Creates and configures the argument parser
ArgParser _createArgParser() {
  return ArgParser()
    ..addOption(
      'path',
      abbr: 'p',
      help: 'Path to the Flutter project to analyze',
      defaultsTo: '.',
    )
    ..addOption(
      'out',
      abbr: 'o',
      help: 'Directory to save the report file (default: Desktop)',
      defaultsTo: '',
    )
    ..addOption(
      'style',
      abbr: 's',
      help: 'Output format for the report (txt, html, md)',
      allowed: ['txt', 'html', 'md'],
      defaultsTo: 'txt',
    )
    ..addOption(
      'limit',
      abbr: 'l',
      help: 'Maximum number of unused entities to display in console',
      defaultsTo: '10',
    )
    ..addFlag(
      'funcs',
      abbr: 'f',
      help: 'Include function usage analysis',
      defaultsTo: false,
    )
    ..addFlag(
      'clean',
      abbr: 'c',
      help: 'Clean up files containing only dead or commented-out classes',
      negatable: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show usage information',
      negatable: false,
    )
    ..addFlag(
      'trace',
      abbr: 't',
      help: 'Show detailed execution trace',
      defaultsTo: false,
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      help: 'Disable progress indicators',
      negatable: false,
    );
}

/// Creates analysis configuration from parsed arguments
/// Creates analysis configuration from parsed arguments
AnalysisConfig _createAnalysisConfig(ArgResults args) {
  final projectPathStr = args['path'] as String;
  final projectPath = path.normalize(path.absolute(projectPathStr));

  String outputDir = args['out'] as String;
  if (outputDir.isEmpty) {
    outputDir = _getDefaultOutputDirectory();
  }

  // Parse the format option and convert to OutType enum
  final formatStr = args['style'] as String? ?? 'txt';

  final OutType outType = switch (formatStr) {
    'html' => OutType.html,
    'md' => OutType.md,
    'txt' => OutType.txt,
    _ => OutType.html,
  };

  return AnalysisConfig(
    projectPath: projectPath,
    outputDir: outputDir,
    maxUnusedEntities: int.parse(args['limit'] as String),
    includeFunctions: args['funcs'] as bool,
    shouldClean: args['clean'] as bool,
    showTrace: args['trace'] as bool,
    showProgress: !(args['quiet'] as bool),
    outType: outType, // Add this parameter
  );
}

/// Gets the default output directory (Desktop)
String _getDefaultOutputDirectory() {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  return path.join(home, 'Desktop');
}

/// Validates that the project directory exists
Future<bool> _validateProjectDirectory(String projectPath) async {
  final projectDir = Directory(projectPath);
  if (!await projectDir.exists()) {
    print('Error: Project directory not found at $projectPath');
    return false;
  }

  return true;
}

/// Runs the complete analysis process
Future<void> _runAnalysis(AnalysisConfig config) async {
  print('Analyzing Flutter project at: ${config.projectPath}');

  final projectDir = Directory(config.projectPath);
  final analysisResult = await _performCodeAnalysis(projectDir, config);

  await _generateReports(analysisResult, config);

  if (config.shouldClean) {
    await _performCleanup(analysisResult, config);
  }
}

/// Performs the code analysis and returns results
Future<AnalysisResult> _performCodeAnalysis(
  Directory projectDir,
  AnalysisConfig config,
) async {
  if (config.showTrace) {
    print('Collecting code entities...');
  }

  final classes = <String, ClassInfo>{};
  final functions = <String, CodeInfo>{};
  final exportList = <ImportInfo>[];

  // FIXED: Added await keyword here
  await CodeAnalyzer.collectCodeEntities(
    directory: projectDir,
    classes: classes,
    functions: functions,
    showProgress: config.showProgress,
    analyzeFunctions: config.includeFunctions,
    exportList: exportList,
  );

  if (config.showTrace) {
    final entitiesFound = config.includeFunctions
        ? '${classes.length} classes and ${functions.length} functions'
        : '${classes.length} classes';
    print('\nFound $entitiesFound.');
    print('Analyzing code references...');
  }

  // FIXED: Added await keyword here and handled the result
  await UsageAnalyzer.findUsages(
    directory: projectDir,
    classes: classes,
    functions: functions,
    showProgress: config.showProgress,
    analyzeFunctions: config.includeFunctions,
    exportList: exportList,
  );

  return AnalysisResult(classes: classes, functions: functions);
}

/// Generates console and file reports
Future<void> _generateReports(
  AnalysisResult result,
  AnalysisConfig config,
) async {
  // Print results to console
  ConsoleReporter.printResults(
    classes: result.classes,
    functions: result.functions,
    showTrace: config.showTrace,
    projectPath: config.projectPath,
    analyzeFunctions: config.includeFunctions,
    maxUnusedEntities: config.maxUnusedEntities,
  );

  // Save results to file
  FileReporter.saveResultsToFile(
    classes: result.classes,
    functions: result.functions,
    outputDirectory: config.outputDir,
    projectPath: config.projectPath,
    analyzeFunctions: config.includeFunctions,
    outType: config.outType, // Changed from hardcoded OutType.html
  );
}

/// Performs cleanup of dead code
Future<void> _performCleanup(
  AnalysisResult result,
  AnalysisConfig config,
) async {
  print('\nStarting cleanup of dead and commented-out classes...');

  await DeadCodeCleaner.performCleanup(
    classes: result.classes,
    functions: result.functions,
    projectPath: config.projectPath,
    analyzeFunctions: config.includeFunctions,
  );
}

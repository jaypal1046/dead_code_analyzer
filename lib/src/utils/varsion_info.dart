import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

void versionfind(ArgParser parser, List<String> arguments) {
  // Try to get version from version file or pubspec.yaml
  String version = 'unknown';
  String versionSource = 'none';

  // Check for version file first
  final versionFile = File(path.join(path.current, 'version'));
  if (versionFile.existsSync()) {
    version = versionFile.readAsStringSync().trim();
    versionSource = 'version file';
  } else {
    // Fallback to pubspec.yaml
    final pubspecFile = File(path.join(path.current, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      final lines = pubspecFile.readAsLinesSync();
      final versionLine = lines.firstWhere(
        (line) => line.trim().startsWith('version:'),
        orElse: () => '',
      );
      if (versionLine.isNotEmpty) {
        version = versionLine.split(':').last.trim();
        versionSource = 'pubspec.yaml';
      }
    }
  }

  parser.addFlag('version',
      abbr: 'V',
      help: 'Show the version of dead_code_analyzer',
      negatable: false);

  if (arguments.contains('--version') || arguments.contains('-V')) {
    print('dead_code_analyzer version $version (from $versionSource)');
    exit(0);
  }
}

[![Pub Version](https://img.shields.io/pub/v/dead_code_analyzer?logo=dart&logoColor=white)](https://pub.dev/packages/dead_code_analyzer)
[![License](https://img.shields.io/github/license/jaypal1046/dead_code_analyzer)](https://github.com/jaypal1046/dead_code_analyzer/blob/main/LICENSE)
[![Package Publisher](https://img.shields.io/pub/publisher/dead_code_analyzer)](https://pub.dev/packages/dead_code_analyzer/publisher)

# Dead Code Analyzer

Dead Code Analyzer is a command-line tool for Dart and Flutter projects that identifies unused code elements (classes, functions, variables) to streamline code cleanup and refactoring. Optimize your codebase, improve maintainability, and reduce technical debt with detailed analysis and actionable reports.

## Features

- Detects unused classes, functions, and variables.
- Tracks internal and external references for code elements.
- Generates detailed reports with recommendations for code removal.
- Displays interactive progress indicators during analysis.
- Supports custom exclusion patterns to skip specific files or directories.
- Experimental support for analyzing multiple projects and flavored `main` functions (e.g., `main_dev.dart`, `main_prod.dart`).
- Verbose mode for debugging reference counting issues.

**Note**: The current version uses a regex-based analysis, which may misreport references for classes with constructors. An AST-based approach is in development for improved accuracy (see [Limitations](#limitations)).

## How to Use

Take these steps to enable Dead Code Analyzer:

1. **Install the package as a dev dependency**:

   ```terminal
   dart pub add --dev dead_code_analyzer
   ```

   or, for Flutter projects:

   ```terminal
   flutter pub add --dev dead_code_analyzer
   ```

2. **Run the analyzer**:

   ```terminal
   # If installed globally
   dart pub global activate dead_code_analyzer
   ```

   ```terminal
   # Check version
   dead_code_analyzer --version
   ```

   ```terminal
   # Or run directly from source
   dart run bin/dead_code_analyzer.dart
   ```

   ```terminal
   # Analyze a specific project
   dead_code_analyzer -p /path/to/your/project
   ```

   ```terminal
   # Analyze with functions and verbose output
   dead_code_analyzer -p /path/to/flutter/project -o /path/to/save/report --analyze-functions --verbose
   ```

   ```terminal
   # Analyze multiple projects (monorepo)
   dead_code_analyzer -p /path/to/monorepo --analyze-functions --verbose
   ```

   ```terminal
   # Clean unused files
   dead_code_analyzer -p /path/to/project --clean --analyze-functions
   ```

## Command Line Options

```
Usage: dead_code_analyzer [options]

Options:
  -V, --version         Show version number
  -p, --project-path    Path to the project to analyze (default: current directory)
  -o, --output-dir      Directory to save the report file (default: Desktop)
  -v, --verbose         Show detailed output including all usage locations and debug logs
  -e, --exclude         Comma-separated patterns to exclude (e.g., "test,example,*.g.dart")
  --no-progress         Disable progress indicators
  --only-unused         Show only unused elements in the report
  --analyze-functions   Include function analysis (default: false)
  --clean               Remove unused files (use with caution)
  -h, --help            Show this help message
```

## Example Output

_Note: Timestamps, file paths, and counts are illustrative and will vary._

```
Dead Code Analysis - [Generated Timestamp]
==================================================

Unused Classes
------------------------------
 - Active (in lib/sdhf.dart, internal references: 0, external references: 0, total: 0)
 - StateFullClass (in lib/classwithfunct.dart, internal references: 0, external references: 0, total: 0)

Unused Functions
------------------------------
 - myFunction (in lib/classwithfunct.dart, internal references: 0, external references: 0, total: 0)

Summary
------------------------------
Total analyzed files: 32
Total classes: 15
Total functions: 42
Total variables: 128

Unused elements: 8 (4.2% of all code elements)
 - Unused classes: 4 (26.7%)
 - Unused functions: 3 (7.1%)
 - Unused variables: 1 (0.8%)

Full analysis saved to: [User Desktop]/dead_code_analysis_[timestamp].txt

Recommendations:
- Remove unused classes and functions listed above.
- Run with --verbose to debug reference counting issues.
- Use --clean to automatically remove unused files (backup your project first).
```

You can visualize the summary statistics with a pie chart by running the tool with a hypothetical `--chart` flag (not yet implemented) or manually generating one using the report data. For example, a pie chart of unused elements might show:

## Integration with CI/CD

Integrate Dead Code Analyzer into your CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
name: Dead Code Check

on:
  pull_request:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - name: Install dead_code_analyzer
        run: dart pub global activate dead_code_analyzer

      - name: Run dead code analysis
        run: dead_code_analyzer -p . --no-progress --only-unused --analyze-functions --verbose
```

## How It Works

The analyzer currently uses a regex-based approach to:

1. Scan all Dart files in the project.
2. Identify declarations of classes, functions, and variables.
3. Track references using regular expressions for internal (same file) and external (other files) usages.
4. Generate a report with unused elements and reference counts.

**Note**: An AST-based analyzer is in development to replace the regex approach, offering better accuracy for complex cases like constructor references.

## Best Practices

- Run with `--verbose` to debug reference counting issues (e.g., classes with constructors).
- Use `--exclude` to skip generated files (e.g., `*.g.dart`, `*.freezed.dart`).
- Analyze specific projects in a monorepo with `-p /path/to/project`.
- Backup your project before using `--clean`.
- Manually verify results before removing code.

## Supporting Multiple Projects and Flavored `main` Functions

- **Multiple Projects**: Run the analyzer on a monorepo root or specify project paths (e.g., `-p /path/to/app1`). Verbose logs include file paths to distinguish projects.
- **Flavored `main` Functions**: The tool detects `main_dev.dart`, `main_prod.dart`, etc., counting references as external usages. Use `--verbose` to see which files reference elements.
- **Debugging**: Add a custom `flavors.yaml` for explicit flavor mapping (see [Contributing](#contributing)).

## Known Limitations

- **Constructor Reference Counting**: Classes with constructors (e.g., `Active({ ... })`) may be incorrectly counted as having 1 internal reference due to regex limitations. Use `--verbose` to inspect debug logs and report issues.
- **Dynamic Code**: Reflection or dynamic invocations may lead to false positives.
- **Unreachable Code**: Not fully supported in the current regex-based version.
- **Complex Patterns**: Regex may miss callbacks or nested constructor calls.
- **Monorepo Support**: Limited isolation; run separately for each project if counts are conflated.

An AST-based version (in development) will address these issues by parsing the Dart AST for precise reference tracking.

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/fix-constructor-count`).
3. Commit your changes (`git commit -m 'Fix constructor reference counting'`).
4. Push to the branch (`git push origin feature/fix-constructor-count`).
5. Open a Pull Request.

To help with the constructor issue:

- Share debug logs from `--verbose` runs.
- Provide sample files (e.g., `sdhf.dart`) with problematic classes.
- Test the AST-based branch when available.

See our [contributing guidelines](CONTRIBUTING.md) for details.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

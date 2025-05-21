```
[![Pub Version](https://img.shields.io/pub/v/dead_code_analyzer?logo=dart&logoColor=white)](https://pub.dev/packages/dead_code_analyzer)
[![License](https://img.shields.io/github/license/jaypal1046/dead_code_analyzer)](https://github.com/jaypal1046/dead_code_analyzer/blob/main/LICENSE)
[![Package Publisher](https://img.shields.io/pub/publisher/dead_code_analyzer)](https://pub.dev/packages/dead_code_analyzer/publisher)

# Dead Code Analyzer

Dead Code Analyzer is a command-line tool for Dart and Flutter projects that identifies unused code elements (classes, functions, variables) and unreachable code segments to streamline code cleanup and refactoring. Optimize your codebase, improve maintainability, and reduce technical debt with comprehensive analysis and actionable reports.

## Features

- Detects unused classes, functions, and variables.
- Identifies unreachable code segments.
- Tracks usage frequency of code elements across the codebase.
- Analyzes internal and external references for accurate results.
- Generates detailed reports with recommendations for code removal.
- Displays interactive progress indicators during analysis.
- Supports custom exclusion patterns to skip specific files or directories.

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
   dead_code_analyzer

   # Or run directly from source
   dart run bin/dead_code_analyzer.dart

   # Analyze a specific project
   dead_code_analyzer -p /path/to/your/project
   ```

## Command Line Options

```
Usage: dead_code_analyzer [options]

Options:
  -p, --project-path    Path to the project to analyze (default: current directory)
  -o, --output-dir      Directory to save the report file (default: Desktop)
  -v, --verbose         Show detailed output including all usage locations
  -e, --exclude         Comma-separated patterns to exclude (e.g., "test,example")
  --no-progress         Disable progress indicators
  --only-unused         Show only unused elements in the report
  -h, --help            Show this help message
```

## Example Output

*Note: Timestamps and file paths are illustrative and will vary based on your system and analysis time.*

```
Dead Code Analysis - [Generated Timestamp]
==================================================

Unused Classes
------------------------------
 - MyUnusedClass (in lib/my_unused_class.dart)
 - OldService (in lib/services/old_service.dart)

Unused Functions
------------------------------
 - calculateLegacyTotal (in lib/utils/calculations.dart)
 - _validateOldFormat (in lib/validators.dart)

Unreachable Code
------------------------------
 - lib/screens/home_screen.dart:47 (code after return statement)
 - lib/utils/formatter.dart:102 (code in always-false conditional)

Summary
------------------------------
Total analyzed files: 78
Total classes: 45
Total functions: 126
Total variables: 384

Unused elements: 19 (3.4% of all code elements)
 - Unused classes: 7 (15.6%)
 - Unused functions: 9 (7.1%)
 - Unused variables: 3 (0.8%)
Unreachable code blocks: 5

Full analysis saved to: [User Desktop]/dead_code_analysis_[timestamp].txt

Recommendations:
- Consider removing the unused classes and functions listed above
- Review unreachable code segments
- Run with --verbose flag to see detailed usage information
```

Would you like a chart to visualize the summary statistics (e.g., unused elements breakdown)? If so, I can generate a pie chart showing the distribution of unused classes, functions, and variables.

## Integration with CI/CD

Integrate Dead Code Analyzer into your CI/CD pipeline to automatically detect dead code:

```yaml
# Example GitHub Actions workflow
name: Dead Code Check

on:
  pull_request:
    branches: [ main ]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      
      - name: Install dead_code_analyzer
        run: dart pub global activate dead_code_analyzer
        
      - name: Run dead code analysis
        run: dead_code_analyzer --no-progress --only-unused
```

## How It Works

The analyzer:

1. Scans all Dart files in your project.
2. Builds an Abstract Syntax Tree (AST) for precise analysis.
3. Identifies declarations of classes, functions, and variables.
4. Tracks references to each element across the codebase.
5. Detects unreachable code segments.
6. Generates a comprehensive report with actionable findings.

## Best Practices

- Run the tool regularly as part of your code cleanup process.
- Review all results before removing code to avoid unintended deletions.
- Use the `--exclude` option to ignore test files or generated code (e.g., `*.g.dart`).
- For large projects, consider analyzing specific directories to improve performance.

## Limitations

- May miss edge cases in complex code structures, such as macros or dynamic widget trees in Flutter.
- Dynamic code invocation or reflection may lead to false positives.
- Always manually verify results before modifying your codebase.

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'Add some amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

See our [contributing guidelines](CONTRIBUTING.md) for more details.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
```
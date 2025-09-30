[![Pub Version](https://img.shields.io/pub/v/dead_code_analyzer?logo=dart&logoColor=white)](https://pub.dev/packages/dead_code_analyzer)
[![License](https://img.shields.io/github/license/jaypal1046/dead_code_analyzer)](https://github.com/jaypal1046/dead_code_analyzer/blob/main/LICENSE)
[![Package Publisher](https://img.shields.io/pub/publisher/dead_code_analyzer)](https://pub.dev/packages/dead_code_analyzer/publisher)

# Dead Code Analyzer

Dead Code Analyzer is a command-line tool for Dart and Flutter projects that identifies unused code elements (classes, functions, variables) to streamline code cleanup and refactoring. Optimize your codebase, improve maintainability, and reduce technical debt with detailed analysis and actionable reports.

## Features

- **Comprehensive Code Detection**: Identifies unused classes, functions, and variables across your entire project
- **Smart Reference Tracking**: Tracks internal (same-file) and external (cross-file) references with export analysis
- **Multiple Report Formats**: Generate reports in TXT, HTML, or Markdown formats
- **Interactive Progress Indicators**: Real-time feedback during analysis (can be disabled with `--quiet`)
- **Configurable Output Limits**: Control console verbosity with customizable entity display limits
- **Automatic Cleanup**: Safely remove files containing only dead or commented-out code
- **Trace Mode**: Debug reference counting with detailed execution logs
- **Advanced Class Analysis**: Detects and categorizes mixins, enums, extensions, state classes, @pragma classes, and typedefs

**Note**: The current version uses a regex-based analysis, which may misreport references for classes with constructors. An AST-based approach is in development for improved accuracy (see [Limitations](#limitations)).

## Installation

### As a Dev Dependency

For Dart projects:
```terminal
dart pub add --dev dead_code_analyzer
```

For Flutter projects:
```terminal
flutter pub add --dev dead_code_analyzer
```

### Global Installation

```terminal
dart pub global activate dead_code_analyzer
```

Verify installation:
```terminal
dead_code_analyzer --version
```

## Quick Start

```terminal
# Analyze current directory
dead_code_analyzer

# Analyze specific project
dead_code_analyzer -p /path/to/your/project

# Full analysis with functions and HTML report
dead_code_analyzer -p /path/to/project -o ./reports --funcs -s html

# Clean unused files (always backup first!)
dead_code_analyzer -p /path/to/project --clean --funcs
```

## Command Line Options

```
Usage: dead_code_analyzer [options]

Options:
  -V, --version         Show version number
  -p, --path            Path to the project to analyze (default: current directory)
  -o, --out             Directory to save the report file (default: Desktop)
  -s, --style           Output format: txt, html, or md (default: txt)
  -l, --limit           Maximum unused entities to display in console (default: 10)
  -f, --funcs           Include function usage analysis (default: false)
  -c, --clean           Clean up files with only dead/commented code
  -t, --trace           Show detailed execution trace for debugging
  -q, --quiet           Disable progress indicators (useful for CI/CD)
  -h, --help            Show this help message
```

## Report Formats

### Text Format (Default)
Simple, readable text output perfect for quick reviews:
```terminal
dead_code_analyzer -p . -s txt
```

### HTML Format
Rich, interactive reports with styling and better navigation:
```terminal
dead_code_analyzer -p . -s html -o ./reports
```

### Markdown Format
Documentation-friendly format that integrates with docs:
```terminal
dead_code_analyzer -p . -s md -o ./docs
```

## Comprehensive Class Analysis

The analyzer provides detailed categorization of all Dart class types:

### Class Categories Analyzed

- **Unused Classes**: Classes with zero internal and external references
- **Commented Classes**: Classes that are commented out in code
- **Classes Used Only Internally**: Referenced only within the same file
- **Classes Used Only Externally**: Referenced only from other files
- **Classes Used Both Internally and Externally**: Mixed usage patterns
- **Mixin Classes**: Dart mixins and their usage tracking
- **Enum Classes**: Enumerations and their reference counting
- **Extension Classes**: Extension methods and their usage
- **State Classes**: StatefulWidget state classes and lifecycle tracking
- **@pragma Classes**: Entry-point classes marked with @pragma annotations
- **Typedef Classes**: Type aliases and custom type definitions

## Example Output

```
Analyzing Flutter project at: /path/to/your/project

Dead Code Analysis - [Generated Timestamp]
==================================================

Unused Classes
------------------------------
 - Active (in lib/sdhf.dart, internal: 0, external: 0, total: 0)
 - StateFullClass (in lib/classwithfunct.dart, internal: 0, external: 0, total: 0)

Unused Functions
------------------------------
 - myFunction (in lib/classwithfunct.dart, internal: 0, external: 0, total: 0)

Summary
------------------------------
Total analyzed files: 32
Total classes: 15
Total functions: 42

Unused elements: 5 (3.5% of all code elements)
 - Unused classes: 2 (13.3%)
 - Unused functions: 3 (7.1%)

Full analysis saved to: [Desktop]/dead_code_analysis_[timestamp].txt

Recommendations:
- Remove unused classes and functions listed above
- Verify @pragma-annotated classes before deletion (may be used by native code)
- Run with --trace to debug reference counting issues
- Use --clean to automatically remove unused files (backup first!)
```

## Advanced Usage

### Debugging Reference Counts

Use trace mode to understand how references are counted:
```terminal
dead_code_analyzer -p . --trace --funcs
```

This shows:
- Files being analyzed
- Entities discovered in each file
- Reference matches found
- Export chain resolution

### Limiting Console Output

For large projects, limit console noise:
```terminal
# Show only top 5 unused entities
dead_code_analyzer -p . --funcs --limit 5

# Or run quietly for CI/CD
dead_code_analyzer -p . --quiet --funcs
```

### Safe Cleanup Workflow

Always backup before cleaning:
```terminal
# 1. Commit current state
git add .
git commit -m "Pre-cleanup checkpoint"

# 2. Run cleanup
dead_code_analyzer -p . --clean --funcs

# 3. Review changes
git diff

# 4. Test thoroughly before committing
flutter test  # or dart test
```

## Integration with CI/CD

### GitHub Actions

```yaml
name: Dead Code Analysis

on:
  pull_request:
    branches: [main, develop]
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Dart
        uses: dart-lang/setup-dart@v1
      
      - name: Install Dependencies
        run: dart pub get
      
      - name: Install Dead Code Analyzer
        run: dart pub global activate dead_code_analyzer
      
      - name: Run Analysis
        run: dead_code_analyzer -p . --quiet --funcs --limit 20 -s md -o ./reports
      
      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: dead-code-report
          path: ./reports/*.md
```

### GitLab CI

```yaml
dead_code_analysis:
  stage: test
  image: dart:stable
  script:
    - dart pub global activate dead_code_analyzer
    - dead_code_analyzer -p . --quiet --funcs -s html -o ./reports
  artifacts:
    paths:
      - reports/
    expire_in: 30 days
```

## How It Works

The analyzer performs a multi-phase analysis:

1. **Entity Collection Phase**
   - Scans all Dart files in the project
   - Identifies declarations (classes, functions, variables)
   - Categorizes special class types (mixins, enums, extensions, etc.)
   - Builds export dependency graph

2. **Usage Analysis Phase**
   - Searches for references using optimized regex patterns
   - Distinguishes internal vs. external references
   - Tracks export chains to resolve transitive usage
   - Handles special cases (@pragma annotations, state classes)

3. **Report Generation Phase**
   - Aggregates usage statistics
   - Categorizes unused vs. used elements
   - Generates reports in selected format (TXT/HTML/MD)
   - Provides actionable recommendations

4. **Cleanup Phase (Optional)**
   - Identifies files with only dead/commented code
   - Creates backups (recommended: use git)
   - Safely removes qualifying files

**Note**: An AST-based analyzer is in development to replace regex for better accuracy with constructors and complex patterns.

## Best Practices

### Analysis Best Practices
- **Start Small**: Run on a single module before analyzing the entire project
- **Use Trace Mode**: Enable `--trace` when investigating unexpected results
- **Version Control**: Always commit before running `--clean`
- **Regular Analysis**: Integrate into CI/CD for continuous monitoring
- **Set Realistic Limits**: Use `--limit` to focus on top offenders first

### Cleanup Best Practices
- **Backup First**: Use git or create a branch before cleanup
- **Test After**: Run your test suite after cleanup
- **Incremental Approach**: Clean a few files at a time
- **Manual Verification**: Review auto-cleaned files before committing
- **Team Communication**: Notify team members before large-scale cleanups

### CI/CD Best Practices
- **Use `--quiet`**: Reduce log noise in pipelines
- **Generate HTML Reports**: Better for artifact storage and review
- **Set Thresholds**: Fail builds if dead code exceeds acceptable limits
- **Archive Reports**: Store as build artifacts for tracking trends

## Supporting Multiple Projects and Flavored Apps

### Monorepo Support
Run the analyzer on multiple projects:
```terminal
# Analyze individual projects
dead_code_analyzer -p ./packages/app1 -o ./reports/app1
dead_code_analyzer -p ./packages/app2 -o ./reports/app2

# Or analyze from root (limited isolation)
dead_code_analyzer -p . --trace
```

### Flavored Main Functions
The tool automatically detects flavor entry points:
- `main_dev.dart`, `main_staging.dart`, `main_prod.dart`
- References from these files count as external usage
- Use `--trace` to see which flavors reference specific code

```terminal
# Analyze project with multiple flavors
dead_code_analyzer -p . --funcs --trace
```

## Known Limitations

### Current Limitations
- **Constructor References**: Classes with constructors (e.g., `Active({...})`) may show incorrect internal reference counts due to regex matching the class name in constructor parameters
- **Dynamic Code**: Reflection, `dart:mirrors`, or dynamic invocations may cause false positives
- **String References**: Classes referenced only in strings (e.g., JSON serialization) may be marked as unused
- **Complex Patterns**: Nested callbacks and complex constructor chains might be missed
- **Generated Code**: `*.g.dart` and `*.freezed.dart` files need careful handling
- **Monorepo Isolation**: Limited cross-project boundary detection

### Workarounds
- Use `--trace` to inspect reference counts and understand false positives
- Manually verify results before removing code
- Add `// ignore: dead_code` comments for known false positives
- Exclude generated files from analysis (feature in development)

### Future Improvements
An AST-based version is in development that will:
- Parse the full Dart abstract syntax tree
- Accurately track constructor and method references
- Handle complex language features (mixins, extensions, etc.)
- Provide better support for generated code
- Offer fix suggestions and automated refactoring

## Contributing

We welcome contributions! Here's how to get started:

### Quick Contribution Guide

1. **Fork and Clone**
   ```terminal
   git clone https://github.com/YOUR_USERNAME/dead_code_analyzer.git
   cd dead_code_analyzer
   ```

2. **Create Feature Branch**
   ```terminal
   git checkout -b feature/your-feature-name
   ```

3. **Make Changes and Test**
   ```terminal
   dart test
   dart run bin/dead_code_analyzer.dart -p ./example_project --trace
   ```

4. **Submit Pull Request**
   ```terminal
   git commit -m "feat: add your feature description"
   git push origin feature/your-feature-name
   ```

### Areas for Contribution
- **AST Parser**: Help build the AST-based analyzer
- **Constructor Tracking**: Improve constructor reference detection
- **New Report Formats**: Add JSON, CSV, or custom formats
- **Exclusion Patterns**: Implement file/folder exclusion rules
- **Test Coverage**: Add tests for edge cases
- **Documentation**: Improve examples and guides

### Reporting Issues
When reporting bugs, please include:
- Dead Code Analyzer version (`dead_code_analyzer --version`)
- Dart/Flutter SDK version
- Sample code that reproduces the issue
- Output from `--trace` mode
- Expected vs. actual behavior

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Support

- 📦 [Package on pub.dev](https://pub.dev/packages/dead_code_analyzer)
- 🐛 [Issue Tracker](https://github.com/jaypal1046/dead_code_analyzer/issues)
- 💬 [Discussions](https://github.com/jaypal1046/dead_code_analyzer/discussions)
- 📧 Contact: [Publisher on pub.dev](https://pub.dev/packages/dead_code_analyzer/publisher)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history and breaking changes.
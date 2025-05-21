```
# Dead Code Analyzer (v0.1.0)

A command-line tool to analyze Dart and Flutter projects, identifying unused code elements (classes, functions, variables) and unreachable code to streamline code cleaning and refactoring. Optimize your codebase by removing dead code, improving maintainability, and reducing technical debt.

## Features

- Identifies unused classes, functions, and variables
- Detects unreachable code segments
- Tracks usage frequency of code elements
- Analyzes both internal and external references
- Generates comprehensive reports with recommendations
- Shows analysis progress with interactive indicators
- Supports custom exclusion patterns

## Installation

### From pub.dev

```bash
# Install globally
dart pub global activate dead_code_analyzer

# Or add to your project's dev_dependencies
dart pub add --dev dead_code_analyzer
```

### From Source

1. Clone this repository (replace `yourusername` with the actual repository owner):
   ```bash
   git clone https://github.com/yourusername/dead_code_analyzer.git
   cd dead_code_analyzer
   ```

2. Install dependencies:
   ```bash
   dart pub get
   ```

3. Activate locally:
   ```bash
   dart pub global activate --source path .
   ```

## Usage

### Basic Usage

```bash
# If installed globally
dead_code_analyzer

# Or run directly from source
dart run bin/dead_code_analyzer.dart

# Analyze a specific project
dead_code_analyzer -p /path/to/your/project
```

### Command Line Options

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

### Example Output

*Note: Timestamps and file paths in the output are illustrative and will vary based on your system and analysis time.*

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

## Integration with CI/CD

You can integrate this tool into your CI/CD pipeline to identify dead code automatically:

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

1. Scans all Dart files in your project
2. Builds an AST (Abstract Syntax Tree) for accurate analysis
3. Identifies declarations of classes, functions, and variables
4. Tracks references to each element across the codebase
5. Identifies unreachable code segments
6. Generates a comprehensive report with findings

## Best Practices

- Run this tool regularly as part of your code cleanup process
- Review all results before removing code
- Use the `--exclude` option to ignore test files or generated code
- For large projects, consider analyzing specific directories separately

## Limitations

- May miss edge cases in complex code structures, such as code within macros or highly dynamic widget trees in Flutter.
- Dynamic code invocation or reflection usage might cause false positives.
- Always manually verify results before making changes to your codebase.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License
This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
```
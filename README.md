# Flutter Class Analyzer

A command-line tool to analyze Flutter projects and identify unused or dead classes to help with code cleaning and refactoring.

## Features

- Identifies all Dart classes in a Flutter project
- Tracks how many times each class is used and where
- Highlights potentially dead or unused classes
- Shows progress as it analyzes (for large projects)
- Provides recommendations for code cleanup

## Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/yourusername/flutter_class_analyzer.git
   cd flutter_class_analyzer
   ```

2. Install dependencies:
   ```bash
   dart pub get
   ```

## Usage

### Basic Usage

```bash
# Analyze the current directory (if it's a Flutter project)
dart run bin/flutter_class_analyzer.dart

# Analyze a specific Flutter project
dart run bin/flutter_class_analyzer.dart -p /path/to/your/flutter/project
```

### Command Line Options

- `-p, --project-path`: Path to the Flutter project to analyze (default: current directory)
- `-o, --output-dir`: Directory to save the report file (default: Desktop)
- `-v, --verbose`: Show detailed output including all usage locations
- `--no-progress`: Disable progress indicators
- `-h, --help`: Show usage information

### Example Output

```
Analyzing Flutter project at: /path/to/your/flutter/project
Scanning files for classes: [====================================] 120/120 (100%)
Analyzing class usage: [====================================] 120/120 (100%)

Summary:
Total classes: 45
Unused classes: 7 (15.6%)
Rarely used classes (1-2 usages): 12
Frequently used classes (>10 usages): 5

Potentially dead classes:
 - UnusedWidget (defined in unused_widget.dart)
 - OldService (defined in services.dart)
 - DeprecatedModel (defined in models.dart)
 - TestScreen (defined in test_screen.dart)
 - MockData (defined in mock_data.dart)

Full analysis saved to: /Users/yourname/Desktop/flutter_class_analysis_2025-05-20_14-30-25.txt

Recommendations:
- Consider removing the unused classes listed above
- Review rarely used classes to determine if they can be consolidated

Tip: Run with --verbose flag to see detailed usage information.
```

### Report File Format

The tool creates a detailed report file on your Desktop (or specified directory) that includes:

1. **Unused Classes Section** - Lists all classes with 0 usages
2. **Rarely Used Classes Section** - Lists classes with only 1-2 usages
3. **Complete Class Usage List** - All classes with their usage counts
4. **Summary Statistics** - Overview of the analysis results

Example report entry:

```
 - PdfComboBox (defined in pdf_combo_box.dart, called 0 times)
 - FetchHomeRenewalResponse (defined in fetchhomerenewalresponse.dart, called 2 times)
```

## Why Use This Tool?

- **Cleaner Codebase**: Identify and remove unused code
- **Faster Builds**: Reducing code can lead to faster compilation
- **Better Maintainability**: Less code means less to maintain
- **Smaller App Size**: Remove dead code to reduce final app size

## How It Works

The tool:

1. Scans all `.dart` files in your Flutter project
2. Identifies class definitions using regex patterns
3. Searches for references to each class across the codebase
4. Calculates usage statistics and identifies potential dead code

## Notes

- The tool uses basic regex pattern matching to identify classes and usages
- It may not catch all edge cases in complex code structures
- Always review results before removing code
- This tool is most effective as part of your regular code cleanup process

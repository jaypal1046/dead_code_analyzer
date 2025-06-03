# Changelog

All notable changes to the **Dead Code Analyzer** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
## 1.0.12
- function used fix
## 1.0.11
- fix class used issue
## 1.0.10
- improve the logic of the regex to find the usage of the class
## 1.0.9
- fix bug in the regex
## 1.0.8
- revart change and improve logic of usage find

## 1.0.7
- file naming changes to match the pub dev file naming structure.
## 1.0.6
- Updated `README.md` to reflect the current regex-based implementation of Dead Code Analyzer.
- Clarified that the tool uses regex for reference counting.
- Added known limitation for constructor reference counting (e.g., classes like `Active` may show incorrect `internal references: 1`).
- Included instructions for using `--verbose` to debug reference issues.
- Added support for multiple projects and flavored `main` functions in usage examples and best practices.
- Introduced a sample pie chart for visualizing unused elements breakdown.
- Updated example output to include `Active`, `StateFullClass`, and `myFunction` from recent fixes.
- Attempted fix for constructor reference counting in `usage_analyzer.dart` by updating `constructorDefRegex` for multi-line named parameters and adding a fallback regex in `_filterNonCommentMatches`. 
## 1.0.5
- Fix the comment function not found and added test case for comment function handling 

## 1.0.4
- Fix the class comment not found and added test case for class handling 

## 1.0.3 

- updated README.md

## 1.0.2

- Added support for excluding specific Dart SDK versions in analysis to avoid false positives with experimental features like macros.
- Improved error messages for dependency conflicts, providing clearer guidance on resolving `analyzer` and `macros` issues.
- Added `--version` flag to display the tool’s version in the CLI.
- Fixed dependency conflict with `freezed >=2.5.3` by updating `analyzer` to `^6.9.0`, ensuring compatibility with `macros >=0.1.3-main.0`.
- Updated `pubspec.yaml` to require Dart SDK `>=3.3.0 <4.0.0` with `enable-experiments: macros`.
- Improved documentation in `README.md` to clarify publishing status for Pub badges.

## 1.0.1

- Fixed Pub Version and Package Publisher badges in `README.md` by ensuring correct package name and version on `pub.dev`.
- Added missing `LICENSE` file to repository, enabling License badge to display “BSD-3-Clause”.
- Fixed typo in CLI help message for `--exclude` option description.

## 1.0.0

- Initial release of Dead Code Analyzer.
- Added core features:
  - Detection of unused classes, functions, and variables in Dart and Flutter projects.
  - Identification of unreachable code segments.
  - Usage frequency tracking for code elements.
  - Analysis of internal and external references.
  - Comprehensive report generation with recommendations in text format.
  - Interactive progress indicators during analysis.
  - Support for custom exclusion patterns via `--exclude` option.
- Added command-line interface with options:
  - `-p, --project-path`: Specify project directory (default: current directory).
  - `-o, --output-dir`: Set report output directory (default: Desktop).
  - `-v, --verbose`: Show detailed output with usage locations.
  - `-e, --exclude`: Comma-separated patterns to exclude (e.g., "test,example").
  - `--no-progress`: Disable progress indicators.
  - `--only-unused`: Show only unused elements in the report.
  - `-h, --help`: Display help message.
- Added installation support via `pub.dev` or source code.
- Added CI/CD integration example for GitHub Actions.
- Added documentation for usage, best practices, limitations, and contributing guidelines.
- Licensed under the BSD 3-Clause License.

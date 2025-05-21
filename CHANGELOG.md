## 1.0.0 - 2023-05-21

# Changelog

All notable changes to the **Dead Code Analyzer** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
##[1.0.1] - 2023-05-21
### Added
- Fix dependencies import issue
- Improve README.md file

## [1.0.0] - 2023-05-21
### Added
--no-progress flag to disable progress indicators
## [0.1.1] - 2023-05-21
### Added
- Improve README.md file

## [0.1.0] - 2025-05-21

### Added
- Initial release of Dead Code Analyzer.
- Core features:
  - Detection of unused classes, functions, and variables in Dart and Flutter projects.
  - Identification of unreachable code segments.
  - Usage frequency tracking for code elements.
  - Analysis of internal and external references.
  - Comprehensive report generation with recommendations in text format.
  - Interactive progress indicators during analysis.
  - Support for custom exclusion patterns via `--exclude` option.
- Command-line interface with options:
  - `-p, --project-path`: Specify project directory (default: current directory).
  - `-o, --output-dir`: Set report output directory (default: Desktop).
  - `-v, --verbose`: Show detailed output with usage locations.
  - `-e, --exclude`: Comma-separated patterns to exclude (e.g., "test,example").
  - `--no-progress`: Disable progress indicators.
  - `--only-unused`: Show only unused elements in the report.
  - `-h, --help`: Display help message.
- Installation support via `pub.dev` or source code.
- CI/CD integration example for GitHub Actions.
- Documentation for usage, best practices, limitations, and contributing guidelines.
- Licensed under the BSD 3-Clause License.

### Changed
- N/A (Initial release).

### Fixed
- N/A (Initial release).
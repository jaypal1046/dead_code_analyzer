# Contributing to Dead Code Analyzer

Thank you for your interest in contributing to Dead Code Analyzer, a CLI tool for identifying unused code in Flutter and Dart projects! We welcome contributions from the community to improve functionality, documentation, and usability. This document outlines how to contribute effectively.

## Table of Contents
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Contributing Code](#contributing-code)
- [Getting Started](#getting-started)
- [Pull Request Process](#pull-request-process)
- [Code Style and Conventions](#code-style-and-conventions)
- [Community and Communication](#community-and-communication)
- [Code of Conduct](#code-of-conduct)

## How Can I Contribute?

### Reporting Bugs
If you find a bug, please help us by reporting it:
- Check the [GitHub Issues](https://github.com/jaypal1046/dead_code_analyzer/issues) page to ensure the bug hasn’t been reported.
- Open a new issue with a clear title and description, including:
  - Steps to reproduce the bug.
  - Expected behavior.
  - Actual behavior.
  - Environment details (e.g., Dart version, OS, Flutter version).
  - Screenshots or logs, if applicable.
- Use the `bug` label when creating the issue.

### Suggesting Enhancements
We welcome ideas to improve the tool, such as new features or optimizations:
- Open a GitHub issue with the `enhancement` label.
- Describe the proposed feature, why it’s useful, and any implementation ideas.
- If you plan to work on it, mention this in the issue to avoid duplicate efforts.

### Contributing Code
You can contribute code to fix bugs, add features, or improve documentation:
- Fork the repository and create a feature branch (e.g., `feature/add-new-analysis` or `fix/bug-description`).
- Follow the [Pull Request Process](#pull-request-process).
- Ensure your code adheres to the [Code Style and Conventions](#code-style-and-conventions).
- Contributions are licensed under the BSD 3-Clause License (see `LICENSE`).

## Getting Started
1. **Fork the Repository**: Click the "Fork" button on the [repository page](https://github.com/jaypal1046/dead_code_analyzer).
2. **Clone Your Fork**:
   ```bash
   git clone git@github.com:jaypal1046/dead_code_analyzer.git
   cd dead_code_analyzer
   ```
3. **Set Up the Upstream Remote**:
   ```bash
   git remote add upstream https://github.com/jaypal1046/dead_code_analyzer.git
   ```
4. **Install Dependencies**:
   Ensure Dart and Flutter are installed, then run:
   ```bash
   dart pub get
   ```
5. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
6. **Test Your Changes**:
   - Run the analyzer on a sample Flutter project:
     ```bash
     dart bin/dead_code_analyzer.dart -p /path/to/sample/flutter/project --analyze-functions --verbose
     ```
   - Add or update tests in the `test` directory if applicable.
7. **Commit Changes**:
   Use clear commit messages (e.g., `Add support for analyzing abstract classes`).
   ```bash
   git add .
   git commit -m "Your descriptive commit message"
   ```

## Pull Request Process
1. **Sync with Upstream**:
   Ensure your fork is up-to-date:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```
   Resolve any merge conflicts.
2. **Push to Your Fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
3. **Open a Pull Request**:
   - Go to the repository on GitHub and click "Compare & pull request."
   - Provide a clear title and description, linking to related issues (e.g., `Fixes #123`).
   - Mark as a "Draft" PR if it’s a work in progress.
4. **Address Feedback**:
   - Respond to code review comments promptly.
   - Make additional commits to address feedback and push to the same branch.
5. **CI Checks**:
   Ensure any CI checks (if configured) pass. Fix failures if they occur.
6. **Merging**:
   Once approved, the maintainer will merge your PR. Discuss backporting if needed.

## Code Style and Conventions
- Follow Dart’s [style guide](https://dart.dev/guides/language/effective-dart/style).
- Use `dart format` to format code:
  ```bash
  dart format .
  ```
- Write clear, self-documenting code with comments for complex logic.
- Avoid whitespace errors; run `git diff --check` before committing.
- Update documentation (e.g., `README.md` or this file) if your changes affect usage.
- If adding features, consider updating the CLI’s help text in `dead_code_analyzer.dart`.

## Community and Communication
- Join discussions in GitHub Issues or contact the maintainer via [insert preferred contact method, e.g., email or Discord].
- Be respectful and constructive in all interactions.
- For major changes, open an issue first to discuss with the community.

## Code of Conduct
We are committed to fostering an inclusive community. Please adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Report unacceptable behavior to [maintainer’s contact info].
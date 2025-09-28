import 'dart:io';
import 'dart:math';

/// A utility class for displaying a progress bar in a command-line interface.
///
/// The [ProgressBar] class provides a customizable progress bar that updates
/// dynamically based on the current progress relative to a total value. It is
/// designed for use in CLI tools, such as the `dead_code_analyzer` package, to
/// show progress during long-running operations like file analysis.
///
/// Example usage:
/// ```dart
/// final progress = ProgressBar(100, description: 'Analyzing files', width: 50);
/// for (var i = 0; i < 100; i++) {
///   progress.increment();
///   // Simulate work
///   await Future.delayed(Duration(milliseconds: 50));
/// }
/// progress.done();
/// ```
/// A class to display a progress bar in the console.
class ProgressBar {
  /// The total number of units to complete.
  final int total;

  /// The width of the progress bar in characters.
  final int width;

  /// A description of the task being performed.
  final String description;

  /// The current progress value.
  int _current = 0;

  /// Whether the progress bar has been marked as complete.
  bool _isDone = false;

  /// Creates a progress bar with the specified [total] units.
  ///
  /// [total] must be a positive integer representing the total units of work.
  /// [width] is the character width of the bar (default: 40).
  /// [description] is a label for the task (default: 'Processing').
  ///
  /// Throws an [ArgumentError] if [total] is not positive or [width] is not positive.
  ProgressBar(this.total, {this.width = 40, this.description = 'Processing'}) {
    if (total <= 0) {
      throw ArgumentError.value(total, 'total', 'Must be positive');
    }
    if (width <= 0) {
      throw ArgumentError.value(width, 'width', 'Must be positive');
    }
  }

  /// Updates the progress bar to the specified [current] value.
  ///
  /// [current] is the current progress, clamped to [0, total].
  void update(int current) {
    if (_isDone) return;
    _current = min(max(0, current), total);
    _draw();
  }

  /// Increments the progress bar by one unit.
  void increment() => update(_current + 1);

  /// Marks the progress bar as complete and finalizes the display.
  ///
  /// This method ensures the bar shows 100% completion and adds a newline.
  /// It can only be called once; subsequent calls are ignored.
  void done() {
    if (_isDone) return;
    _current = total;
    _draw();
    stdout.writeln();
    _isDone = true;
  }

  /// Draws the progress bar to the console.
  void _draw() {
    final ratio = _current / total;
    final percentage = (ratio * 100).toInt();
    final completedWidth = (width * ratio).floor();

    final bar = StringBuffer()
      ..write('[')
      ..write('=' * completedWidth)
      ..write(completedWidth < width ? '>' : '')
      ..write(' ' * (width - completedWidth - (completedWidth < width ? 1 : 0)))
      ..write(']');

    final progressText = '$_current/$total ($percentage%)';
    stdout.write('\r$description: $bar $progressText');
  }
}

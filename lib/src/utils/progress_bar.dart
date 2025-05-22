import 'dart:io';
import 'dart:math';

/// Progress bar display class
class ProgressBar {
  final int total;
  final int width;
  final String description;
  int _current = 0;
  bool _done = false;

  ProgressBar(this.total, {this.width = 40, this.description = 'Processing'});

  void update(int current) {
    _current = min(current, total);
    _draw();
  }

  void increment() {
    update(_current + 1);
  }

  void done() {
    if (!_done) {
      _current = total;
      _draw();
      stdout.writeln();
      _done = true;
    }
  }

  void _draw() {
    if (total <= 0) return;

    final ratio = _current / total;
    final percentage = (ratio * 100).toInt();
    final completedWidth = (width * ratio).floor();

    final bar =
        '[${'=' * completedWidth}${completedWidth < width ? '>' : ''}${' ' * (width - completedWidth - (completedWidth < width ? 1 : 0))}]';

    final progressText = '$_current/$total ($percentage%)';
    final line = '\r$description: $bar $progressText';

    stdout.write(line);
  }
}

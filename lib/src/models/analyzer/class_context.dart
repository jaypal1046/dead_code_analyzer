/// Manages the current class context during code analysis.
///
/// Tracks the current class being analyzed, nesting depth,
/// and whether we're inside a Flutter State class.
class ClassContext {
  /// Stack of class information for handling nested classes.
  final List<_ClassInfo> _classStack = [];

  /// Current nesting depth within braces.
  int depth = 0;

  /// Whether currently inside a Flutter State class.
  bool insideStateClass = false;

  /// Returns true if currently inside any class.
  bool get isInsideClass => _classStack.isNotEmpty;

  /// Returns the name of the current class, or empty string if none.
  String get currentClassName =>
      _classStack.isNotEmpty ? _classStack.last.name : '';

  /// Returns the type of the current class, or empty string if none.
  String get currentType => _classStack.isNotEmpty ? _classStack.last.type : '';

  /// Enters a new class context.
  ///
  /// [className]: Name of the class being entered
  /// [type]: Type of the entity (class, enum, extension, mixin)
  void enterClass(String className, String type) {
    _classStack.add(_ClassInfo(name: className, type: type));
    depth = 1; // Reset depth for new class
  }

  /// Exits the current class context.
  void exitClass() {
    if (_classStack.isNotEmpty) {
      _classStack.removeLast();
    }

    // Reset depth appropriately
    if (_classStack.isNotEmpty) {
      depth = 1; // Still inside parent class
    } else {
      depth = 0; // Outside all classes
    }
  }

  /// Updates the current nesting depth.
  ///
  /// [change]: The change in depth (positive for opening braces, negative for closing)
  void updateDepth(int change) {
    depth += change;
  }

  /// Sets whether currently inside a State class.
  void setInsideStateClass(bool value) {
    insideStateClass = value;
  }
}


/// Information about a class in the context stack.
class _ClassInfo {
  /// The name of the class.
  final String name;

  /// The type of the entity (class, enum, extension, mixin).
  final String type;

  const _ClassInfo({
    required this.name,
    required this.type,
  });
}
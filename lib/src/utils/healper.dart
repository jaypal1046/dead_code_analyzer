import 'dart:io';

import 'package:args/args.dart';
import 'package:dead_code_analyzer/src/model/code_info.dart';

List<File> getDartFiles(Directory dir) {
  return dir
      .listSync(recursive: true)
      .where((entity) =>
          entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.contains('/.dart_tool/') &&
          !entity.path.contains('/build/'))
      .cast<File>()
      .toList();
}

void printUsage(ArgParser parser) {
  print('Usage: dart bin/dead_code_analyzer.dart [options]');
  print(parser.usage);
  print('\nExample:');
  print(
      '  dart bin/dead_code_analyzer.dart -p /path/to/flutter/project -o /path/to/save/report --analyze-functions --max-unused 20');
}

// Helper function to check if a line is commented out
bool isLineCommented(String line) {
  String trimmed = line.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('/*') && trimmed.endsWith('*/') ||
      isInsideBlockComment(trimmed);
}

// Helper function to check if function is inside block comment
bool isInsideBlockComment(String line) {
  // Simplified check for single-line block comments
  return line.contains('/*') && line.contains('*/');
}

// Helper function to determine if a specific function match is commented
bool isFunctionInCommented(
    String line, RegExpMatch match, List<String> lines, int lineIndex) {
  // Check if the function declaration itself starts with //
  String beforeFunction = line.substring(0, match.start);
  String functionPart = line.substring(match.start);

  // Check if there's a // before the function on the same line
  if (beforeFunction.trim().endsWith('//') ||
      functionPart.trim().startsWith('//')) {
    return true;
  }

  // Check if the entire line is commented
  if (isLineCommented(line)) {
    return true;
  }

  // Check for multi-line comment scenarios
  return isInMultiLineComment(lines, lineIndex, match.start);
}

// Helper function to check if a position is inside a multi-line comment
bool isInMultiLineComment(List<String> lines, int lineIndex, int charPosition) {
  bool insideComment = false;

  // Iterate through lines up to the current line
  for (int i = 0; i <= lineIndex; i++) {
    String lineToCheck = lines[i];
    int endPos = (i == lineIndex) ? charPosition : lineToCheck.length;

    int pos = 0;
    while (pos < endPos - 1) {
      // Skip single-line comments
      if (pos < lineToCheck.length - 1 &&
          lineToCheck[pos] == '/' &&
          lineToCheck[pos + 1] == '/') {
        break; // Ignore rest of the line
      }

      // Check for start of multi-line comment
      if (!insideComment &&
          pos < lineToCheck.length - 1 &&
          lineToCheck[pos] == '/' &&
          lineToCheck[pos + 1] == '*') {
        insideComment = true;
        pos += 2;
      }
      // Check for end of multi-line comment
      else if (insideComment &&
          pos < lineToCheck.length - 1 &&
          lineToCheck[pos] == '*' &&
          lineToCheck[pos + 1] == '/') {
        insideComment = false;
        pos += 2;
      } else {
        pos++;
      }
    }
  }

  return insideComment;
}

// Helper function to check if function is a constructor
bool isConstructor(String functionName, String line) {
  RegExp constructorPattern = RegExp(r'^\s*(?://\s*)?[A-Z]\w*(?:\.\w+)?\s*\(');
  return constructorPattern.hasMatch(line.trim()) &&
      functionName[0].toUpperCase() == functionName[0];
}

// Helper function to clean up commented function names
String getCleanFunctionName(String functionKey) {
  if (functionKey.contains('_commented_')) {
    return functionKey.split('_commented_')[0];
  }
  return functionKey;
}

// Helper function to get all commented functions
Map<String, CodeInfo> getCommentedFunctions(Map<String, CodeInfo> functions) {
  return Map.fromEntries(
      functions.entries.where((entry) => entry.value.commentedOut));
}

// Helper function to get all active (non-commented) functions
Map<String, CodeInfo> getActiveFunctions(Map<String, CodeInfo> functions) {
  return Map.fromEntries(
      functions.entries.where((entry) => !entry.value.commentedOut));
}

String sanitizeFilePath(String filePath) {
  //todo: This function can be customized based on your needs

  // Replace slashes, dots, and other invalid characters with underscores
  // return filePath.startsWith('lib')
  //     ? filePath.substring(4).replaceAll(RegExp(r'[\/\\.]'), '_')
  //     : filePath.replaceAll(RegExp(r'[\/\\.]'), '_');
  return filePath.substring(4);
}

// Expanded list of prebuilt Flutter and framework methods
final Set<String> prebuiltFlutterMethods = {
  'toString',
  'onWillPop',
  'if',
  'for',
  'while',
  'switch',
  'try',
  'catch',
  'finally',
  'main',
  'runApp',
  'runZoned',
  'super',
  'InkWell',
  // Widget Lifecycle
  'build',
  'createElement',
  'debugFillProperties',
  'canUpdate',
  'updateChild',
  'inflateWidget',
  'deactivateChild',
  'debugGetCreatorChain',
  'toStringShallow',
  'toStringDeep',
  'toDiagnosticsNode',

  // StatefulWidget Lifecycle
  'createState',
  'initState',
  'didChangeDependencies',
  'didUpdateWidget',
  'reassemble',
  'setState',
  'deactivate',
  'dispose',
  'activate',
  'mounted',

  // StatelessWidget
  'createRenderObject',
  'updateRenderObject',
  'didUnmountRenderObject',

  // InheritedWidget
  'updateShouldNotify',
  'inheritFromWidgetOfExactType',
  'dependOnInheritedWidgetOfExactType',
  'dependOnInheritedElement',
  'getElementForInheritedWidgetOfExactType',

  // Object Lifecycle (Dart)
  'toStringShort',
  'hashCode',
  'runtimeType',
  'noSuchMethod',
  '==',

  // RenderObject Methods
  'performLayout',
  'performResize',
  'paint',
  'hitTest',
  'hitTestSelf',
  'hitTestChildren',
  'applyPaintTransform',
  'getTransformTo',
  'getDistanceToActualBaseline',
  'computeMinIntrinsicWidth',
  'computeMaxIntrinsicWidth',
  'computeMinIntrinsicHeight',
  'computeMaxIntrinsicHeight',
  'performCommit',
  'adoptChild',
  'dropChild',
  'visitChildren',
  'redepthChildren',
  'attach',
  'detach',
  'owner',
  'depth',
  'constraints',
  'size',
  'hasSize',
  'parentData',
  'parent',
  'markNeedsLayout',
  'markNeedsLayoutForSizedByParentChange',
  'markNeedsPaint',
  'markNeedsCompositingBitsUpdate',
  'markNeedsSemanticsUpdate',
  'scheduleInitialPaint',
  'scheduleInitialLayout',
  'scheduleInitialSemantics',
  'replaceRootLayer',
  'showOnScreen',
  'describeSemanticsConfiguration',
  'assembleSemanticsNode',
  'clearSemantics',

  // Animation Methods
  'addListener',
  'removeListener',
  'addStatusListener',
  'removeStatusListener',
  'forward',
  'reverse',
  'reset',
  'stop',
  'repeat',
  'drive',
  'animateWith',
  'value',
  'status',
  'isCompleted',
  'isDismissed',
  'isAnimating',
  'velocity',

  // StreamController Methods
  'onListen',
  'onPause',
  'onResume',
  'onCancel',
  'add',
  'addError',
  'close',
  'stream',
  'sink',
  'hasListener',
  'isPaused',
  'isClosed',

  // Future Methods
  'then',
  'catchError',
  'whenComplete',
  'timeout',
  'asStream',

  // Stream Methods
  'listen',
  'where',
  'map',
  'asyncMap',
  'asyncExpand',
  'handleError',
  'expand',
  'pipe',
  'transform',
  'reduce',
  'fold',
  'join',
  'contains',
  'forEach',
  'every',
  'any',
  'length',
  'isEmpty',
  'isBroadcast',
  'asBroadcastStream',
  'skip',
  'skipWhile',
  'take',
  'takeWhile',
  'toList',
  'toSet',
  'drain',
  'cast',
  'retype',
  'first',
  'last',
  'single',
  'firstWhere',
  'lastWhere',
  'singleWhere',
  'elementAt',
  'distinct',

  // Serialization Methods
  'toJson',
  'fromJson',
  'toMap',
  'fromMap',
  'copyWith',

  // List/Collection Methods
  'addAll',
  'insert',
  'insertAll',
  'remove',
  'removeAt',
  'removeLast',
  'removeWhere',
  'retainWhere',
  'clear',
  'sort',
  'shuffle',
  'indexOf',
  'lastIndexOf',
  'isNotEmpty',
  'reversed',
  'iterator',
  'asMap',
  'getRange',
  'setRange',
  'removeRange',
  'fillRange',
  'replaceRange',
  'setAll',
  'sublist',

  // Map Methods
  'putIfAbsent',
  'update',
  'updateAll',
  'addEntries',
  'containsKey',
  'containsValue',
  'keys',
  'values',
  'entries',

  // Set Methods
  'union',
  'intersection',
  'difference',
  'lookup',

  // Navigator Methods
  'push',
  'pop',
  'pushReplacement',
  'pushAndRemoveUntil',
  'replace',
  'replaceRouteBelow',
  'canPop',
  'maybePop',
  'popUntil',
  'removeRoute',
  'removeRouteBelow',
  'popAndPushNamed',
  'pushNamed',
  'pushReplacementNamed',
  'pushNamedAndRemoveUntil',
  'restorablePush',
  'restorablePushNamed',
  'restorablePushReplacement',
  'restorablePushReplacementNamed',
  'restorablePushAndRemoveUntil',
  'restorablePushNamedAndRemoveUntil',

  // MediaQuery Methods
  'of',
  'maybeOf',
  'fromView',
  'fromWindow',
  'removePadding',
  'removeViewInsets',
  'removeViewPadding',
  'textScaleFactorOf',
  'platformBrightnessOf',
  'highContrastOf',
  'disableAnimationsOf',
  'accessibleNavigationOf',
  'invertColorsOf',
  'reduceMotionOf',
  'videoPlaybackControlsOf',

  // Scaffold Methods
  'hasDrawer',
  'hasEndDrawer',
  'hasFloatingActionButton',
  'isDrawerOpen',
  'isEndDrawerOpen',
  'openDrawer',
  'openEndDrawer',
  'showBottomSheet',
  'showSnackBar',
  'hideCurrentSnackBar',
  'removeCurrentSnackBar',
  'showBodyScrim',
  'hideBodyScrim',

  // Form Methods
  'save',
  'validate',

  // FormField Methods
  'didChange',
  'setValue',

  // Focus Methods
  'requestFocus',
  'unfocus',
  'consumeKeyboardToken',
  'hasFocus',
  'hasPrimaryFocus',
  'canRequestFocus',
  'descendantsAreFocusable',
  'descendantsAreTraversable',
  'skipTraversal',
  'reparent',
  'setFirstFocus',
  'setLastFocus',
  'invalidateScopeData',
  'traversalDescendants',
  'inDirection',
  'findFirstFocusInDirection',
  'sortDescendants',

  // Overlay Methods
  'rearrange',

  // PageController Methods
  'animateToPage',
  'nextPage',
  'previousPage',
  'jumpToPage',
  'animateTo',
  'jumpTo',
  'createScrollPosition',
  'debugFillDescription',

  // ScrollController Methods
  'hasClients',
  'position',
  'positions',
  'offset',
  'initialScrollOffset',
  'keepScrollOffset',
  'debugLabel',

  // TabController Methods
  'indexIsChanging',
  'index',
  'previousIndex',
  'animation',

  // TextEditingController Methods
  'notifyListeners',
  'clearComposing',
  'isSelectionWithinTextBounds',
  'buildTextSpan',
  'text',
  'selection',

  // ValueNotifier Methods
  'hasListeners',

  // GlobalKey Methods
  'currentState',
  'currentContext',
  'currentWidget',

  // BuildContext Methods
  'findAncestorWidgetOfExactType',
  'findAncestorStateOfType',
  'findRootAncestorStateOfType',
  'findAncestorRenderObjectOfType',
  'visitAncestorElements',
  'visitChildElements',
  'findRenderObject',
  'widget',
  'debugDoingBuild',

  // Element Methods
  'mount',
  'updateSlotForChild',
  'attachRenderObject',
  'detachRenderObject',
  'unmount',
  'inheritFromElement',
  'updateDependencies',
  'performRebuild',
  'markNeedsBuild',
  'rebuild',
  'debugVisitOnstageChildren',
  'debugDescribeChildren',

  // Ticker Methods
  'start',
  'scheduled',
  'shouldScheduleTick',
  'unscheduleTick',

  // GestureDetector callback methods
  'onTap',
  'onTapDown',
  'onTapUp',
  'onTapCancel',
  'onSecondaryTap',
  'onSecondaryTapDown',
  'onSecondaryTapUp',
  'onSecondaryTapCancel',
  'onTertiaryTapDown',
  'onTertiaryTapUp',
  'onTertiaryTapCancel',
  'onDoubleTap',
  'onDoubleTapDown',
  'onDoubleTapCancel',
  'onLongPress',
  'onLongPressStart',
  'onLongPressMoveUpdate',
  'onLongPressUp',
  'onLongPressEnd',
  'onSecondaryLongPress',
  'onSecondaryLongPressStart',
  'onSecondaryLongPressMoveUpdate',
  'onSecondaryLongPressUp',
  'onSecondaryLongPressEnd',
  'onVerticalDragDown',
  'onVerticalDragStart',
  'onVerticalDragUpdate',
  'onVerticalDragEnd',
  'onVerticalDragCancel',
  'onHorizontalDragDown',
  'onHorizontalDragStart',
  'onHorizontalDragUpdate',
  'onHorizontalDragEnd',
  'onHorizontalDragCancel',
  'onPanDown',
  'onPanStart',
  'onPanUpdate',
  'onPanEnd',
  'onPanCancel',
  'onScaleStart',
  'onScaleUpdate',
  'onScaleEnd',

  // Common Widget Properties/Methods (callback style)
  'onPressed',
  'onHover',
  'onFocusChange',
  'onChanged',
  'onSubmitted',
  'onEditingComplete',
  'onSaved',
  'validator',
  'builder',
  'itemBuilder',
  'separatorBuilder',
  'itemCount',
  'itemExtent',
  'prototypeItem',
  'addAutomaticKeepAlives',
  'addRepaintBoundaries',
  'addSemanticIndexes',
  'cacheExtent',
  'controller',
  'dragStartBehavior',
  'keyboardDismissBehavior',
  'physics',
  'primary',
  'restorationId',
  'scrollDirection',
  'semanticChildCount',
  'shrinkWrap',
  'clipBehavior',

  // AppLifecycleState methods
  'didChangeAppLifecycleState',
  'didHaveMemoryPressure',
  'didChangeLocales',
  'didChangeTextScaleFactor',
  'didChangePlatformBrightness',
  'didChangeAccessibilityFeatures',

  // WidgetsBindingObserver methods
  'didChangeMetrics',
  'didRequestAppExit',
  'didPopRoute',
  'didPushRoute',
  'didPushRouteInformation',

  // Hero methods
  'createRectTween',
  'flightShuttleBuilder',
  'placeholderBuilder',
  'transitionOnUserGestures',

  // PageRoute methods
  'buildPage',
  'buildTransitions',
  'canTransitionFrom',
  'canTransitionTo',

  // Common Dart methods that might be overridden
  'compareTo',
  'call',

  // Diagnostics methods

  // Custom painter methods
  'shouldRepaint',
  'shouldRebuildSemantics',
  'semanticsBuilder',

  // Sliver methods
  'childMainAxisPosition',
  'childCrossAxisPosition',
  'childScrollOffset',
  'calculatePaintOffset',
  'calculateCacheOffset',
  'childExistingScrollOffset',
  'updateOutOfBandData',
  'updateParentData',

  // Platform channel methods
  'invokeMethod',
  'invokeListMethod',
  'invokeMapMethod',
  'setMethodCallHandler',

  // Error handling
  'onError',
};

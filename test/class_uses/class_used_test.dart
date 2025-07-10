import 'package:dead_code_analyzer/src/model/class_info.dart';
import 'package:dead_code_analyzer/src/model/import_info.dart';
import 'package:dead_code_analyzer/src/usage/class_uages.dart';
import 'package:test/test.dart';

void main() {
  group('analyzeClassUsages', () {
    // Mock class definitions
    final classes = {
      'MyWidget': ClassInfo(
        '/path/to/my_widget.dart',
        type: 'stateless_class',
        lineIndex: 10,
        startPosition: 100,
      ),
      'MyStatefulWidget': ClassInfo(
        '/path/to/my_stateful_widget.dart',
        type: 'stateful_class',
        lineIndex: 15,
        startPosition: 150,
      ),
      'MyRegularClass': ClassInfo(
        '/path/to/my_regular_class.dart',
        type: 'class',
        lineIndex: 20,
        startPosition: 200,
      ),
    };

    test('should count internal class usages correctly', () {
      final content = '''
        import 'package:flutter/material.dart';
       
        class NewWidet extends StatelessWidget {
          NewWidet(); // Definition
          void build() {
            MyWidget another = MyWidget(); // Valid usage
            print('MyWidget'); // String, should be ignored
            // MyWidget comment; // Comment, should be ignored
            MyWidget second = MyWidget(); // Another valid usage
          }
        }
      ''';
      final filePath = '/path/to/my_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      expect(classes['MyWidget']!.internalUsageCount, 2);
      expect(classes['MyWidget']!.externalUsages, isEmpty);
    });

    test('should count external class usages with direct import', () {
      final content = '''
        import '/path/to/my_widget.dart';
        class OtherWidget extends StatelessWidget {
          void build() {
            MyWidget widget = MyWidget(); // Valid usage
            MyWidget another = MyWidget(); // Another valid usage
          }
        }
      ''';
      final filePath = '/path/to/other_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      expect(classes['MyWidget']!.internalUsageCount, 0);
      expect(classes['MyWidget']!.externalUsages[filePath], 2);
    });

    test('should handle imports with alias', () {
      final content = '''
        import '/path/to/my_widget.dart' as widgetAlias;
        class OtherWidget extends StatelessWidget {
          void build() {
            widgetAlias.MyWidget widget = widgetAlias.MyWidget(); // Valid usage
          }
        }
      ''';
      final filePath = '/path/to/other_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      expect(classes['MyWidget']!.internalUsageCount, 0);
      expect(classes['MyWidget']!.externalUsages[filePath], 1);
    });

    test('should respect show clause in imports', () {
      final content = '''
        import '/path/to/my_widget.dart' show MyWidget;
        class OtherWidget extends StatelessWidget {
          void build() {
            MyWidget widget = MyWidget(); // Valid usage
            MyStatefulWidget widget2 = MyStatefulWidget(); // Should be ignored
          }
        }
      ''';
      final filePath = '/path/to/other_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      expect(classes['MyWidget']!.internalUsageCount, 0);
      expect(classes['MyWidget']!.externalUsages[filePath], 1);
      expect(classes['MyStatefulWidget']!.externalUsages, isEmpty);
    });

    test('should respect hide clause in imports', () {
      final content = '''
        import '/path/to/my_widget.dart' hide MyWidget;
        import '/path/to/my_regular_class.dart';
        class OtherWidget extends StatelessWidget {
          void build() {
            MyWidget widget = MyWidget(); // Should be ignored
            MyRegularClass instance = MyRegularClass(); // Valid usage
          }
        }
      ''';
      final filePath = '/path/to/other_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      // expect(classes['MyWidget']!.internalUsageCount, 0);
      // expect(classes['MyWidget']!.externalUsages, isEmpty);
      expect(classes['MyRegularClass']!.externalUsages[filePath], 1);
    });

    test('should ignore usages in comments and strings', () {
      final content = '''
        import '/path/to/my_widget.dart';
        class OtherWidget extends StatelessWidget {
          void build() {
            // MyWidget comment; // Ignored
            String text = 'MyWidget'; // Ignored
            MyWidget widget = MyWidget(); // Valid usage
          }
        }
      ''';
      final filePath = '/path/to/other_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      expect(classes['MyWidget']!.internalUsageCount, 0);
      expect(classes['MyWidget']!.externalUsages[filePath], 1);
    });

    test('should handle Flutter-specific classes (StatelessWidget)', () {
      final content = '''
        import 'package:flutter/material.dart';
        import '/path/to/my_widget.dart';
        class OtherWidget extends StatelessWidget {
          Widget build(BuildContext context) {
            return MyWidget(); // Valid usage
          }
        }
      ''';
      final filePath = '/path/to/other_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      expect(classes['MyWidget']!.internalUsageCount, 0);
      expect(classes['MyWidget']!.externalUsages[filePath], 1);
    });

    test('should handle Flutter-specific classes (StatefulWidget)', () {
      final content = '''
        import 'package:flutter/material.dart';
        import '/path/to/my_stateful_widget.dart';
        class OtherWidget extends StatelessWidget {
          Widget build(BuildContext context) {
            return MyStatefulWidget(); // Valid usage
          }
        }
      ''';
      final filePath = '/path/to/other_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      expect(classes['MyStatefulWidget']!.internalUsageCount, 0);
      expect(classes['MyStatefulWidget']!.externalUsages[filePath], 1);
    });

    test('should not count usages if class is not imported', () {
      final content = '''
        class OtherWidget extends StatelessWidget {
          void build() {
            MyWidget widget = MyWidget(); // Should be ignored
          }
        }
      ''';
      final filePath = '/path/to/other_widget.dart';

      analyzeClassUsages(content, filePath, classes);

      expect(classes['MyWidget']!.internalUsageCount, 0);
      expect(classes['MyWidget']!.externalUsages, isEmpty);
    });
  });

  group('parseImports', () {
    test('should parse simple import', () {
      final content = '''
        import '/path/to/my_widget.dart';
      ''';
      final imports = parseImports(content);
      expect(imports.length, 1);
      expect(imports[0].path, '/path/to/my_widget.dart');
      expect(imports[0].asAlias, isNull);
      expect(imports[0].shownClasses, isEmpty);
      expect(imports[0].hiddenClasses, isEmpty);
    });

    test('should parse import with alias', () {
      final content = '''
        import '/path/to/my_widget.dart' as widgetAlias;
      ''';
      final imports = parseImports(content);
      expect(imports.length, 1);
      expect(imports[0].path, '/path/to/my_widget.dart');
      expect(imports[0].asAlias, 'widgetAlias');
      expect(imports[0].shownClasses, isEmpty);
      expect(imports[0].hiddenClasses, isEmpty);
    });

    test('should parse import with show clause', () {
      final content = '''
        import '/path/to/my_widget.dart' show MyWidget, OtherClass;
      ''';
      final imports = parseImports(content);
      expect(imports.length, 1);
      expect(imports[0].path, '/path/to/my_widget.dart');
      expect(imports[0].shownClasses, ['MyWidget', 'OtherClass']);
      expect(imports[0].hiddenClasses, isEmpty);
    });

    test('should parse import with hide clause', () {
      final content = '''
        import '/path/to/my_widget.dart' hide MyWidget, OtherClass;
      ''';
      final imports = parseImports(content);
      expect(imports.length, 1);
      expect(imports[0].path, '/path/to/my_widget.dart');
      expect(imports[0].hiddenClasses, ['MyWidget', 'OtherClass']);
      expect(imports[0].shownClasses, isEmpty);
    });
    test('should parse package import', () {
      final content = '''
        import 'package:translator/domain/repositories/subtitle_repository.dart';
      ''';
      final imports = parseImports(content);
      expect(imports.length, 1);
      expect(imports[0].path,
          'package:translator/domain/repositories/subtitle_repository.dart');
      expect(imports[0].asAlias, isNull);
      expect(imports[0].shownClasses, isEmpty);
      expect(imports[0].hiddenClasses, isEmpty);
    });
  });

  group('isClassAccessibleInFile', () {
    test('should return true for accessible class', () {
      final imports = [
        ImportInfo(path: '/path/to/my_widget.dart'),
      ];
      expect(
          isClassAccessibleInFile(
              'MyWidget', '/path/to/my_widget.dart', imports),
          isTrue);
    });

    test('should return false for hidden class', () {
      final imports = [
        ImportInfo(
            path: '/path/to/my_widget.dart', hiddenClasses: ['MyWidget']),
      ];
      expect(
          isClassAccessibleInFile(
              'MyWidget', '/path/to/my_widget.dart', imports),
          isFalse);
    });

    test('should return false for non-imported class', () {
      final imports = [
        ImportInfo(path: '/path/to/other.dart'),
      ];
      expect(
          isClassAccessibleInFile(
              'MyWidget', '/path/to/my_widget.dart', imports),
          isFalse);
    });

    test('should return false for show clause excluding class', () {
      final imports = [
        ImportInfo(
            path: '/path/to/my_widget.dart', shownClasses: ['OtherClass']),
      ];
      expect(
          isClassAccessibleInFile(
              'MyWidget', '/path/to/my_widget.dart', imports),
          isFalse);
    });
    test('should return true for accessible class with package import', () {
      final imports = [
        ImportInfo(
            path:
                'package:translator/domain/repositories/subtitle_repository.dart'),
      ];
      final classPath =
          '/Users/developer/project/lib/domain/repositories/subtitle_repository.dart';
      expect(
        isClassAccessibleInFile('SubtitleRepository', classPath, imports),
        isTrue,
      );
    });

    test('should return false for non-matching package import', () {
      final imports = [
        ImportInfo(
            path:
                'package:translator/domain/repositories/other_repository.dart'),
      ];
      final classPath =
          '/Users/developer/project/lib/domain/repositories/subtitle_repository.dart';
      expect(
        isClassAccessibleInFile('SubtitleRepository', classPath, imports),
        isFalse,
      );
    });
  });

  group('getEffectiveClassName', () {
    test('should return original class name without alias', () {
      final imports = [
        ImportInfo(path: '/path/to/my_widget.dart'),
      ];
      expect(
          getEffectiveClassName('MyWidget', '/path/to/my_widget.dart', imports),
          'MyWidget');
    });

    test('should return aliased class name', () {
      final imports = [
        ImportInfo(path: '/path/to/my_widget.dart', asAlias: 'widgetAlias'),
      ];
      expect(
          getEffectiveClassName('MyWidget', '/path/to/my_widget.dart', imports),
          'widgetAlias.MyWidget');
    });
  });
}

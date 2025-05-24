// text_function_file1.dart
const String functionTestFile1 = '''
class TestClass {
    /* void commentedFunction() {},
void commentedFunction1() {},
void commentedFunction2() {},*/
    void activeFunction() {},
    @pragma('vm:entry-point')
    void entryPointFunction() {},
}
''';

// text_function_file2.dart
const String functionTestFile2 = '''
class TestClass {
    /* void commentedFunction() {},
void commentedFunction1() {},
void commentedFunction2() {},*/
    void activeFunction() {},
    @pragma('vm:entry-point')
    void entryPointFunction() {},
}
''';

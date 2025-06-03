// text_function_file.dart
const String functionTestFile = '''
class TestClass extends State<MyWidget> {
    /* void commentedFunction() {},
void commentedFunction1() {},
void commentedFunction2() {},*/
    void activeFunction() {},
    @pragma('vm:entry-point')
    void entryPointFunction() {},
    void emptyFunction();
    TestClass._privateConstructor() {}
}
''';

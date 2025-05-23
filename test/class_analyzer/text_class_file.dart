final ckassTestFile = '''
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
 
  // class CommentedOutClass {
  //   void commentedOutFunction() {
  //     // This function is commented out
  //   }
  //}
  class MyHomePage extends StatefulWidget {
    const MyHomePage({super.key, required this.title});
    final String title;

    @override
    State<MyHomePage> createState() => _MyHomePageState();
  }

  class _MyHomePageState extends State<MyHomePage> {
    int _counter = 0;

    void _incrementCounter() {
      setState(() {
        _counter++;
      });
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Text('You have pushed the button \$_counter times'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _incrementCounter,
          child: Icon(Icons.add),
        ),
      );
    }
  }
  /* class CommentedClass { 
  void commentedFunction() {
    // This function is commented out
  }
  }*/
''';

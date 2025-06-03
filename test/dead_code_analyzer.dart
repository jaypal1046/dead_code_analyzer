import 'dart:io';
import 'class_analyzer/class_analyzer.dart';
import 'function_analyzer/multi_file_function_analyzer.dart';
import 'function_analyzer/sigle_file_function_analyzer.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print("Please specify a test to run: class or function");
    exit(1);
  }

  switch (args[0]) {
    case 'class':
      classAnalyzerTest();
      break;
    case 'function':
      functionAnalyzerTest();
      break;
    case 'multifilefunction':
      multifilefunctionAnalyzerTest();
      break;
    default:
      print("Unknown test: ${args[0]}");
  }
}

// File: lib/test_functions.dart
// This file contains various function types to test the analyzer

// Top-level function that is used
void usedTopLevelFunction() {
  print('This function is used');
}

// Top-level function that is unused (dead code)
void unusedTopLevelFunction() {
  print('This function is never called');
}

// Class with various method types
abstract class TestBaseClass {
  // Abstract method
  void abstractMethod();
  
  // Regular method that will be overridden
  void overridableMethod() {
    print('Base implementation');
  }
}

class TestClass extends TestBaseClass {
  // Static method that is used
  static void usedStaticMethod() {
    print('This static method is used');
  }
  
  // Static method that is never called (dead code)
  static void unusedStaticMethod() {
    print('This static method is never called');
  }
  
  // Instance method that is used
  void usedInstanceMethod() {
    print('This instance method is used');
  }
  
  // Instance method that is never called (dead code)
  void unusedInstanceMethod() {
    print('This instance method is never called');
  }
  
  // Implementation of abstract method
  @override
  void abstractMethod() {
    print('Implementation of abstract method');
  }
  
  // Override of parent method
  @override
  void overridableMethod() {
    print('Overridden implementation');
  }
}

void main() {
  // Call the used top-level function
  usedTopLevelFunction();
  
  // Create an instance of TestClass
  final testInstance = TestClass();
  
  // Call the used instance method
  testInstance.usedInstanceMethod();
  
  // Call the used static method
  TestClass.usedStaticMethod();
  
  // Call the abstract method implementation
  testInstance.abstractMethod();
  
  // Call the overridden method
  testInstance.overridableMethod();
  
  // Use an anonymous function (closure)
  closure() {
    print('This is an anonymous function');
  }
  closure();
  
  // Use a local function
  void localFunction() {
    print('This is a local function');
  }
  localFunction();
}
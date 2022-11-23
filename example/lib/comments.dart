import 'package:flutter/material.dart';

/// This is TestA
class TestA {
  /// This is A i
  int i = 1;
  void greet(String name) {
    /* Assume we have a valid name. */
    // ignore: avoid_print
    print('Hi, $name!');
  }
}

/* This is TestB */
class TestB {
  /* This is B i */
  int i = 1;
}

// This is TestC
class TestC {
  // This is C i
  int i = 1;
}

/**
 * This is TestD
 *
 *
 *
 *  */
class TestD {
  /* This is D i */
  int i = 1;
}

int i = 1;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key, required this.s}) : super(key: key);
  final int s;
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  int i = 0;
  int _j = 0;
  int get j => _j;
  set j(int value) {
    if (_j != value) {
      _j = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

enum Enum {
  test,
  test1,
}

class Test with MixinTest {
  @override
  String get a => '1';

  @override
  void test() {}
}

mixin MixinTest {
  String get a;

  void test();
}

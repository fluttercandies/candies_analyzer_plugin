// ignore_for_file: perfer_candies_class_prefix, perfer_doc_comments, avoid_print
import 'package:flutter/material.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void dispose() {
    super.dispose();
    print('ddd');
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class MyWidget1 extends StatefulWidget {
  const MyWidget1({Key? key}) : super(key: key);

  @override
  State<MyWidget1> createState() => _MyWidget1State();
}

class _MyWidget1State extends State<MyWidget1> {
  @override
  void dispose() {
    super.dispose();
    print('ddd');
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class MyWidget2 extends StatefulWidget {
  const MyWidget2({Key? key}) : super(key: key);

  @override
  State<MyWidget2> createState() => _MyWidget2State();
}

class _MyWidget2State extends State<MyWidget2> {
  @override
  void dispose() {
    print('ddd');
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class MyWidget3 extends StatefulWidget {
  const MyWidget3({Key? key}) : super(key: key);

  @override
  State<MyWidget3> createState() => _MyWidget3State();
}

class _MyWidget3State extends State<MyWidget3> {
  @override
  void dispose() {
    print('ddd');
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

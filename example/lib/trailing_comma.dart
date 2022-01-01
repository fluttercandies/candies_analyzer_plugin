// ignore_for_file: unused_field,perfer_doc_comments,perfer_candies_class_prefix

import 'package:flutter/material.dart';

class MyWidget extends StatefulWidget {
  const MyWidget(
      {Key? key,
      required this.value,
      required this.value1,
      required this.value2})
      : super(key: key);

  final String value;
  final String value1;
  final String value2;
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final List<String> _list = <String>[
    '1',
    '2',
    '3',
    '1000000000000000000',
    'dadadjakl'
  ];

  final Set<String> _set = <String>{
    '1',
    '2',
    '3',
    '1000000000000000000',
    'dadadjakl'
  };

  final Map<String, String> _map = <String, String>{
    '1': '1',
    '2': '2',
    '3': '3',
    '1000000000000000000': '1000000000000000000',
    'dadadjakl': 'dadadjakl'
  };
  @override
  void initState() {
    super.initState();
    // ignore: unused_local_variable
    Test test = Test('dadafsfsff', 'dadafsfsdfdfsd', 'sdadfdfsfsfasd',
        'dadfdfdfsfsda', 'dadadadasfd', 'dafefgfdadasdad');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.red, border: Border.all(color: Colors.red))),
    );
  }
}

class Test {
  Test(this.value, this.value1, this.value2, this.value3, this.value4,
      this.value5);
  final String value;
  final String value1;
  final String value2;
  final String value3;
  final String value4;
  final String value5;
}

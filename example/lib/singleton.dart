import 'package:flutter/foundation.dart';

class Singleton {
  factory Singleton() => _singleton;
  Singleton._();
  static final Singleton _singleton = Singleton._();
  void printInfo() {
    if (kDebugMode) {
      print('object');
    }
  }

  int get num => 1;
}

class Singleton1 {
  const Singleton1();
  void printInfo() {
    if (kDebugMode) {
      print('object');
    }
  }

  int get num => 1;
}

// class Singleton1 {
//   Singleton1._();
//   static final Singleton1 _singleton1 = Singleton1._();
//   static Singleton1 get instance => _singleton1;
//   void printInfo() {
//     if (kDebugMode) {
//       print('object');
//     }
//   }
// }

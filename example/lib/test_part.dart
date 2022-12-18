part of 'test.dart';

extension TestE on Test {
  void printInfo(String info) {
    if (kDebugMode) {
      print(info);
    }
  }
}

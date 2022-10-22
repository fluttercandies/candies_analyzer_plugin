import 'dart:isolate';
import 'package:analyzer_plugin/starter.dart';
import 'plugin.dart';

class CandiesLintsStarter {
  CandiesLintsStarter._();
  static void start(
    List<String> args,
    SendPort sendPort, {
    CandiesLintsPlugin? plugin,
  }) {
    ServerPluginStarter(
      plugin ?? CandiesLintsPlugin(),
    ).start(sendPort);
  }
}

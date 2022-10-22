import 'dart:isolate';
import 'package:analyzer_plugin/starter.dart';
import 'plugin.dart';

/// An object that can be used to start an analysis server plugin. This class
/// exists so that clients can configure a plugin before starting it.
class CandiesLintsStarter {
  CandiesLintsStarter._();

  /// Establish the channel used to communicate with the server and start the
  /// plugin.
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

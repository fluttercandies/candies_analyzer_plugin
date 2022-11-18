import 'dart:isolate';
import 'package:analyzer_plugin/starter.dart';
import 'package:candies_analyzer_plugin/src/plugin.dart';

/// An object that can be used to start an analysis server plugin. This class
/// exists so that clients can configure a plugin before starting it.
class CandiesAnalyzerPluginStarter {
  CandiesAnalyzerPluginStarter._();

  /// Establish the channel used to communicate with the server and start the
  /// plugin.
  static void start(
    List<String> args,
    SendPort sendPort, {
    CandiesAnalyzerPlugin? plugin,
  }) {
    ServerPluginStarter(
      plugin ?? CandiesAnalyzerPlugin(),
    ).start(sendPort);
  }
}

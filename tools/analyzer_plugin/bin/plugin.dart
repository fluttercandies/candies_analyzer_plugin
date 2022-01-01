import 'dart:isolate';

import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';

// This file must be 'plugin.dart'
void main(List<String> args, SendPort sendPort) {
  // for performance, default is false, if you want to check log, set it to true.
  CandiesAnalyzerPluginLogger().shouldLog = false;
  CandiesAnalyzerPluginStarter.start(
    args,
    sendPort,
    plugin: CandiesAnalyzerPlugin(),
  );
}

import 'package:logger/logger.dart';
// ignore: implementation_imports
import 'package:logger/src/outputs/file_output.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;

/// The logger for this plugin
class CandiesAnalyzerPluginLogger {
  factory CandiesAnalyzerPluginLogger() => _candiesAnalyzerPluginLogger;
  CandiesAnalyzerPluginLogger._();
  static final CandiesAnalyzerPluginLogger _candiesAnalyzerPluginLogger =
      CandiesAnalyzerPluginLogger._();
  final Map<String, Logger> _loggers = <String, Logger>{};

  /// The name of log file
  String logFileName = 'candies_analyzer_plugin';

  /// whether should log
  bool shouldLog = false;
  void _init(String root) {
    if (!_loggers.containsKey(root)) {
      _loggers[root] = Logger(
          filter: _Filter(),
          printer: PrettyPrinter(
            methodCount: 0,
            printTime: true,
          ),
          output: FileOutput(
            file: io.File(path.join(
              root,
              '$logFileName.log',
            )),
            overrideExisting: true,
          ));

      log('analyze at : $root', root: root);
    }
  }

  /// Log info
  void log(
    dynamic message, {
    required String root,
    dynamic error,
    StackTrace? stackTrace,
    bool forceLog = false,
  }) {
    if (!shouldLog && !forceLog) {
      return;
    }
    _init(root);
    _loggers[root]?.d(message, error, stackTrace);
  }

  /// Log error
  void logError(
    dynamic message, {
    required String root,
    dynamic error,
    StackTrace? stackTrace,
    bool forceLog = false,
  }) {
    if (!shouldLog && !forceLog) {
      return;
    }
    _init(root);
    _loggers[root]?.e(message, error, stackTrace);
  }
}

class _Filter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

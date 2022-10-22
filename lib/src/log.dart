import 'package:logger/logger.dart';
// ignore: implementation_imports
import 'package:logger/src/outputs/file_output.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;

class CandiesLintsLogger {
  factory CandiesLintsLogger() => _candiesLintsLogger;
  CandiesLintsLogger._();
  static final CandiesLintsLogger _candiesLintsLogger = CandiesLintsLogger._();
  final Map<String, Logger> _loggers = <String, Logger>{};
  String logFileName = 'candies_lints';
  bool shouldLog = true;
  void _init(String root) {
    if (shouldLog) {
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
  }

  void log(
    dynamic message, {
    required String root,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _init(root);
    _loggers[root]?.d(message, error, stackTrace);
  }

  void logError(
    dynamic message, {
    required String root,
    dynamic error,
    StackTrace? stackTrace,
  }) {
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

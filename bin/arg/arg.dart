import 'dart:convert';
import 'dart:io';

import 'package:io/ansi.dart';

import 'arg_parser.dart';

abstract class Argument<T> {
  Argument() {
    if (false is T) {
      parser.addFlag(name,
          abbr: abbr, help: help, defaultsTo: defaultsTo as bool?);
    } else if ('' is T) {
      parser.addOption(name,
          abbr: abbr, help: help, defaultsTo: defaultsTo as String?);
    } else if (<String>[] is T) {
      parser.addMultiOption(
        name,
        abbr: abbr,
        help: help,
        defaultsTo: defaultsTo as List<String>?,
      );
    } else {
      // TODO(zmtzawqlp): not implement for now.
      throw Exception('not implement fill method');
    }
  }

  /// The name of the option that the user passes as an argument.
  String get name;

  /// A single-character string that can be used as a shorthand for this option.
  ///
  /// For example, `abbr: "a"` will allow the user to pass `-a value` or
  /// `-avalue`.
  String? get abbr;

  /// A description of this option.
  String get help;

  /// The value this option will have if the user doesn't explicitly pass it in
  T? get defaultsTo;

  /// The value this option
  T? get value {
    if (argResults.wasParsed(name)) {
      return argResults[name] as T?;
    }
    return defaultsTo;
  }

  void run();
}

String processRun({
  required String executable,
  String? arguments,
  bool runInShell = false,
  String? workingDirectory,
  List<String>? argumentsList,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
  bool printInfo = true,
}) {
  final List<String> temp = <String>[];

  if (arguments != null) {
    temp.addAll(
        arguments.split(' ')..removeWhere((String x) => x.trim() == ''));
  }

  if (argumentsList != null) {
    temp.addAll(argumentsList);
  }
  if (printInfo) {
    print(yellow.wrap('$executable $temp'));
  }
  final ProcessResult result = Process.runSync(
    executable,
    temp,
    runInShell: runInShell,
    workingDirectory: workingDirectory,
    stdoutEncoding: stdoutEncoding,
    stderrEncoding: stderrEncoding,
  );
  if (result.exitCode != 0) {
    throw Exception(result.stderr);
  }

  final String stdout = result.stdout.toString();
  if (printInfo) {
    print(green.wrap('stdout: $stdout\n'));
  }

  return stdout;
}

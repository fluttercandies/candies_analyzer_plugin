import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'plugin.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  final String debugFilePath = path.join(
      Directory.current.parent.parent.parent.path, 'lib', 'main.dart');

  final ResolvedUnitResult result =
      await resolveFile2(path: debugFilePath) as ResolvedUnitResult;

  final List<AnalysisError> errors =
      plugin.getErrorsFromResult(result, plugin.astVisitor);
  print(errors.length);
}

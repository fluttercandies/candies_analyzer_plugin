import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:candies_lints/candies_lints.dart';
import 'plugin.dart';

Future<void> main(List<String> args) async {
  final String root = Directory.current.parent.parent.parent.path;
  final AnalysisContextCollection collection =
      AnalysisContextCollection(includedPaths: <String>[root]);

  final CandiesLintsPlugin myPlugin = plugin;
  for (final AnalysisContext context in collection.contexts) {
    for (final String file in context.contextRoot.analyzedFiles()) {
      if (!myPlugin.shouldAnalyzeFile(file)) {
        continue;
      }
      final List<AnalysisError> errors = myPlugin.getErrorsFromResultForDebug(
        await context.currentSession.getResolvedUnit(file)
            as ResolvedUnitResult,
        context,
      );
      print(errors.length);
    }
  }
}

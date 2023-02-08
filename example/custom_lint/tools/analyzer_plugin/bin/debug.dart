import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';
import 'plugin.dart';

Future<void> main(List<String> args) async {
  final String root = Directory.current.parent.parent.parent.path;
  final AnalysisContextCollection collection =
      AnalysisContextCollection(includedPaths: <String>[root]);

  final CandiesAnalyzerPlugin myPlugin = plugin;
  for (final AnalysisContext context in collection.contexts) {
    final CandiesAnalyzerPluginConfig config = myPlugin.configs.putIfAbsent(
        context.root,
        () => CandiesAnalyzerPluginConfig(
              context: context,
              pluginName: myPlugin.name,
              dartLints: myPlugin.dartLints,
              astVisitor: myPlugin.astVisitor,
              yamlLints: myPlugin.yamlLints,
              genericLints: myPlugin.genericLints,
            ));

    if (!config.shouldAnalyze) {
      continue;
    }
    for (final String file in context.contextRoot.analyzedFiles()) {
      //var errors = await context.currentSession.getErrors(file);
      if (!config.include(file)) {
        continue;
      }
      if (!myPlugin.shouldAnalyzeFile(file, context)) {
        continue;
      }

      final bool isAnalyzed = context.contextRoot.isAnalyzed(file);
      if (!isAnalyzed) {
        continue;
      }

      final List<AnalysisError> errors =
          (await myPlugin.getAnalysisErrorsForDebug(
        file,
        context,
      ))
              .toList();
      for (final AnalysisError error in errors) {
        final List<AnalysisErrorFixes> fixes = await myPlugin
            .getAnalysisErrorFixesForDebug(
                EditGetFixesParams(file, error.location.offset), context)
            .toList();
        print(fixes.length);
      }

      print(errors.length);
    }
  }
}

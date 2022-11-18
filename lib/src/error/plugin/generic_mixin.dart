import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:candies_analyzer_plugin/src/config.dart';
import 'package:candies_analyzer_plugin/src/error/lints/generic_lint.dart';

mixin CandiesGenericFileErrorPlugin on ServerPlugin {
  /// The generic lints to be used to analyze generic files
  List<GenericLint> get genericLints => <GenericLint>[];

  Iterable<AnalysisError> analyzeGenericFile({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesAnalyzerPluginConfig config,
  }) sync* {
    final String content = File(path).readAsStringSync();
    final LineInfo lineInfo = LineInfo.fromContent(content);
    for (final GenericLint lint in config.genericLints) {
      yield* lint.toGenericAnalysisErrors(
        analysisContext: analysisContext,
        path: path,
        config: config,
        content: content,
        lineInfo: lineInfo,
      );
    }
  }
}

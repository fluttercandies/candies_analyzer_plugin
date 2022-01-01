import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';

mixin CandiesDartFileErrorPlugin on ServerPlugin {
  /// AstVisitor to check lint
  AstVisitorBase get astVisitor => CandiesLintsAstVisitor();

  /// The dart lints to be used to analyze dart files
  List<DartLint> get dartLints => <DartLint>[
        PreferAssetConst(),
        PreferNamedRoutes(),
        PerferSafeSetState(),
        MustCallSuperDispose(),
        EndCallSuperDispose(),
        PerferDocComments(),
        PreferSingleton(),
        //UnusedFile(),
        GoodDocComments(),
        PreferTrailingComma(),
      ];

  Future<Iterable<AnalysisError>> analyzeDartFile({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesAnalyzerPluginConfig config,
  }) async {
    final SomeResolvedUnitResult unitResult =
        await analysisContext.currentSession.getResolvedUnit(path);
    if (unitResult is ResolvedUnitResult) {
      return config.getDartErrorsFromResult(result: unitResult);
    }
    CandiesAnalyzerPluginLogger().logError('getResolvedUnit failed for $path',
        root: analysisContext.root);
    return <AnalysisError>[];
  }
}

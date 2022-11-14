part of 'plugin.dart';

mixin DartFilePlugin on ServerPlugin {
  /// AstVisitor to check lint
  AstVisitorBase get astVisitor => CandiesLintsAstVisitor();

  /// The dart lints to be used to analyze dart files
  List<DartLint> get dartLints => <DartLint>[
        PreferAssetConst(),
        PreferNamedRoutes(),
        PerferSafeSetState(),
        MustCallSuperDispose(),
        EndCallSuperDispose(),
      ];

  Future<Iterable<AnalysisError>> analyzeDartFile({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesLintsConfig config,
  }) async {
    final SomeResolvedUnitResult unitResult =
        await analysisContext.currentSession.getResolvedUnit(path);
    if (unitResult is ResolvedUnitResult) {
      return getDartErrorsFromResult(unitResult, config);
    }
    CandiesLintsLogger().logError('getResolvedUnit failed for $path',
        root: analysisContext.root);
    return <AnalysisError>[];
  }

  /// Return AnalysisError List base on ResolvedUnitResult.
  Iterable<AnalysisError> getDartErrorsFromResult(
    ResolvedUnitResult unitResult,
    CandiesLintsConfig config,
  ) {
    unitResult.unit.visitChildren(config.astVisitor);
    final CandiesLintsIgnoreInfo ignore =
        CandiesLintsIgnoreInfo.forDart(unitResult);
    return config.astVisitor
        .getAnalysisErrors(
          result: unitResult,
          ignore: ignore,
          config: config,
        )
        .toList();
  }
}

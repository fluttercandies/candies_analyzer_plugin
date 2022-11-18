part of 'config.dart';

/// The default AstVisitor to analyze lints
class CandiesLintsAstVisitor extends GeneralizingAstVisitor<void>
    with AstVisitorBase {
  @override
  void visitNode(AstNode node) {
    analyze(node);
    super.visitNode(node);
  }
}

/// AstVisitor to check lint
///
mixin AstVisitorBase on AstVisitor<void> {
  List<DartLint>? _lints;
  List<DartLint> get lints => _lints ??= <DartLint>[];

  bool analyze(AstNode node) {
    bool handle = false;
    for (final DartLint lint in lints) {
      handle = lint.analyze(node) || handle;
    }
    return handle;
  }

  Iterable<AnalysisError> getAnalysisErrors({
    required ResolvedUnitResult result,
    required CandiesAnalyzerPluginIgnoreInfo ignore,
    required CandiesAnalyzerPluginConfig? config,
  }) sync* {
    for (final DartLint lint in lints) {
      yield* lint.toDartAnalysisErrors(
        result: result,
        ignoreInfo: ignore,
        config: config,
      );
    }
  }

  Stream<AnalysisErrorFixes> getAnalysisErrorFixes({
    required EditGetFixesParams parameters,
  }) async* {
    for (final DartLint lint in lints) {
      yield* lint.toDartAnalysisErrorFixesStream(parameters: parameters);
    }
  }

  Iterable<DartAnalysisError> clearCacheErrors(String path) sync* {
    for (final DartLint lint in lints) {
      final List<DartAnalysisError>? list = lint.clearCacheErrors(path);
      if (list != null) {
        yield* list;
      }
    }
  }
}

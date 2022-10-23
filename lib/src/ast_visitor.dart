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
  List<CandyLint>? _lints;
  List<CandyLint> get lints => _lints ??= <CandyLint>[];

  bool analyze(AstNode node) {
    bool handle = false;
    for (final CandyLint lint in lints) {
      handle = lint.analyze(node) || handle;
    }
    return handle;
  }

  Iterable<AnalysisError> getAnalysisErrors({
    required ResolvedUnitResult result,
    required CandiesLintsIgnoreInfo ignore,
    required CandiesLintsConfig? config,
  }) sync* {
    for (final CandyLint lint in lints) {
      yield* lint.toAnalysisErrors(
        result: result,
        ignoreInfo: ignore,
        config: config,
      );
    }
  }

  Stream<AnalysisErrorFixes> getAnalysisErrorFixes({
    required EditGetFixesParams parameters,
  }) async* {
    for (final CandyLint lint in lints) {
      yield* lint.toAnalysisErrorFixesStream(parameters: parameters);
    }
  }

  Iterable<CandyAnalysisError> clearCacheErrors(String path) sync* {
    for (final CandyLint lint in lints) {
      final List<CandyAnalysisError>? list = lint.clearCacheErrors(path);
      if (list != null) {
        yield* list;
      }
    }
  }
}

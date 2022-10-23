part of 'plugin.dart';

mixin GenericFilePlugin on ServerPlugin {
  /// The generic lints to be used to analyze generic files
  List<GenericLint> get genericLints => <GenericLint>[];

  Iterable<AnalysisError> analyzeGenericFile({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesLintsConfig config,
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

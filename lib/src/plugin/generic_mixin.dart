part of 'plugin.dart';

mixin GenericFilePlugin on ServerPlugin {
  /// The generic lints to be used to analyze generic files
  List<GenericLint> get genericLints => <GenericLint>[];

  Iterable<AnalysisError> analyzeGenericFile({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesLintsConfig config,
  }) sync* {}
}

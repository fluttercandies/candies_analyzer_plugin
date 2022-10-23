part of 'plugin.dart';

mixin YamlFilePlugin on ServerPlugin {
  /// The yaml lints to be used to analyze yaml files
  List<YamlLint> get yamlLints => <YamlLint>[];

  Iterable<AnalysisError> analyzeYamlFile({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesLintsConfig config,
  }) sync* {
    final String content = File(path).readAsStringSync();
    final YamlNode root = loadYamlNode(content);
    //final String baseName = path_package.basename(path);
    // Pubspec? pubspec;
    // if (baseName == 'pubspec.yaml') {
    //   pubspec = Pubspec.parse(content);
    // }
    final LineInfo lineInfo = LineInfo.fromContent(content);
    for (final YamlLint lint in config.yamlLints) {
      yield* lint.toYamlAnalysisErrors(
        analysisContext: analysisContext,
        path: path,
        config: config,
        root: root,
        content: content,
        lineInfo: lineInfo,
      );
    }
  }
}

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:candies_analyzer_plugin/src/config.dart';
import 'package:candies_analyzer_plugin/src/error/lints/yaml_lint.dart';
import 'package:yaml/yaml.dart';

mixin CandiesYamlFileErrorPlugin on ServerPlugin {
  /// The yaml lints to be used to analyze yaml files
  List<YamlLint> get yamlLints => <YamlLint>[];

  Iterable<AnalysisError> analyzeYamlFile({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesAnalyzerPluginConfig config,
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

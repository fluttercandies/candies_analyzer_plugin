import 'dart:io';
import 'dart:async';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_options.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/error_processor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:candies_lints/src/extension.dart';
import 'package:candies_lints/src/ignore_info.dart';
import 'package:candies_lints/src/lints/lint.dart';
import 'package:path/path.dart' as path;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';
import 'package:analyzer/dart/ast/visitor.dart';
part 'ast_visitor.dart';

/// The class to handle pubspec.yaml and analysis_options.yaml
class CandiesLintsConfig {
  CandiesLintsConfig({
    required this.context,
    required this.pluginName,
    required List<CandyLint> lints,
    required this.astVisitor,
  }) {
    final AnalysisOptions analysisOptions = context.analysisOptions;
    _shouldAnalyze = analysisOptions.enabledPluginNames.contains(pluginName);

    // those files are excluded
    // var excludePatterns = analysisOptions.excludePatterns;

    // File(path.join(context.root, 'analysis_options.yaml'));
    // if (analysisOptionsFile.existsSync()) {
    //   var analysisOptions = loadYaml(analysisOptionsFile.readAsStringSync())
    //       as Map<dynamic, dynamic>;
    //
    // }

    if (_shouldAnalyze) {
      final File pubspecFile = File(path.join(context.root, 'pubspec.yaml'));

      if (pubspecFile.existsSync()) {
        final Pubspec pubspec = Pubspec.fromJson(
            loadYaml(pubspecFile.readAsStringSync()) as Map<dynamic, dynamic>);
        _shouldAnalyze = pubspec.devDependencies.containsKey(pluginName);
      }
    }

    if (shouldAnalyze) {
      final List<String> disableLints = <String>[];
      final String? path = context.contextRoot.optionsFile?.path;
      if (path != null) {
        final File file = File(path);
        final YamlMap yaml = loadYaml(file.readAsStringSync()) as YamlMap;

        // if (yaml.containsKey('include')) {
        //   var s = yaml.nodes['include'] as YamlScalar;
        //   print('dd');
        // }
        if (yaml.nodes['linter'] is YamlMap) {
          final YamlMap linter = yaml.nodes['linter'] as YamlMap;
          if (linter.containsKey('rules')) {
            // perfer_candies_class_prefix: false
            // we will see which custom lint is false
            if (linter.nodes['rules'] is YamlMap) {
              final YamlMap rules = linter.nodes['rules'] as YamlMap;
              for (final dynamic key in rules.keys) {
                if (rules[key]?.toString().trim() == 'false') {
                  disableLints.add(key.toString().toUpperCase());
                }
              }
            }
            // - perfer_candies_class_prefix
            // else if (linter.nodes['rules'] is YamlList) {}
          }
        }
      }

      astVisitor._lints = lints
          .where((CandyLint lint) =>
              !disableLints.contains(lint.code.toUpperCase()) && !ignore(lint))
          .toList();
    }
  }

  final AnalysisContext context;
  final String pluginName;
  final AstVisitorBase astVisitor;

  bool _shouldAnalyze = false;
  bool get shouldAnalyze => _shouldAnalyze;

  bool ignore(CandyLint lint) {
    for (final ErrorProcessor errorProcessor
        in context.analysisOptions.errorProcessors) {
      if (errorProcessor.ignore(lint)) {
        return true;
      }
    }
    return false;
  }

  AnalysisErrorSeverity getSeverity(CandyLint lint) {
    for (final ErrorProcessor errorProcessor
        in context.analysisOptions.errorProcessors) {
      if (errorProcessor.same(lint)) {
        return errorProcessor.getSeverity(lint);
      }
    }
    return lint.severity;
  }
}

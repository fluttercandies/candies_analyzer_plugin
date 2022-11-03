// ignore_for_file: implementation_imports

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
import 'package:candies_lints/src/error/dart.dart';
import 'package:candies_lints/src/lints/dart/dart_lint.dart';
import 'package:candies_lints/src/lints/generic_lint.dart';
import 'package:candies_lints/src/lints/lint.dart';
import 'package:candies_lints/src/lints/yaml_lint.dart';
import 'package:path/path.dart' as path_context;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/util/glob.dart';
import 'package:analyzer/src/util/file_paths.dart' as file_paths;
part 'ast_visitor.dart';

/// The class to handle pubspec.yaml and analysis_options.yaml
class CandiesLintsConfig {
  CandiesLintsConfig({
    required this.context,
    required this.pluginName,
    required List<DartLint> dartLints,
    required this.astVisitor,
    required this.yamlLints,
    required this.genericLints,
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
      final File pubspecFile =
          File(path_context.join(context.root, file_paths.pubspecYaml));

      if (pubspecFile.existsSync()) {
        final Pubspec pubspec = Pubspec.fromJson(
            loadYaml(pubspecFile.readAsStringSync()) as Map<dynamic, dynamic>);
        _shouldAnalyze = pubspec.devDependencies.containsKey(pluginName);
      }
    }

    if (shouldAnalyze) {
      final List<String> disableLints = <String>[];
      final String? optionsFilePath = context.contextRoot.optionsFile?.path;
      if (optionsFilePath != null) {
        final File file = File(optionsFilePath);
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
        if (yaml.nodes[pluginName] is YamlMap) {
          final YamlMap pluginConfig = yaml.nodes[pluginName] as YamlMap;
          void fillPatternList(String node, List<Glob> patternList) {
            if (pluginConfig.nodes[node] is YamlList) {
              patternList.addAll((pluginConfig.nodes[node] as YamlList).map(
                  (dynamic e) => Glob(path_context.separator, e.toString())));
            }
          }

          fillPatternList('include', _includePatterns);
          fillPatternList('exclude', _excludePatterns);
        }
      }

      astVisitor._lints = dartLints
          .where((DartLint lint) =>
              !disableLints.contains(lint.code.toUpperCase()) && !ignore(lint))
          .toList();

      yamlLints.removeWhere((YamlLint lint) =>
          disableLints.contains(lint.code.toUpperCase()) || ignore(lint));

      genericLints.removeWhere((GenericLint lint) =>
          disableLints.contains(lint.code.toUpperCase()) || ignore(lint));
    }
  }

  final AnalysisContext context;
  final String pluginName;
  final AstVisitorBase astVisitor;
  final List<Glob> _includePatterns = <Glob>[];
  final List<Glob> _excludePatterns = <Glob>[];
  final List<YamlLint> yamlLints;
  final List<GenericLint> genericLints;
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

  bool isAnalyzed(String path) {
    final String relative =
        path_context.relative(path, from: context.contextRoot.root.path);
    return _include(relative) && !_exclude(relative);
  }

  bool _include(String path) =>
      _includePatterns.isEmpty ||
      _includePatterns.any((Glob pattern) => pattern.matches(path));

  bool _exclude(String path) =>
      _excludePatterns.any((Glob pattern) => pattern.matches(path));

  bool isDartFile(String file) => file_paths.isDart(path_context.context, file);

  bool isYamlFile(String file) => file.endsWith('.yaml');

  Stream<AnalysisErrorFixes> getAnalysisErrorFixes({
    required EditGetFixesParams parameters,
    required AnalysisContext analysisContext,
  }) async* {
    final String file = parameters.file;

    if (isDartFile(file)) {
      for (final DartLint lint in astVisitor.lints) {
        yield* lint.toDartAnalysisErrorFixesStream(parameters: parameters);
      }
    } else if (isYamlFile(file)) {
      for (final YamlLint lint in yamlLints) {
        yield* lint.toYamlAnalysisErrorFixesStream(
          parameters: parameters,
          analysisContext: analysisContext,
        );
      }
    } else {
      for (final GenericLint lint in genericLints) {
        yield* lint.toGenericAnalysisErrorFixesStream(
          parameters: parameters,
          analysisContext: analysisContext,
        );
      }
    }
  }

  void clearCacheErrors(String file) {
    if (isDartFile(file)) {
      astVisitor.clearCacheErrors(file).toList();
    } else if (isYamlFile(file)) {
      for (final YamlLint lint in yamlLints) {
        lint.clearCacheErrors(file);
      }
    } else {
      for (final GenericLint lint in genericLints) {
        lint.clearCacheErrors(file);
      }
    }
  }
}

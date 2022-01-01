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
import 'package:candies_analyzer_plugin/src/error/lints/dart/dart_lint.dart';
import 'package:candies_analyzer_plugin/src/error/lints/generic_lint.dart';
import 'package:candies_analyzer_plugin/src/error/lints/lint.dart';
import 'package:candies_analyzer_plugin/src/error/lints/yaml_lint.dart';
import 'package:candies_analyzer_plugin/src/extension.dart';
import 'package:candies_analyzer_plugin/src/ignore_info.dart';
import 'package:path/path.dart' as path_context;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/util/glob.dart';
import 'package:analyzer/src/util/file_paths.dart' as file_paths;

import 'error/lints/dart/unused_file.dart';
import 'log.dart';

part 'ast_visitor.dart';

/// The class to handle pubspec.yaml and analysis_options.yaml
class CandiesAnalyzerPluginConfig {
  CandiesAnalyzerPluginConfig({
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
          if (pluginConfig.nodes['include'] is YamlList) {
            final YamlList includePatterns =
                pluginConfig.nodes['include'] as YamlList;
            _includePatterns.addAll(includePatterns
                .map((dynamic e) => Glob(path_context.separator, e.toString()))
                .toList());
          }
        }
      }

      _dartLints.addAll(dartLints.where((DartLint lint) =>
          !disableLints.contains(lint.code.toUpperCase()) && !ignore(lint)));

      // astVisitor._lints = _dartLints
      //     .where((DartLint element) => element.astVisitor == null)
      //     .toList();

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
  final List<YamlLint> yamlLints;
  final List<DartLint> _dartLints = <DartLint>[];
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

  bool include(String input) {
    if (_includePatterns.isEmpty) {
      return true;
    }

    final String relative =
        path_context.relative(input, from: context.contextRoot.root.path);

    for (final Glob includePattern in _includePatterns) {
      if (includePattern.matches(relative)) {
        return true;
      }
    }
    return false;
  }

  bool isDartFile(String file) => file_paths.isDart(path_context.context, file);

  bool isYamlFile(String file) => file.endsWith('.yaml');

  Iterable<AnalysisError> getDartErrorsFromResult({
    required ResolvedUnitResult result,
  }) sync* {
    final CandiesAnalyzerPluginIgnoreInfo ignore =
        CandiesAnalyzerPluginIgnoreInfo.forDart(result);
    final Iterable<DartLint> dartLints = _dartLints.where((DartLint dartLint) {
      final bool shouldAnalyze =
          !dartLint.ignoreFile(result) && !ignore.ignored(dartLint.code);

      if (!shouldAnalyze && dartLint is UnusedFile) {
        // add this into used file

        return true;
      }
      return shouldAnalyze;
    });
    if (dartLints.isEmpty) {
      return;
    }

    CandiesAnalyzerPluginLogger().log(
      'begin analyze file: ${result.path}}',
      root: result.root,
    );

    // use CandiesAnalyzerPlugin.astVisitor [CandiesLintsAstVisitor]
    final List<DartLint> dartLints1 = dartLints
        .where((DartLint element) => element.astVisitor == null)
        .toList();

    if (dartLints1.isNotEmpty) {
      astVisitor._lints = dartLints1;
      result.unit.accept(astVisitor);
    }

    for (final DartLint dartLint in dartLints) {
      // use [DartLint].astVisitor
      dartLint.accept(result, ignore);

      yield* dartLint.toDartAnalysisErrors(
        ignoreInfo: ignore,
        result: result,
        config: this,
      );
    }
  }

  Stream<AnalysisErrorFixes> getAnalysisErrorFixes({
    required EditGetFixesParams parameters,
    required AnalysisContext analysisContext,
  }) async* {
    final String file = parameters.file;

    if (isDartFile(file)) {
      for (final DartLint lint in _dartLints) {
        yield* lint.toDartAnalysisErrorFixesStream(
          parameters: parameters,
          analysisContext: analysisContext,
          config: this,
        );
      }
    } else if (isYamlFile(file)) {
      for (final YamlLint lint in yamlLints) {
        yield* lint.toYamlAnalysisErrorFixesStream(
          parameters: parameters,
          analysisContext: analysisContext,
          config: this,
        );
      }
    } else {
      for (final GenericLint lint in genericLints) {
        yield* lint.toGenericAnalysisErrorFixesStream(
          parameters: parameters,
          analysisContext: analysisContext,
          config: this,
        );
      }
    }
  }

  void clearCacheErrors(String file) {
    if (isDartFile(file)) {
      for (final DartLint dartLint in _dartLints) {
        dartLint.clearCacheErrors(file);
      }
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

  Iterable<AnalysisError> getAllCacheErrors({String? code}) sync* {
    for (final DartLint lint in _dartLints) {
      if (code != null && lint.code != code) {
        continue;
      }
      yield* lint.getAllCacheErrors();
    }

    for (final YamlLint lint in yamlLints) {
      if (code != null && lint.code != code) {
        continue;
      }
      yield* lint.getAllCacheErrors();
    }

    for (final GenericLint lint in genericLints) {
      if (code != null && lint.code != code) {
        continue;
      }
      yield* lint.getAllCacheErrors();
    }
  }

  Iterable<AnalysisError> getCacheErrors(String path, {String? code}) sync* {
    for (final DartLint lint in _dartLints) {
      if (code != null && lint.code != code) {
        continue;
      }
      final List<AnalysisError>? errors = lint.getCacheErrors(path);
      if (errors != null) {
        yield* errors;
      }
    }

    for (final YamlLint lint in yamlLints) {
      if (code != null && lint.code != code) {
        continue;
      }
      final List<AnalysisError>? errors = lint.getCacheErrors(path);
      if (errors != null) {
        yield* errors;
      }
    }

    for (final GenericLint lint in genericLints) {
      if (code != null && lint.code != code) {
        continue;
      }
      final List<AnalysisError>? errors = lint.getCacheErrors(path);
      if (errors != null) {
        yield* errors;
      }
    }
  }

  UnusedFile? get unusedFile {
    for (final DartLint dartLint in _dartLints) {
      if (dartLint is UnusedFile) {
        return dartLint;
      }
    }
    return null;
  }
}

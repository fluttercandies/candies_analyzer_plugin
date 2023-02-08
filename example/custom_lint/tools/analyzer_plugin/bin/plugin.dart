import 'dart:convert';
import 'dart:isolate';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_yaml.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';
import 'package:analyzer/src/pubspec/pubspec_validator.dart';

CandiesAnalyzerPlugin get plugin => CustomLintPlugin();

// This file must be 'plugin.dart'
void main(List<String> args, SendPort sendPort) {
  // for performance, default is false, if you want to check log, set it to true.
  CandiesAnalyzerPluginLogger().shouldLog = true;
  CandiesAnalyzerPluginStarter.start(
    args,
    sendPort,
    plugin: plugin,
  );
}

class CustomLintPlugin extends CandiesAnalyzerPlugin {
  @override
  String get name => 'custom_lint';

  @override
  List<String> get fileGlobsToAnalyze => const <String>[
        '**/*.dart',
        '**/*.yaml',
        '**/*.json',
      ];

  @override
  List<DartLint> get dartLints => <DartLint>[
        // add your dart lint here
        PerferCandiesClassPrefix(),
        ...super.dartLints,
      ];

  @override
  List<YamlLint> get yamlLints => <YamlLint>[RemoveDependency(package: 'path')];

  @override
  List<GenericLint> get genericLints => <GenericLint>[RemoveDuplicateValue()];

  @override
  bool get showAnalysisErrorWithGitAuthor => false;

  @override
  bool get cacheErrorsIntoFile => true;
}

class PerferCandiesClassPrefix extends DartLint {
  @override
  String get code => 'perfer_candies_class_prefix';

  @override
  String? get url =>
      'https://github.com/fluttercandies/candies_analyzer_plugin';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is ClassDeclaration) {
      final String name = node.name2.toString();
      final int startIndex = _getClassNameStartIndex(name);
      if (!name.substring(startIndex).startsWith('Candies')) {
        return node.name2;
      }
    }
    return null;
  }

  @override
  String get message => 'Define a class name start with Candies';

  @override
  Future<List<SourceChange>> getDartFixes(
    DartAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async {
    final ResolvedUnitResult resolvedUnitResult = error.result;

    final Iterable<DartAnalysisError> cacheErrors = config
        .getCacheErrors(resolvedUnitResult.path, code: code)
        .whereType<DartAnalysisError>();

    final Map<DartAnalysisError, Set<SyntacticEntity>> references =
        _findClassReferences(cacheErrors, resolvedUnitResult);

    return <SourceChange>[
      await getDartFix(
        resolvedUnitResult: resolvedUnitResult,
        message: 'Use Candies as a class prefix.',
        buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
          _fix(
            error,
            resolvedUnitResult,
            dartFileEditBuilder,
            references[error]!,
          );
          dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
        },
      ),
      if (cacheErrors.length > 1)
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'Use Candies as a class prefix where possible in file.',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            for (final DartAnalysisError error in cacheErrors) {
              _fix(
                error,
                resolvedUnitResult,
                dartFileEditBuilder,
                references[error]!,
              );
            }
            dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
          },
        ),
    ];
  }

  void _fix(
    DartAnalysisError error,
    ResolvedUnitResult resolvedUnitResult,
    DartFileEditBuilder dartFileEditBuilder,
    Set<SyntacticEntity> references,
  ) {
    final AstNode astNode = error.astNode;
    // get name node
    final Token nameNode = (astNode as ClassDeclaration).name2;
    final String nameString = nameNode.lexeme;

    final int startIndex = _getClassNameStartIndex(nameString);
    final String replace =
        '${nameString.substring(0, startIndex)}Candies${nameString.substring(startIndex)}';

    for (final SyntacticEntity match in references) {
      dartFileEditBuilder.addSimpleReplacement(
          SourceRange(match.offset, match.length), replace);
    }
  }

  Map<DartAnalysisError, Set<SyntacticEntity>> _findClassReferences(
    Iterable<DartAnalysisError> errors,
    ResolvedUnitResult resolvedUnitResult,
  ) {
    final Map<DartAnalysisError, Set<SyntacticEntity>> references =
        <DartAnalysisError, Set<SyntacticEntity>>{};
    final Map<String, DartAnalysisError> classNames =
        <String, DartAnalysisError>{};

    for (final DartAnalysisError error in errors) {
      classNames[(error.astNode as ClassDeclaration).name2.lexeme] = error;
      references[error] = <SyntacticEntity>{};
    }

    resolvedUnitResult.unit
        .accept(_FindClassReferenceVisitor(references, classNames));

    return references;
  }

  int _getClassNameStartIndex(String nameString) {
    int index = 0;
    while (nameString[index] == '_') {
      index++;
      if (index == nameString.length - 1) {
        break;
      }
    }
    return index;
  }
}

class _FindClassReferenceVisitor extends GeneralizingAstVisitor<void> {
  _FindClassReferenceVisitor(this.references, this.classNames);
  final Map<DartAnalysisError, Set<SyntacticEntity>> references;
  final Map<String, DartAnalysisError> classNames;

  @override
  void visitNode(AstNode node) {
    if (node.childEntities.length == 1) {
      final String source = node.toSource();
      if (classNames.keys.contains(source)) {
        references[classNames[source]]!.add(node);
        return;
      }
    }
    super.visitNode(node);
  }
}

class RemoveDependency extends YamlLint {
  RemoveDependency({required this.package});
  final String package;
  @override
  String get code => 'remove_${package}_dependency';

  @override
  String get message => 'Remove $package dependency';

  @override
  String? get correction => 'Remove $package dependency';

  @override
  AnalysisErrorSeverity get severity => AnalysisErrorSeverity.WARNING;

  @override
  Iterable<SourceRange> matchLint(
    YamlNode root,
    String content,
    LineInfo lineInfo,
  ) sync* {
    if (root is YamlMap && root.containsKey(PubspecField.DEPENDENCIES_FIELD)) {
      final YamlNode dependencies =
          root.nodes[PubspecField.DEPENDENCIES_FIELD]!;
      if (dependencies is YamlMap && dependencies.containsKey(package)) {
        final YamlNode get = dependencies.nodes[package]!;
        int start = dependencies.span.start.offset;
        final int end = get.span.start.offset;
        final int index = content.substring(start, end).indexOf('$package: ');
        start += index;
        yield SourceRange(start, get.span.end.offset - start);
      }
    }
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  @override
  Future<List<SourceChange>> getYamlFixes(
    AnalysisContext analysisContext,
    String path,
    YamlAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async =>
      <SourceChange>[
        await getYamlFix(
            analysisContext: analysisContext,
            path: path,
            message: 'Remove $package Dependency',
            buildYamlFileEdit: (YamlFileEditBuilder builder) {
              builder.addSimpleReplacement(
                  SourceRange(error.location.offset, error.location.length),
                  '');
            })
      ];
}

class RemoveDuplicateValue extends GenericLint {
  @override
  String get code => 'remove_duplicate_value';

  @override
  Iterable<SourceRange> matchLint(
    String content,
    String file,
    LineInfo lineInfo,
  ) sync* {
    if (isFileType(file: file, type: '.json')) {
      final Map<dynamic, dynamic> map =
          jsonDecode(content) as Map<dynamic, dynamic>;

      final Map<dynamic, dynamic> duplicate = <dynamic, dynamic>{};
      final Map<dynamic, dynamic> checkDuplicate = <dynamic, dynamic>{};
      for (final dynamic key in map.keys) {
        final dynamic value = map[key];
        if (checkDuplicate.containsKey(value)) {
          duplicate[key] = value;
          duplicate[checkDuplicate[value]] = value;
        }
        checkDuplicate[value] = key;
      }

      if (duplicate.isNotEmpty) {
        for (final dynamic key in duplicate.keys) {
          final int start = content.indexOf('"$key"');
          final dynamic value = duplicate[key];
          final int end = content.indexOf(
                '"$value"',
                start,
              ) +
              value.toString().length +
              1;

          final int lineNumber = lineInfo.getLocation(end).lineNumber;

          bool hasComma = false;
          int commaIndex = end;
          int commaLineNumber = lineInfo.getLocation(commaIndex).lineNumber;

          while (!hasComma && commaLineNumber == lineNumber) {
            commaIndex++;
            final String char = content[commaIndex];
            hasComma = char == ',';
            commaLineNumber = lineInfo.getLocation(commaIndex).lineNumber;
          }

          yield SourceRange(start, (hasComma ? commaIndex : end) + 1 - start);
        }
      }
    }
  }

  @override
  String get message => 'remove duplicate value';

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  @override
  Future<List<SourceChange>> getGenericFixes(
    AnalysisContext analysisContext,
    String path,
    GenericAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async =>
      <SourceChange>[
        await getGenericFix(
            analysisContext: analysisContext,
            path: path,
            message: 'Remove duplicate value',
            buildFileEdit: (FileEditBuilder builder) {
              builder.addSimpleReplacement(
                  SourceRange(error.location.offset, error.location.length),
                  '');
            })
      ];
}

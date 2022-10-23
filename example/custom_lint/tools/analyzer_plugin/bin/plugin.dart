import 'dart:isolate';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_yaml.dart';
import 'package:candies_lints/candies_lints.dart';
import 'package:analyzer/src/pubspec/pubspec_validator.dart';

CandiesLintsPlugin get plugin => CustomLintPlugin();

// This file must be 'plugin.dart'
void main(List<String> args, SendPort sendPort) {
  CandiesLintsStarter.start(
    args,
    sendPort,
    plugin: plugin,
  );
}

class CustomLintPlugin extends CandiesLintsPlugin {
  @override
  String get name => 'custom_lint';

  @override
  bool shouldAnalyzeFile(String path) {
    return super.shouldAnalyzeFile(path) || path.endsWith('.yaml');
  }

  @override
  List<DartLint> get dartLints => <DartLint>[
        // add your line here
        PerferCandiesClassPrefix(),

        ...super.dartLints,
      ];

  @override
  List<YamlLint> get yamlLints => <YamlLint>[
        RemoveDependency(package: 'path'),
      ];
}

class PerferCandiesClassPrefix extends DartLint {
  @override
  String get code => 'perfer_candies_class_prefix';

  @override
  String? get url => 'https://github.com/fluttercandies/candies_lints';

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
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async {
    // get name node
    final Token nameNode = (astNode as ClassDeclaration).name2;
    final String nameString = nameNode.toString();
    return <SourceChange>[
      await getDartFix(
        resolvedUnitResult: resolvedUnitResult,
        message: 'Use Candies as a class prefix.',
        buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
          final int startIndex = _getClassNameStartIndex(nameString);

          final RegExp regExp = RegExp(nameString);

          final String replace =
              '${nameString.substring(0, startIndex)}Candies${nameString.substring(startIndex)}';

          for (final Match match
              in regExp.allMatches(resolvedUnitResult.content)) {
            dartFileEditBuilder.addSimpleReplacement(
                SourceRange(match.start, match.end - match.start), replace);
          }

          dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
        },
      )
    ];
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

class RemoveDependency extends YamlLint {
  RemoveDependency({required this.package});
  final String package;
  @override
  String get code => 'remove_${package}_dependency';

  @override
  String get message => 'don\'t use $package!';

  @override
  String? get correction => 'Remove $package dependency';

  @override
  AnalysisErrorSeverity get severity => AnalysisErrorSeverity.WARNING;

  @override
  List<SourceRange> matchLint(
    YamlNode root,
    String content,
  ) {
    if (root is YamlMap && root.containsKey(PubspecField.DEPENDENCIES_FIELD)) {
      YamlNode dependencies = root.nodes[PubspecField.DEPENDENCIES_FIELD]!;
      if (dependencies is YamlMap && dependencies.containsKey(package)) {
        YamlNode get = dependencies.nodes[package]!;
        int start = dependencies.span.start.offset;
        int end = get.span.start.offset;
        var index = content.substring(start, end).indexOf('$package: ');
        start += index;
        return <SourceRange>[SourceRange(start, get.span.end.offset - start)];
      }
    }

    return <SourceRange>[];
  }

  @override
  Future<List<SourceChange>> getYamlFixes(
    AnalysisContext analysisContext,
    String path,
    YamlAnalysisError error,
  ) async =>
      <SourceChange>[
        await getYamlFix(
            analysisContext: analysisContext,
            path: path,
            message: 'Remove $package Dependency',
            buildYamlFileEdit: ((YamlFileEditBuilder builder) {
              builder.addSimpleReplacement(
                  SourceRange(error.location.offset, error.location.length),
                  '');
            }))
      ];
}

import 'dart:isolate';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_lints/candies_lints.dart';

CandiesLintsPlugin get plugin => CandiesLintsPlugin(
      name: 'custom_lint',
      logFileName: 'custom_lint',
      lints: <CandyLint>[
        // add your line here
        PerferCandiesClassPrefix(),
        ...CandiesLintsPlugin.defaultLints,
      ],
    );

// This file must be 'plugin.dart'
void main(List<String> args, SendPort sendPort) {
  CandiesLintsStarter.start(
    args,
    sendPort,
    plugin: plugin,
  );
}

class PerferCandiesClassPrefix extends CandyLint {
  @override
  String get code => 'perfer_candies_class_prefix';

  @override
  String? get url => 'https://github.com/fluttercandies/candies_lints';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is ClassDeclaration) {
      final String name = node.name2.toString();
      int startIndex = _getClassNameStartIndex(name);
      if (!name.substring(startIndex).startsWith('Candies')) {
        return node.name2;
      }
    }
    return null;
  }

  @override
  String get message => 'Define a class name start with Candies';

  @override
  Future<List<SourceChange>> getFixes(
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async {
    // get name node
    Token nameNode = (astNode as ClassDeclaration).name2;
    String nameString = nameNode.toString();
    return <SourceChange>[
      await getFix(
        resolvedUnitResult: resolvedUnitResult,
        message: 'Use Candies as a class prefix.',
        buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
          int startIndex = _getClassNameStartIndex(nameString);

          RegExp regExp = RegExp(nameString);

          String replace =
              '${nameString.substring(0, startIndex)}Candies${nameString.substring(startIndex)}';

          for (Match match in regExp.allMatches(resolvedUnitResult.content)) {
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

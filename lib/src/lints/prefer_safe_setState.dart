import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_lints/src/extension.dart';

import 'lint.dart';

class PerferSafeSetState extends CandyLint {
  @override
  String get code => 'prefer_safe_setState';

  @override
  String get message => 'prefer to check mounted before setState';

  @override
  String? get correction => 'Add if(mounted){} for setState';

  @override
  String? get url => 'https://github.com/fluttercandies/candies_lints';

  @override
  Future<List<SourceChange>> getFixes(
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async {
    return <SourceChange>[
      if (astNode.toString().endsWith(';') ||
          (astNode.parent != null && astNode.parent!.toString().endsWith(';')))
        await getFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'Add if(mounted){} for setState',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            final int start = astNode.offset;
            final int end = astNode.end + 1;
            const String a = 'if(mounted){';
            const String b = '}';
            dartFileEditBuilder.addSimpleInsertion(start, a);
            dartFileEditBuilder.addSimpleInsertion(end, b);
            dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
          },
        )
    ];
  }

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is MethodInvocation && node.methodName.toString() == 'setState') {
      AstNode? parent = node.parent;
      while (parent != null && parent is! BlockFunctionBody) {
        if (parent is IfStatement &&
            parent.condition.toString().contains('mounted')) {
          return null;
        } else if (parent is ClassDeclaration) {
          return null;
        }
        parent = parent.parent;
      }
      return node;
    }
    return null;
  }
}

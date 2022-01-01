import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_analyzer_plugin/src/config.dart';
import 'package:candies_analyzer_plugin/src/error/error/dart.dart';
import 'package:candies_analyzer_plugin/src/extension.dart';

import 'dart_lint.dart';

/// The 'prefer_safe_setState' lint
class PerferSafeSetState extends DartLint {
  @override
  String get code => 'prefer_safe_setState';

  @override
  String get message => 'Prefer to check mounted before setState';

  @override
  String? get correction => 'Add if(mounted){} for setState';

  @override
  String? get url =>
      'https://github.com/fluttercandies/candies_analyzer_plugin';

  @override
  Future<List<SourceChange>> getDartFixes(
    DartAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async {
    final ResolvedUnitResult resolvedUnitResult = error.result;
    final Iterable<DartAnalysisError> cacheErrors = config
        .getCacheErrors(resolvedUnitResult.path, code: code)
        .whereType<DartAnalysisError>()
        .where((DartAnalysisError element) => _hasFix(element.astNode));

    final AstNode astNode = error.astNode;
    return <SourceChange>[
      if (_hasFix(astNode))
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'Add if(mounted){} for setState',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            _fix(error, dartFileEditBuilder);
            dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
          },
        ),
      if (cacheErrors.length > 1)
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'Add if(mounted){} for setState where possible in file.',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            for (final DartAnalysisError error in cacheErrors) {
              _fix(error, dartFileEditBuilder);
            }
            dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
          },
        ),
    ];
  }

  bool _hasFix(AstNode astNode) {
    return astNode.toString().endsWith(';') ||
        (astNode.parent != null && astNode.parent!.toString().endsWith(';'));
  }

  void _fix(DartAnalysisError error, DartFileEditBuilder dartFileEditBuilder) {
    final AstNode astNode = error.astNode;
    final int start = astNode.offset;
    final int end = astNode.end + 1;
    const String a = 'if(mounted){';
    const String b = '}';
    dartFileEditBuilder.addSimpleInsertion(start, a);
    dartFileEditBuilder.addSimpleInsertion(end, b);
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

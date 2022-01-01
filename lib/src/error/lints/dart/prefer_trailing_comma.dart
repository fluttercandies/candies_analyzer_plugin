import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';

import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';

class PreferTrailingComma extends DartLint {
  @override
  String get code => 'prefer_trailing_comma';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is ArgumentList) {
      return _handleNodes(
        node.arguments,
        node.leftParenthesis,
        node.rightParenthesis,
      );
    } else if (node is FormalParameterList) {
      return _handleNodes(
        node.parameters,
        node.leftParenthesis,
        node.rightParenthesis,
      );
    } else if (node is ListLiteral) {
      return _handleNodes(
        node.elements,
        node.leftBracket,
        node.rightBracket,
      );
    } else if (node is SetOrMapLiteral) {
      return _handleNodes(
        node.elements,
        node.leftBracket,
        node.rightBracket,
      );
    }

    return null;
  }

  @override
  String get message => 'Prefer trailing comma.';

  SyntacticEntity? _handleNodes(
    Iterable<AstNode> nodes,
    Token leftBracket,
    Token rightBracket,
  ) {
    if (nodes.isEmpty) {
      return null;
    }

    final AstNode last = nodes.last;
    final LineInfo lineInfo = (last.root as CompilationUnit).lineInfo;

    // not end with comma
    if (last.endToken.next?.type != TokenType.COMMA) {
      final int startLineNumber = leftBracket.startLineNumber(lineInfo);
      final int endLineNumber = rightBracket.startLineNumber(lineInfo);

      if (startLineNumber != endLineNumber &&
          // it's not in the same line
          !(last.startLineNumber(lineInfo) == startLineNumber &&
              last.endLineNumber(lineInfo) == endLineNumber)) {
        return last;
      }
    }

    return null;
  }

  @override
  Future<List<SourceChange>> getDartFixes(
    DartAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async {
    final ResolvedUnitResult resolvedUnitResult = error.result;

    final Iterable<DartAnalysisError> cacheErrors = config
        .getCacheErrors(resolvedUnitResult.path, code: code)
        .whereType<DartAnalysisError>();

    return <SourceChange>[
      await getDartFix(
        resolvedUnitResult: resolvedUnitResult,
        message: 'Add trailing comma.',
        buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
          _fix(dartFileEditBuilder, error);
          dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
        },
      ),
      if (cacheErrors.length > 1)
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'Add trailing comma where possible in file.',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            for (final DartAnalysisError error in cacheErrors) {
              _fix(dartFileEditBuilder, error);
            }
            dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
          },
        ),
    ];
  }

  void _fix(DartFileEditBuilder dartFileEditBuilder, DartAnalysisError error) {
    dartFileEditBuilder.addSimpleInsertion(
      error.location.offset + error.location.length,
      ',',
    );
  }
}

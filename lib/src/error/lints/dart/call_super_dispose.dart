// ignore_for_file: implementation_imports

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer/src/dart/ast/ast.dart';

import 'dart_lint.dart';

class MustCallSuperDispose extends DartLint with CallSuperDisposeMixin {
  @override
  String get code => 'must_call_super_dispose';
}

class EndCallSuperDispose extends DartLint with CallSuperDisposeMixin {
  @override
  String get code => 'end_call_super_dispose';
}

mixin CallSuperDisposeMixin on DartLint {
  @override
  String get message =>
      'Implementations of this method should end with a call to the inherited method, as in `super.dispose()`';
  @override
  Future<List<SourceChange>> getDartFixes(
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async {
    if (astNode is MethodDeclarationImpl &&
        astNode.body is BlockFunctionBodyImpl) {
      final AstNode? result = _matchLint(astNode);
      return <SourceChange>[
        if (this is MustCallSuperDispose && result == astNode)
          await getDartFix(
            resolvedUnitResult: resolvedUnitResult,
            message: 'must call super.dispose',
            buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
              dartFileEditBuilder.addSimpleInsertion(
                  astNode.end - 1, 'super.dispose();');
              dartFileEditBuilder.format(SourceRange(
                astNode.offset,
                astNode.length,
              ));
            },
          )
        else if (this is EndCallSuperDispose &&
            result is ExpressionStatementImpl)
          await getDartFix(
            resolvedUnitResult: resolvedUnitResult,
            message: 'call super.dispose at the end of this method',
            buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
              dartFileEditBuilder.addSimpleReplacement(
                  SourceRange(
                    result.offset,
                    result.length,
                  ),
                  '');
              dartFileEditBuilder.addSimpleInsertion(
                  astNode.end - 1, 'super.dispose();');
              dartFileEditBuilder.format(SourceRange(
                astNode.offset,
                astNode.length,
              ));
            },
          ),
      ];
    }

    return <SourceChange>[];
  }

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is MethodDeclarationImpl) {
      if (node.name2.toString() == 'dispose') {
        final AstNode? result = _matchLint(node);
        // remove the metadata
        if (result != null &&
            result is MethodDeclarationImpl &&
            result.metadata.isNotEmpty) {
          return _SyntacticEntity(
            result.firstTokenAfterCommentAndMetadata.offset,
            node.end,
          );
        }

        return result;
      }
    }
    return null;
  }

  AstNode? _matchLint(MethodDeclarationImpl node) {
    bool callSuperDispose = false;
    for (final ChildEntity element in node.body.namedChildEntities) {
      if (element.value is BlockImpl) {
        final BlockImpl block = element.value as BlockImpl;
        final NodeListImpl<Statement> statements = block.statements;
        // not call super.dispose
        if (this is MustCallSuperDispose && statements.isEmpty) {
          return node;
        }

        for (final Statement statement in statements) {
          if (statement is ExpressionStatementImpl &&
              statement.expression.toString() == 'super.dispose()') {
            callSuperDispose = true;
            // not call super.dispose at the end of this method
            if (this is EndCallSuperDispose && statement != statements.last) {
              return statement;
            }
          }
        }
      } else if (element.value.toString() == 'super.dispose()') {
        callSuperDispose = true;
      }
    }
    // not call super.dispose
    if (this is MustCallSuperDispose && !callSuperDispose) {
      return node;
    }
    return null;
  }
}

class _SyntacticEntity extends SyntacticEntity {
  _SyntacticEntity(this.offset, this.end) : length = end - offset;
  @override
  final int offset;

  @override
  final int length;

  @override
  final int end;
}

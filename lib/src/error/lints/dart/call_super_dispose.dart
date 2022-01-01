// ignore_for_file: implementation_imports

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:candies_analyzer_plugin/src/config.dart';
import 'package:candies_analyzer_plugin/src/error/error/dart.dart';

import 'dart_lint.dart';

class MustCallSuperDispose extends DartLint with CallSuperDisposeMixin {
  @override
  String get code => 'must_call_super_dispose';
  @override
  Future<List<SourceChange>> getDartFixes(
    DartAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async {
    final ResolvedUnitResult resolvedUnitResult = error.result;
    final AstNode astNode = error.astNode;

    final AstNode? result = _matchLint(astNode as MethodDeclarationImpl);

    final Iterable<DartAnalysisError> cacheErrors = config
        .getCacheErrors(resolvedUnitResult.path, code: code)
        .whereType<DartAnalysisError>()
        .where((DartAnalysisError element) {
      final AstNode astNode = element.astNode;
      return _hasFix(astNode) &&
          _matchLint(astNode as MethodDeclarationImpl) == astNode;
    });

    return <SourceChange>[
      if (_hasFix(astNode) && result == astNode)
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'call super.dispose',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            _fix(dartFileEditBuilder, astNode);
          },
        ),
      if (cacheErrors.length > 1)
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'call super.dispose where possible in file.',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            for (final DartAnalysisError error in cacheErrors) {
              _fix(
                dartFileEditBuilder,
                error.astNode as MethodDeclarationImpl,
              );
            }
          },
        ),
    ];
  }
}

class EndCallSuperDispose extends DartLint with CallSuperDisposeMixin {
  @override
  String get code => 'end_call_super_dispose';

  @override
  Future<List<SourceChange>> getDartFixes(
    DartAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async {
    final ResolvedUnitResult resolvedUnitResult = error.result;
    final AstNode astNode = error.astNode;

    final AstNode? result = _matchLint(astNode as MethodDeclarationImpl);

    final Iterable<DartAnalysisError> cacheErrors = config
        .getCacheErrors(resolvedUnitResult.path, code: code)
        .whereType<DartAnalysisError>()
        .where((DartAnalysisError element) {
      final AstNode astNode = element.astNode;
      return _hasFix(astNode) &&
          _matchLint(astNode as MethodDeclarationImpl)
              is ExpressionStatementImpl;
    });

    return <SourceChange>[
      if (_hasFix(astNode) && result is ExpressionStatementImpl)
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'call super.dispose at the end of this method.',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            _fix1(dartFileEditBuilder, result, astNode);
          },
        ),
      if (cacheErrors.length > 1)
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message:
              'call super.dispose at the end of this method where possible in file.',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            for (final DartAnalysisError error in cacheErrors) {
              _fix1(
                dartFileEditBuilder,
                _matchLint(error.astNode as MethodDeclarationImpl)
                    as ExpressionStatementImpl,
                error.astNode as MethodDeclarationImpl,
              );
            }
          },
        ),
    ];
  }
}

mixin CallSuperDisposeMixin on DartLint {
  @override
  String get message =>
      'Implementations of this method should end with a call to the inherited method, as in `super.dispose()`';

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

void _fix1(DartFileEditBuilder dartFileEditBuilder,
    ExpressionStatementImpl result, MethodDeclarationImpl astNode) {
  dartFileEditBuilder.addSimpleReplacement(
      SourceRange(
        result.offset,
        result.length,
      ),
      '');
  dartFileEditBuilder.addSimpleInsertion(astNode.end - 1, 'super.dispose();');
  dartFileEditBuilder.format(SourceRange(
    astNode.offset,
    astNode.length,
  ));
}

void _fix(
    DartFileEditBuilder dartFileEditBuilder, MethodDeclarationImpl astNode) {
  dartFileEditBuilder.addSimpleInsertion(astNode.end - 1, 'super.dispose();');
  dartFileEditBuilder.format(
    SourceRange(
      astNode.offset,
      astNode.length,
    ),
  );
}

bool _hasFix(AstNode astNode) {
  return astNode is MethodDeclarationImpl &&
      astNode.body is BlockFunctionBodyImpl;
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

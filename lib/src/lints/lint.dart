// ignore_for_file: implementation_imports

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/src/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_yaml.dart';
import 'package:candies_lints/src/extension.dart';
import 'package:candies_lints/src/ignore_info.dart';
import 'package:candies_lints/src/log.dart';

abstract class CandyLint {
  /// The severity of the error.
  AnalysisErrorSeverity get severity => AnalysisErrorSeverity.INFO;

  /// The type of the error.
  AnalysisErrorType get type => AnalysisErrorType.LINT;

  /// The location associated with the error.
  //Location location;

  /// The message to be displayed for this error. The message should indicate
  /// what is wrong with the code and why it is wrong.
  String get message;

  /// The correction message to be displayed for this error. The correction
  /// message should indicate how the user can fix the error. The field is
  /// omitted if there is no correction message associated with the error code.
  String? get correction => null;

  /// The name, as a string, of the error code associated with this error.
  String get code;

  /// The URL of a page containing documentation associated with this error.
  String? get url => null;

  /// Additional messages associated with this diagnostic that provide context
  /// to help the user understand the diagnostic.
  List<DiagnosticMessage>? get contextMessages => null;

  /// A hint to indicate to interested clients that this error has an
  /// associated fix (or fixes). The absence of this field implies there are
  /// not known to be fixes. Note that since the operation to calculate whether
  /// fixes apply needs to be performant it is possible that complicated tests
  /// will be skipped and a false negative returned. For this reason, this
  /// attribute should be treated as a "hint". Despite the possibility of false
  /// negatives, no false positives should be returned. If a client sees this
  /// flag set they can proceed with the confidence that there are in fact
  /// associated fixes.
  //bool? get hasFix => false;

  Iterable<AnalysisError> toAnalysisErrors({
    required ResolvedUnitResult result,
    required CandiesLintsIgnoreInfo ignore,
  }) sync* {
    final Map<SyntacticEntity, AstNode> copy = <SyntacticEntity, AstNode>{};
    copy.addAll(_astNodes);
    if (copy.isNotEmpty) {
      CandiesLintsLogger().log(
        'find ${copy.length} lint($code) at ${result.path}',
        root: result.root,
      );
    }
    _astNodes.clear();
    for (final SyntacticEntity syntacticEntity in copy.keys) {
      final Location location = astNodeToLocation(
        result,
        syntacticEntity,
      );
      if (!ignore.ignoredAt(code, location.startLine)) {
        yield toAnalysisError(
          result: result,
          location: location,
        );
      } else {
        CandiesLintsLogger().log(
          'ignore code: $code at ${result.lineNumber(syntacticEntity.offset)} line in ${result.path}',
          root: result.root,
        );
      }
    }
  }

  Stream<AnalysisErrorFixes> toAnalysisErrorFixesStream({
    required ResolvedUnitResult result,
    required EditGetFixesParams parameters,
    required CandiesLintsIgnoreInfo ignore,
  }) async* {
    final Map<SyntacticEntity, AstNode> copy = <SyntacticEntity, AstNode>{};
    copy.addAll(_astNodes);
    _astNodes.clear();
    for (final SyntacticEntity syntacticEntity in copy.keys) {
      if (syntacticEntity.offset <= parameters.offset &&
          parameters.offset <= syntacticEntity.end) {
        final Location location = astNodeToLocation(
          result,
          syntacticEntity,
        );
        if (!ignore.ignoredAt(code, location.startLine)) {
          yield await toAnalysisErrorFixes(
            result: result,
            node: copy[syntacticEntity]!,
            location: location,
            ignore: ignore,
          );
        } else {
          CandiesLintsLogger().log(
            'ignore code: $code at ${result.lineNumber(syntacticEntity.offset)} line in ${parameters.file}',
            root: result.root,
          );
        }
      }
    }
  }

  Future<AnalysisErrorFixes> toAnalysisErrorFixes({
    required AstNode node,
    required ResolvedUnitResult result,
    required Location location,
    required CandiesLintsIgnoreInfo ignore,
  }) async {
    List<SourceChange> fixes = await getFixes(
      result,
      node,
    );

    fixes.add(
      await ignoreForThisLine(
        resolvedUnitResult: result,
        ignore: ignore,
        code: code,
        location: location,
      ),
    );

    fixes.add(
      await ignoreForThisFile(
        resolvedUnitResult: result,
        ignore: ignore,
      ),
    );

    fixes = fixes.reversed.toList();

    CandiesLintsLogger().log(
      'get ${fixes.length} fixes for lint($code) at ${result.path}',
      root: result.root,
    );

    return AnalysisErrorFixes(
      toAnalysisError(
        result: result,
        location: location,
      ),
      fixes: <PrioritizedSourceChange>[
        for (int i = 0; i < fixes.length; i++)
          PrioritizedSourceChange(i, fixes[i])
      ],
    );
  }

  Future<SourceChange> ignoreForThisFile({
    required ResolvedUnitResult resolvedUnitResult,
    required CandiesLintsIgnoreInfo ignore,
  }) {
    return getFix(
      resolvedUnitResult: resolvedUnitResult,
      message: 'Ignore \'$code\' for this file',
      buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
        ignore.fixIgnoreForThisFile(
          code,
          dartFileEditBuilder: dartFileEditBuilder,
        );
      },
    );
  }

  Future<SourceChange> ignoreForThisLine({
    required ResolvedUnitResult resolvedUnitResult,
    required CandiesLintsIgnoreInfo ignore,
    required Location location,
    required String code,
  }) {
    return getFix(
      resolvedUnitResult: resolvedUnitResult,
      message: 'Ignore \'$code\' for this line',
      buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
        ignore.fixIgnoreForThisLine(
          code,
          location,
          dartFileEditBuilder: dartFileEditBuilder,
        );
      },
    );
  }

  Future<SourceChange> getFix({
    required ResolvedUnitResult resolvedUnitResult,
    required String message,
    void Function(DartFileEditBuilder builder)? buildDartFileEdit,
    void Function(YamlFileEditBuilder builder)? buildYamlFileEdit,
    void Function(FileEditBuilder builder)? buildGenericFileEdit,
    ImportPrefixGenerator? importPrefixGenerator,
  }) async {
    final ChangeBuilderImpl changeBuilder =
        ChangeBuilderImpl(session: resolvedUnitResult.session);
    if (buildDartFileEdit != null) {
      await changeBuilder.addDartFileEdit(
        resolvedUnitResult.libraryElement.source.fullName,
        buildDartFileEdit,
        importPrefixGenerator: importPrefixGenerator,
      );
    } else if (buildYamlFileEdit != null) {
      await changeBuilder.addYamlFileEdit(
        resolvedUnitResult.libraryElement.source.fullName,
        buildYamlFileEdit,
      );
    } else if (buildGenericFileEdit != null) {
      await changeBuilder.addGenericFileEdit(
        resolvedUnitResult.libraryElement.source.fullName,
        buildGenericFileEdit,
      );
    }
    final SourceChange sourceChange = changeBuilder.sourceChange;
    sourceChange.message = message;
    return sourceChange;
  }

  /// Quick fix for lint
  Future<List<SourceChange>> getFixes(
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async =>
      <SourceChange>[];

  AnalysisError toAnalysisError({
    required ResolvedUnitResult result,
    required Location location,
  }) {
    CandiesLintsLogger().log(
      'find error: $code at ${location.startLine} line in ${result.path}',
      root: result.root,
    );
    return AnalysisError(
      severity,
      type,
      location,
      message,
      code,
      correction: correction,
      contextMessages: contextMessages,
      url: url,
      //hasFix: hasFix,
    );
  }

  Location astNodeToLocation(ResolvedUnitResult result, SyntacticEntity node) {
    final CharacterLocation startLocation =
        result.lineInfo.getLocation(node.offset);
    final CharacterLocation endLocation = result.lineInfo.getLocation(node.end);
    return Location(
      result.path,
      node.offset,
      node.length,
      startLocation.lineNumber,
      startLocation.columnNumber,
      endLine: endLocation.lineNumber,
      endColumn: endLocation.columnNumber,
    );
  }

  final Map<SyntacticEntity, AstNode> _astNodes = <SyntacticEntity, AstNode>{};

  bool analyze(AstNode node) {
    if (!_astNodes.containsKey(node) &&
        _astNodes.keys
            .where(
              (SyntacticEntity element) => element.offset == node.offset,
            )
            .isEmpty) {
      final SyntacticEntity? syntacticEntity = matchLint(node);
      if (syntacticEntity != null) {
        _astNodes[syntacticEntity] = node;
        return true;
      }
    }
    return false;
  }

  SyntacticEntity? matchLint(AstNode node);
}

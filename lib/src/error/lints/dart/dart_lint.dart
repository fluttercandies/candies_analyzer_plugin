// ignore_for_file: implementation_imports

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/src/utilities/change_builder/change_builder_core.dart';
import 'package:candies_analyzer_plugin/src/error/error/dart.dart';
import 'package:candies_analyzer_plugin/src/error/lints/lint.dart';
import 'package:candies_analyzer_plugin/src/extension.dart';
import 'package:candies_analyzer_plugin/src/ignore_info.dart';
import 'package:candies_analyzer_plugin/src/log.dart';
import 'package:candies_analyzer_plugin/src/config.dart';

/// The dart lint base
abstract class DartLint extends CandyLint {
  bool get addIgnoreForThisLineFix => true;
  bool get addIgnoreForThisFileFix => true;

  Iterable<DartAnalysisError> toDartAnalysisErrors({
    required ResolvedUnitResult result,
    required CandiesAnalyzerPluginIgnoreInfo ignoreInfo,
    required CandiesAnalyzerPluginConfig? config,
  }) sync* {
    final Map<SyntacticEntity, AstNode> copy = <SyntacticEntity, AstNode>{};
    copy.addAll(_astNodes);
    _astNodes.clear();
    final List<DartAnalysisError> errors = <DartAnalysisError>[];
    _cacheErrorsForFixes[result.path] = errors;
    CandiesAnalyzerPluginLogger().log(
      'find ${copy.length} lint($code) at ${result.path}',
      root: result.root,
    );
    for (final SyntacticEntity syntacticEntity in copy.keys) {
      final Location location = astNodeToLocation(
        result,
        syntacticEntity,
      );
      if (!ignoreInfo.ignoredAt(code, location.startLine)) {
        final DartAnalysisError error = toDartAnalysisError(
          result: result,
          location: location,
          astNode: copy[syntacticEntity]!,
          ignoreInfo: ignoreInfo,
          config: config,
        );
        errors.add(error);
        yield error;
      } else {
        CandiesAnalyzerPluginLogger().log(
          'ignore code: $code at ${result.lineNumber(syntacticEntity.offset)} line in ${result.path}',
          root: result.root,
        );
      }
    }
  }

  Stream<AnalysisErrorFixes> toDartAnalysisErrorFixesStream({
    required EditGetFixesParams parameters,
    required AnalysisContext analysisContext,
  }) async* {
    final List<DartAnalysisError>? errors =
        _cacheErrorsForFixes[parameters.file];
    if (errors != null) {
      for (final DartAnalysisError error in errors) {
        if (error.location.offset <= parameters.offset &&
            parameters.offset <=
                error.location.offset + error.location.length) {
          yield await toAnalysisErrorFixes(error: error);
        }
      }
    }
  }

  Future<AnalysisErrorFixes> toAnalysisErrorFixes(
      {required DartAnalysisError error}) async {
    List<SourceChange> fixes = await getDartFixes(
      error.result,
      error.astNode,
    );

    if (addIgnoreForThisLineFix) {
      fixes.add(await ignoreForThisLine(
        resolvedUnitResult: error.result,
        ignore: error.ignoreInfo,
        code: code,
        location: error.location,
      ));
    }

    if (addIgnoreForThisFileFix) {
      fixes.add(await ignoreForThisFile(
        resolvedUnitResult: error.result,
        ignore: error.ignoreInfo,
      ));
    }

    fixes = fixes.reversed.toList();

    CandiesAnalyzerPluginLogger().log(
      'get ${fixes.length} fixes for lint($code) at ${error.result.path}',
      root: error.result.root,
    );

    return AnalysisErrorFixes(
      error,
      fixes: <PrioritizedSourceChange>[
        for (int i = 0; i < fixes.length; i++)
          PrioritizedSourceChange(i, fixes[i])
      ],
    );
  }

  Future<SourceChange> ignoreForThisFile({
    required ResolvedUnitResult resolvedUnitResult,
    required CandiesAnalyzerPluginIgnoreInfo ignore,
  }) {
    return getDartFix(
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
    required CandiesAnalyzerPluginIgnoreInfo ignore,
    required Location location,
    required String code,
  }) {
    return getDartFix(
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

  Future<SourceChange> getDartFix({
    required ResolvedUnitResult resolvedUnitResult,
    required String message,
    required void Function(DartFileEditBuilder builder) buildDartFileEdit,
    // void Function(YamlFileEditBuilder builder)? buildYamlFileEdit,
    // void Function(FileEditBuilder builder)? buildGenericFileEdit,
    ImportPrefixGenerator? importPrefixGenerator,
  }) async {
    final ChangeBuilderImpl changeBuilder =
        ChangeBuilderImpl(session: resolvedUnitResult.session);

    await changeBuilder.addDartFileEdit(
      resolvedUnitResult.libraryElement.source.fullName,
      buildDartFileEdit,
      importPrefixGenerator: importPrefixGenerator,
    );
    final SourceChange sourceChange = changeBuilder.sourceChange;
    sourceChange.message = message;
    return sourceChange;
  }

  /// Quick fix for lint
  Future<List<SourceChange>> getDartFixes(
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async =>
      <SourceChange>[];

  DartAnalysisError toDartAnalysisError({
    required ResolvedUnitResult result,
    required Location location,
    required AstNode astNode,
    required CandiesAnalyzerPluginIgnoreInfo ignoreInfo,
    required CandiesAnalyzerPluginConfig? config,
  }) {
    CandiesAnalyzerPluginLogger().log(
      'find error: $code at ${location.startLine} line in ${result.path}',
      root: result.root,
    );
    return DartAnalysisError(
      config?.getSeverity(this) ?? severity,
      type,
      location,
      message,
      code,
      correction: correction,
      contextMessages: contextMessages,
      url: url,
      astNode: astNode,
      result: result,
      ignoreInfo: ignoreInfo,
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

  final Map<String, List<DartAnalysisError>> _cacheErrorsForFixes =
      <String, List<DartAnalysisError>>{};

  List<DartAnalysisError>? clearCacheErrors(String path) {
    return _cacheErrorsForFixes.remove(path);
  }

  List<DartAnalysisError>? getCacheErrors(String path) {
    return _cacheErrorsForFixes[path];
  }

  Iterable<DartAnalysisError> getAllCacheErrors() sync* {
    for (final List<DartAnalysisError> errors in _cacheErrorsForFixes.values) {
      yield* errors;
    }
  }

  bool analyze(AstNode node) {
    if (!_astNodes.containsKey(node) &&
        _astNodes.keys
            .where(
              (SyntacticEntity element) => element.offset == node.offset,
            )
            .isEmpty) {
      final SyntacticEntity? syntacticEntity = matchLint(node);
      if (syntacticEntity != null) {
        if (ignoreLint(syntacticEntity, node)) {
          return false;
        }
        _astNodes[syntacticEntity] = node;
        return true;
      }
    }
    return false;
  }

  /// call this if [DartLint].astVisitor is null
  /// and use [CandiesAnalyzerPlugin].astVisitor [CandiesLintsAstVisitor]
  SyntacticEntity? matchLint(AstNode node);

  /// report lint if you use  [DartLint].astVisitor
  void reportLint(SyntacticEntity offset, AstNode node) {
    if (!_astNodes.containsKey(node) &&
        _astNodes.keys
            .where(
              (SyntacticEntity element) =>
                  element.offset == offset.offset &&
                  element.length == offset.length,
            )
            .isEmpty) {
      if (ignoreLint(offset, node)) {
        return;
      }
      _astNodes[offset] = node;
    }
  }

  // bool reportError(
  //   String path,
  //   DartAnalysisError error, {
  //   bool insert = false,
  //   bool remove = false,
  // }) {
  //   final List<DartAnalysisError> list =
  //       _cacheErrorsForFixes.putIfAbsent(path, () => <DartAnalysisError>[]);

  //   remove = remove ||
  //       ignoreFile(error.result) ||
  //       error.ignoreInfo.ignoredAt(
  //         code,
  //         error.location.startLine,
  //       );

  //   CandiesAnalyzerPluginLogger().log(
  //     '${remove ? 'remove' : 'add'} $code: $path',
  //     root: error.result.root,
  //   );

  //   if (remove) {
  //     list.removeWhere((DartAnalysisError element) =>
  //         element.code == error.code && element.location == error.location);
  //     return true;
  //   }

  //   for (final DartAnalysisError element in list) {
  //     // same error
  //     if (element.code == error.code && element.location == error.location) {
  //       return false;
  //     }
  //   }

  //   if (insert) {
  //     list.insert(0, error);
  //   } else {
  //     list.add(error);
  //   }
  //   return false;
  // }

  /// if has, do not use use CandiesAnalyzerPlugin.astVisitor [CandiesLintsAstVisitor]
  AstVisitor<void>? get astVisitor => null;

  /// if you want to ignore this error
  bool ignoreLint(SyntacticEntity offset, AstNode node) => false;

  /// if you want to ignore analysis this file
  bool ignoreFile(ResolvedUnitResult result) => false;

  void accept(
      ResolvedUnitResult result, CandiesAnalyzerPluginIgnoreInfo ignoreInfo) {
    final AstVisitor<void>? _astVisitor = astVisitor;
    if (_astVisitor != null) {
      result.unit.accept(_astVisitor);
    }
  }
}

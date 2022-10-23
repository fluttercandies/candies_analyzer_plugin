import 'package:candies_lints/src/lints/lint.dart';

/// The yaml lint base
abstract class GenericLint extends CandyLint {
  // Iterable<AnalysisError> toDartAnalysisErrors({
  //   required String content,
  //   required CandiesLintsConfig? config,
  // }) sync* {
  //   final Map<SyntacticEntity, AstNode> copy = <SyntacticEntity, AstNode>{};
  //   copy.addAll(_astNodes);
  //   if (copy.isNotEmpty) {
  //     CandiesLintsLogger().log(
  //       'find ${copy.length} lint($code) at ${result.path}',
  //       root: result.root,
  //     );
  //   }
  //   _astNodes.clear();
  //   final List<DartAnalysisError> errors = <DartAnalysisError>[];
  //   _cacheErrorsForFixes[result.path] = errors;
  //   for (final SyntacticEntity syntacticEntity in copy.keys) {
  //     final Location location = astNodeToLocation(
  //       result,
  //       syntacticEntity,
  //     );
  //     if (!ignoreInfo.ignoredAt(code, location.startLine)) {
  //       final DartAnalysisError error = toDartAnalysisError(
  //         result: result,
  //         location: location,
  //         astNode: copy[syntacticEntity]!,
  //         ignoreInfo: ignoreInfo,
  //         config: config,
  //       );
  //       errors.add(error);
  //       yield error;
  //     } else {
  //       CandiesLintsLogger().log(
  //         'ignore code: $code at ${result.lineNumber(syntacticEntity.offset)} line in ${result.path}',
  //         root: result.root,
  //       );
  //     }
  //   }
  // }

  // Stream<AnalysisErrorFixes> toDartAnalysisErrorFixesStream(
  //     {required EditGetFixesParams parameters}) async* {
  //   final List<DartAnalysisError>? errors =
  //       _cacheErrorsForFixes[parameters.file];
  //   if (errors != null) {
  //     for (final DartAnalysisError error in errors) {
  //       if (error.location.offset <= parameters.offset &&
  //           parameters.offset <=
  //               error.location.offset + error.location.length) {
  //         yield await toAnalysisErrorFixes(error: error);
  //       }
  //     }
  //   }
  // }

  // Future<AnalysisErrorFixes> toAnalysisErrorFixes(
  //     {required DartAnalysisError error}) async {
  //   List<SourceChange> fixes = await getDartFixes(
  //     error.result,
  //     error.astNode,
  //   );

  //   fixes.add(
  //     await ignoreForThisLine(
  //       resolvedUnitResult: error.result,
  //       ignore: error.ignoreInfo,
  //       code: code,
  //       location: error.location,
  //     ),
  //   );

  //   fixes.add(
  //     await ignoreForThisFile(
  //       resolvedUnitResult: error.result,
  //       ignore: error.ignoreInfo,
  //     ),
  //   );

  //   fixes = fixes.reversed.toList();

  //   CandiesLintsLogger().log(
  //     'get ${fixes.length} fixes for lint($code) at ${error.result.path}',
  //     root: error.result.root,
  //   );

  //   return AnalysisErrorFixes(
  //     error,
  //     fixes: <PrioritizedSourceChange>[
  //       for (int i = 0; i < fixes.length; i++)
  //         PrioritizedSourceChange(i, fixes[i])
  //     ],
  //   );
  // }

  // Future<SourceChange> ignoreForThisFile({
  //   required ResolvedUnitResult resolvedUnitResult,
  //   required CandiesLintsIgnoreInfo ignore,
  // }) {
  //   return getDartFix(
  //     resolvedUnitResult: resolvedUnitResult,
  //     message: 'Ignore \'$code\' for this file',
  //     buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
  //       ignore.fixIgnoreForThisFile(
  //         code,
  //         dartFileEditBuilder: dartFileEditBuilder,
  //       );
  //     },
  //   );
  // }

  // Future<SourceChange> ignoreForThisLine({
  //   required ResolvedUnitResult resolvedUnitResult,
  //   required CandiesLintsIgnoreInfo ignore,
  //   required Location location,
  //   required String code,
  // }) {
  //   return getDartFix(
  //     resolvedUnitResult: resolvedUnitResult,
  //     message: 'Ignore \'$code\' for this line',
  //     buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
  //       ignore.fixIgnoreForThisLine(
  //         code,
  //         location,
  //         dartFileEditBuilder: dartFileEditBuilder,
  //       );
  //     },
  //   );
  // }

  // Future<SourceChange> getDartFix({
  //   required ResolvedUnitResult resolvedUnitResult,
  //   required String message,
  //   void Function(DartFileEditBuilder builder)? buildDartFileEdit,
  //   void Function(YamlFileEditBuilder builder)? buildYamlFileEdit,
  //   void Function(FileEditBuilder builder)? buildGenericFileEdit,
  //   ImportPrefixGenerator? importPrefixGenerator,
  // }) async {
  //   final ChangeBuilderImpl changeBuilder =
  //       ChangeBuilderImpl(session: resolvedUnitResult.session);
  //   if (buildDartFileEdit != null) {
  //     await changeBuilder.addDartFileEdit(
  //       resolvedUnitResult.libraryElement.source.fullName,
  //       buildDartFileEdit,
  //       importPrefixGenerator: importPrefixGenerator,
  //     );
  //   } else if (buildYamlFileEdit != null) {
  //     await changeBuilder.addYamlFileEdit(
  //       resolvedUnitResult.libraryElement.source.fullName,
  //       buildYamlFileEdit,
  //     );
  //   } else if (buildGenericFileEdit != null) {
  //     await changeBuilder.addGenericFileEdit(
  //       resolvedUnitResult.libraryElement.source.fullName,
  //       buildGenericFileEdit,
  //     );
  //   }
  //   final SourceChange sourceChange = changeBuilder.sourceChange;
  //   sourceChange.message = message;
  //   return sourceChange;
  // }

  // /// Quick fix for lint
  // Future<List<SourceChange>> getDartFixes(
  //   ResolvedUnitResult resolvedUnitResult,
  //   AstNode astNode,
  // ) async =>
  //     <SourceChange>[];

  // DartAnalysisError toDartAnalysisError({
  //   required ResolvedUnitResult result,
  //   required Location location,
  //   required AstNode astNode,
  //   required CandiesLintsIgnoreInfo ignoreInfo,
  //   required CandiesLintsConfig? config,
  // }) {
  //   CandiesLintsLogger().log(
  //     'find error: $code at ${location.startLine} line in ${result.path}',
  //     root: result.root,
  //   );
  //   return DartAnalysisError(
  //     config?.getSeverity(this) ?? severity,
  //     type,
  //     location,
  //     message,
  //     code,
  //     correction: correction,
  //     contextMessages: contextMessages,
  //     url: url,
  //     astNode: astNode,
  //     result: result,
  //     ignoreInfo: ignoreInfo,
  //     //hasFix: hasFix,
  //   );
  // }

  // Location astNodeToLocation(ResolvedUnitResult result, SyntacticEntity node) {
  //   final CharacterLocation startLocation =
  //       result.lineInfo.getLocation(node.offset);
  //   final CharacterLocation endLocation = result.lineInfo.getLocation(node.end);
  //   return Location(
  //     result.path,
  //     node.offset,
  //     node.length,
  //     startLocation.lineNumber,
  //     startLocation.columnNumber,
  //     endLine: endLocation.lineNumber,
  //     endColumn: endLocation.columnNumber,
  //   );
  // }

  // final Map<SyntacticEntity, AstNode> _astNodes = <SyntacticEntity, AstNode>{};

  // final Map<String, List<AnalysisError>> _cacheErrorsForFixes =
  //     <String, List<AnalysisError>>{};

  // List<AnalysisError>? clearCacheErrors(String path) {
  //   return _cacheErrorsForFixes.remove(path);
  // }

  // bool analyze(AstNode node) {
  //   if (!_astNodes.containsKey(node) &&
  //       _astNodes.keys
  //           .where(
  //             (SyntacticEntity element) => element.offset == node.offset,
  //           )
  //           .isEmpty) {
  //     final SyntacticEntity? syntacticEntity = matchLint(node);
  //     if (syntacticEntity != null) {
  //       _astNodes[syntacticEntity] = node;
  //       return true;
  //     }
  //   }

  //   return false;
  // }

  // SourceRange? matchLint(String content);
}

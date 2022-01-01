import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:candies_analyzer_plugin/src/config.dart';
import 'package:candies_analyzer_plugin/src/error/error/generic.dart';
import 'package:candies_analyzer_plugin/src/extension.dart';
import 'package:candies_analyzer_plugin/src/log.dart';
import 'package:path/path.dart' as path_package;

import 'lint.dart';

/// The generic lint base
abstract class GenericLint extends CandyLint {
  Iterable<GenericAnalysisError> toGenericAnalysisErrors({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesAnalyzerPluginConfig config,
    required String content,
    required LineInfo lineInfo,
  }) sync* {
    final List<SourceRange> nodes = matchLint(
      content,
      path,
      lineInfo,
    ).toList();

    CandiesAnalyzerPluginLogger().log(
      'find ${nodes.length} yaml lint($code) at $path',
      root: analysisContext.root,
    );

    final List<GenericAnalysisError> errors = <GenericAnalysisError>[];
    _cacheErrorsForFixes[path] = errors;
    for (final SourceRange node in nodes) {
      final Location location = sourceSpanToLocation(
        path,
        node,
        lineInfo,
      );

      final GenericAnalysisError error = toGenericAnalysisError(
        analysisContext: analysisContext,
        path: path,
        location: location,
        config: config,
        content: content,
      );
      errors.add(error);
      yield error;
    }
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Stream<AnalysisErrorFixes> toGenericAnalysisErrorFixesStream({
    required EditGetFixesParams parameters,
    required AnalysisContext analysisContext,
    required CandiesAnalyzerPluginConfig config,
  }) async* {
    final List<GenericAnalysisError>? errors =
        _cacheErrorsForFixes[parameters.file];
    if (errors != null) {
      for (final GenericAnalysisError error in errors) {
        if (error.location.offset <= parameters.offset &&
            parameters.offset <=
                error.location.offset + error.location.length) {
          yield await toGenericAnalysisErrorFixes(
            error: error,
            path: parameters.file,
            analysisContext: analysisContext,
            config: config,
          );
        }
      }
    }
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Future<AnalysisErrorFixes> toGenericAnalysisErrorFixes({
    required GenericAnalysisError error,
    required AnalysisContext analysisContext,
    required String path,
    required CandiesAnalyzerPluginConfig config,
  }) async {
    List<SourceChange> fixes = await getGenericFixes(
      analysisContext,
      path,
      error,
      config,
    );

    if (fixes.isNotEmpty) {
      fixes = fixes.reversed.toList();
    }

    CandiesAnalyzerPluginLogger().log(
      'get ${fixes.length} fixes for yaml lint($code) at $path',
      root: analysisContext.root,
    );

    return AnalysisErrorFixes(
      error,
      fixes: <PrioritizedSourceChange>[
        for (int i = 0; i < fixes.length; i++)
          PrioritizedSourceChange(i, fixes[i])
      ],
    );
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Future<SourceChange> getGenericFix({
    required AnalysisContext analysisContext,
    required String path,
    required String message,
    required void Function(FileEditBuilder builder) buildFileEdit,
  }) async {
    final ChangeBuilder changeBuilder =
        ChangeBuilder(session: analysisContext.currentSession);

    await changeBuilder.addGenericFileEdit(
      path,
      buildFileEdit,
    );

    final SourceChange sourceChange = changeBuilder.sourceChange;
    sourceChange.message = message;
    return sourceChange;
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Future<List<SourceChange>> getGenericFixes(
    AnalysisContext analysisContext,
    String path,
    GenericAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async =>
      <SourceChange>[];

  GenericAnalysisError toGenericAnalysisError({
    required AnalysisContext analysisContext,
    required String path,
    required Location location,
    required CandiesAnalyzerPluginConfig config,
    required String content,
  }) {
    CandiesAnalyzerPluginLogger().log(
      'find error: $code at ${location.startLine} line in $path',
      root: analysisContext.root,
    );
    return GenericAnalysisError(
      config.getSeverity(this),
      type,
      location,
      message,
      code,
      correction: correction,
      contextMessages: contextMessages,
      url: url,
      content: content,
      //hasFix: hasFix,
    );
  }

  Location sourceSpanToLocation(
    String path,
    SourceRange sourceRange,
    LineInfo lineInfo,
  ) {
    final CharacterLocation startLocation =
        lineInfo.getLocation(sourceRange.offset);
    final CharacterLocation endLocation = lineInfo.getLocation(sourceRange.end);
    return Location(
      path,
      sourceRange.offset,
      sourceRange.length,
      startLocation.lineNumber,
      startLocation.columnNumber,
      endLine: endLocation.lineNumber,
      endColumn: endLocation.columnNumber,
    );
  }

  final Map<String, List<GenericAnalysisError>> _cacheErrorsForFixes =
      <String, List<GenericAnalysisError>>{};

  List<GenericAnalysisError>? clearCacheErrors(String path) {
    return _cacheErrorsForFixes.remove(path);
  }

  List<GenericAnalysisError>? getCacheErrors(String path) {
    return _cacheErrorsForFixes[path];
  }

  Iterable<GenericAnalysisError> getAllCacheErrors() sync* {
    for (final List<GenericAnalysisError> errors
        in _cacheErrorsForFixes.values) {
      yield* errors;
    }
  }

  Iterable<SourceRange> matchLint(
    String content,
    String file,
    LineInfo lineInfo,
  );

  bool isFileType({
    required String file,
    required String type,
  }) {
    return path_package.extension(file) == type;
  }
}

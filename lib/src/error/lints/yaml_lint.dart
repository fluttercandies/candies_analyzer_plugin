import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_yaml.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';

/// The yaml lint base
abstract class YamlLint extends CandyLint {
  Iterable<YamlAnalysisError> toYamlAnalysisErrors({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesAnalyzerPluginConfig config,
    required YamlNode root,
    required String content,
    required LineInfo lineInfo,
  }) sync* {
    final List<SourceRange> nodes = matchLint(
      root,
      content,
      lineInfo,
    ).toList();

    CandiesAnalyzerPluginLogger().log(
      'find ${nodes.length} yaml lint($code) at $path',
      root: analysisContext.root,
    );

    final List<YamlAnalysisError> errors = <YamlAnalysisError>[];
    _cacheErrorsForFixes[path] = errors;
    for (final SourceRange node in nodes) {
      final Location location = sourceSpanToLocation(
        path,
        node,
        lineInfo,
      );

      final YamlAnalysisError error = toYamlAnalysisError(
        analysisContext: analysisContext,
        path: path,
        location: location,
        config: config,
        root: root,
        content: content,
      );
      errors.add(error);
      yield error;
    }
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Stream<AnalysisErrorFixes> toYamlAnalysisErrorFixesStream({
    required EditGetFixesParams parameters,
    required AnalysisContext analysisContext,
    required CandiesAnalyzerPluginConfig config,
  }) async* {
    final List<YamlAnalysisError>? errors =
        _cacheErrorsForFixes[parameters.file];
    if (errors != null) {
      for (final YamlAnalysisError error in errors) {
        if (error.location.offset <= parameters.offset &&
            parameters.offset <=
                error.location.offset + error.location.length) {
          yield await toYamlAnalysisErrorFixes(
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
  Future<AnalysisErrorFixes> toYamlAnalysisErrorFixes({
    required YamlAnalysisError error,
    required AnalysisContext analysisContext,
    required String path,
    required CandiesAnalyzerPluginConfig config,
  }) async {
    List<SourceChange> fixes = await getYamlFixes(
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
  Future<SourceChange> getYamlFix({
    required AnalysisContext analysisContext,
    required String path,
    required String message,
    required void Function(YamlFileEditBuilder builder) buildYamlFileEdit,
  }) async {
    final ChangeBuilder changeBuilder =
        ChangeBuilder(session: analysisContext.currentSession);

    await changeBuilder.addYamlFileEdit(
      path,
      buildYamlFileEdit,
    );

    final SourceChange sourceChange = changeBuilder.sourceChange;
    sourceChange.message = message;
    return sourceChange;
  }

  /// It doesn't work for now.
  /// https://github.com/dart-lang/sdk/issues/50306
  /// leave it in case dart team maybe support it someday in the future
  Future<List<SourceChange>> getYamlFixes(
    AnalysisContext analysisContext,
    String path,
    YamlAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async =>
      <SourceChange>[];

  YamlAnalysisError toYamlAnalysisError({
    required AnalysisContext analysisContext,
    required String path,
    required Location location,
    required CandiesAnalyzerPluginConfig? config,
    required YamlNode root,
    required String content,
  }) {
    CandiesAnalyzerPluginLogger().log(
      'find error: $code at ${location.startLine} line in $path',
      root: analysisContext.root,
    );
    return YamlAnalysisError(
      config?.getSeverity(this) ?? severity,
      type,
      location,
      message,
      code,
      correction: correction,
      contextMessages: contextMessages,
      url: url,
      content: content,
      root: root,
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

  final Map<String, List<YamlAnalysisError>> _cacheErrorsForFixes =
      <String, List<YamlAnalysisError>>{};

  List<YamlAnalysisError>? clearCacheErrors(String path) {
    return _cacheErrorsForFixes.remove(path);
  }

  List<YamlAnalysisError>? getCacheErrors(String path) {
    return _cacheErrorsForFixes[path];
  }

  Iterable<YamlAnalysisError> getAllCacheErrors() sync* {
    for (final List<YamlAnalysisError> errors in _cacheErrorsForFixes.values) {
      yield* errors;
    }
  }

  Iterable<SourceRange> matchLint(
    YamlNode root,
    String content,
    LineInfo lineInfo,
  );
}

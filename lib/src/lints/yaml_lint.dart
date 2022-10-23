import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_yaml.dart';
import 'package:candies_lints/candies_lints.dart';

/// The yaml lint base
abstract class YamlLint extends CandyLint {
  Iterable<YamlAnalysisError> toYamlAnalysisErrors({
    required AnalysisContext analysisContext,
    required String path,
    required CandiesLintsConfig? config,
    required YamlNode root,
    required String content,
    required LineInfo lineInfo,
  }) sync* {
    final List<SourceRange> nodes = matchLint(
      root,
      content,
    );

    CandiesLintsLogger().log(
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

  Stream<AnalysisErrorFixes> toYamlAnalysisErrorFixesStream({
    required EditGetFixesParams parameters,
    required AnalysisContext analysisContext,
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
          );
        }
      }
    }
  }

  Future<AnalysisErrorFixes> toYamlAnalysisErrorFixes({
    required YamlAnalysisError error,
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    List<SourceChange> fixes = await getYamlFixes(
      analysisContext,
      path,
      error,
    );

    if (fixes.isNotEmpty) {
      fixes = fixes.reversed.toList();
    }

    CandiesLintsLogger().log(
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

  /// Quick fix for lint
  Future<List<SourceChange>> getYamlFixes(
    AnalysisContext analysisContext,
    String path,
    YamlAnalysisError error,
  ) async =>
      <SourceChange>[];

  YamlAnalysisError toYamlAnalysisError({
    required AnalysisContext analysisContext,
    required String path,
    required Location location,
    required CandiesLintsConfig? config,
    required YamlNode root,
    required String content,
  }) {
    CandiesLintsLogger().log(
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

  List<SourceRange> matchLint(YamlNode root, String content);
}

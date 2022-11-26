// ignore_for_file: unused_import, implementation_imports

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/plugin/completion_mixin.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/plugin/fix_mixin.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';
//import 'package:analyzer_plugin/src/utilities/fixes/fixes.dart';
import 'package:analyzer/error/error.dart' as error;
import 'package:candies_analyzer_plugin/src/completion/completion_mixin.dart';
import 'package:candies_analyzer_plugin/src/error/plugin/dart_mixin.dart';
import 'package:candies_analyzer_plugin/src/error/plugin/generic_mixin.dart';
import 'package:candies_analyzer_plugin/src/error/plugin/yaml_mixin.dart';
import 'package:path/path.dart' as path_package;
import 'package:analyzer/src/util/glob.dart';

part 'plugin_base.dart';

class CandiesAnalyzerPlugin extends ServerPlugin
    with
        CandiesDartFileErrorPlugin,
        CandiesYamlFileErrorPlugin,
        CandiesGenericFileErrorPlugin,
        CandiesCompletionPlugin,
        CandiesAnalyzerPluginBase {
  CandiesAnalyzerPlugin()
      : super(resourceProvider: PhysicalResourceProvider.INSTANCE) {
    CandiesAnalyzerPluginLogger().logFileName = logFileName;
  }

  /// Return the user visible name of this plugin.
  @override
  String get name => 'candies_analyzer_plugin';

  /// Return the version number of the plugin spec required by this plugin,
  /// encoded as a string.
  @override
  String get version => '1.0.0';

  /// Return a list of glob patterns selecting the files that this plugin is
  /// interested in analyzing.
  @override
  List<String> get fileGlobsToAnalyze => const <String>['**/*.dart'];

  /// Return the user visible information about how to contact the plugin authors
  /// with any problems that are found, or `null` if there is no contact info.
  @override
  String get contactInfo =>
      'https://github.com/fluttercandies/candies_analyzer_plugin';

  /// show lint with git author

  late AnalysisContextCollection _contextCollection;

  /// Handles files that might have been affected by a content change of
  /// one or more files. The implementation may check if these files should
  /// be analyzed, do such analysis, and send diagnostics.
  ///
  /// By default invokes [analyzeFiles] only for files that are analyzed in
  /// this [analysisContext].
  @override
  Future<void> handleAffectedFiles(
      {required AnalysisContext analysisContext, required List<String> paths}) {
    final List<String> analyzedPaths = paths
        .where(analysisContext.contextRoot.isAnalyzed)
        .toList(growable: false);
    if (analyzedPaths.isNotEmpty) {
      CandiesAnalyzerPluginLogger().log(
        'The files are changed: ${analyzedPaths.join('\n')}',
        root: analysisContext.root,
      );
    }
    return super
        .handleAffectedFiles(analysisContext: analysisContext, paths: paths);
  }

  /// Analyzes the given files.
  /// By default invokes [analyzeFile] for every file.
  /// Implementations may override to optimize for batch analysis.
  @override
  Future<void> analyzeFile(
      {required AnalysisContext analysisContext, required String path}) async {
    if (!shouldAnalyzeFile(path, analysisContext)) {
      return;
    }

    final bool isAnalyzed = analysisContext.contextRoot.isAnalyzed(path);
    if (!isAnalyzed) {
      return;
    }

    final CandiesAnalyzerPluginConfig? config = _configs[analysisContext.root];
    if (config != null && config.shouldAnalyze) {
      await saveAccessibleExtensions(
          analysisContext: analysisContext, path: path);
    }
    if (config == null || !config.shouldAnalyze || !config.include(path)) {
      config?.clearCacheErrors(path);
      // send a notification that we ignore the errors in this file.
      channel.sendNotification(
        AnalysisErrorsParams(path, <AnalysisError>[]).toNotification(),
      );
      return;
    }

    try {
      CandiesAnalyzerPluginLogger().log(
        'analyze file: $path',
        root: analysisContext.root,
      );

      final List<AnalysisError> errors =
          (await getAnalysisErrors(config, path, analysisContext)).toList();
      CandiesAnalyzerPluginLogger().log(
        'find ${errors.length} errors in $path',
        root: analysisContext.root,
      );

      await beforeSendAnalysisErrors(
        errors: errors,
        analysisContext: analysisContext,
        path: path,
        config: config,
      );
      // if errors is empty, we still need to send a notification
      // to clear errors if it has.
      channel.sendNotification(
        AnalysisErrorsParams(path, errors).toNotification(),
      );
    } on Exception catch (e, stackTrace) {
      CandiesAnalyzerPluginLogger().logError(
        'analyze file failed!',
        root: analysisContext.root,
        error: e,
        stackTrace: stackTrace,
      );
      channel.sendNotification(
        PluginErrorParams(false, e.toString(), stackTrace.toString())
            .toNotification(),
      );
    }
  }

  /// get analysis errors base on file type
  Future<Iterable<AnalysisError>> getAnalysisErrors(
    CandiesAnalyzerPluginConfig config,
    String path,
    AnalysisContext analysisContext,
  ) async {
    if (config.isDartFile(path)) {
      return await analyzeDartFile(
        analysisContext: analysisContext,
        path: path,
        config: config,
      );
    } else if (config.isYamlFile(path)) {
      return analyzeYamlFile(
        analysisContext: analysisContext,
        path: path,
        config: config,
      );
    } else {
      return analyzeGenericFile(
        analysisContext: analysisContext,
        path: path,
        config: config,
      );
    }
  }

  /// debug: get analysis errors
  Future<Iterable<AnalysisError>> getAnalysisErrorsForDebug(
    String path,
    AnalysisContext analysisContext,
  ) {
    final CandiesAnalyzerPluginConfig config =
        _configs[analysisContext.root] ??= CandiesAnalyzerPluginConfig(
      context: analysisContext,
      pluginName: name,
      dartLints: dartLints,
      astVisitor: astVisitor,
      yamlLints: yamlLints,
      genericLints: genericLints,
    );
    return getAnalysisErrors(config, path, analysisContext);
  }

  /// Handle an 'edit.getFixes' request.
  ///
  /// Throw a [RequestFailure] if the request could not be handled.
  @override
  Future<EditGetFixesResult> handleEditGetFixes(
      EditGetFixesParams parameters) async {
    final String path = parameters.file;
    final AnalysisContext context = _contextCollection.contextFor(path);
    if (!shouldAnalyzeFile(path, context)) {
      return EditGetFixesResult(const <AnalysisErrorFixes>[]);
    }

    try {
      //final ResolvedUnitResult unitResult = await getResolvedUnitResult(path);
      // CandiesAnalyzerPluginLogger()
      //     .log('start get fixes for $path', root: unitResult.root);
      // can't get candies error from ResolvedUnitResult.errors
      // so we can't use FixesMixin
      // CandiesAnalyzerPluginLogger().log(
      //     'has ${unitResult.errors.map((e) => e.errorCode)} errors for $path',
      //     root: unitResult.root);

      final String root = context.root;

      final CandiesAnalyzerPluginConfig? config = _configs[root];
      if (config == null || !config.shouldAnalyze || !config.include(path)) {
        CandiesAnalyzerPluginLogger().log(
          'skip get fixes for $path',
          root: root,
        );
        return EditGetFixesResult(const <AnalysisErrorFixes>[]);
      }

      CandiesAnalyzerPluginLogger().log(
        'start get fixes for $path',
        root: root,
      );

      final List<AnalysisErrorFixes> fixes =
          await getAnalysisErrorFixes(config, parameters, context).toList();

      CandiesAnalyzerPluginLogger().log(
        'get total ${fixes.length} fixes for $path',
        root: root,
      );
      return EditGetFixesResult(fixes);
    } on Exception catch (e, stackTrace) {
      // CandiesAnalyzerPluginLogger()
      //     .logError('get fixes failed: $e', root: unitResult.root);
      channel.sendNotification(
        PluginErrorParams(false, e.toString(), stackTrace.toString())
            .toNotification(),
      );
    }

    return EditGetFixesResult(const <AnalysisErrorFixes>[]);
  }

  /// debug: get analysis errors fixes
  Stream<AnalysisErrorFixes> getAnalysisErrorFixesForDebug(
    EditGetFixesParams parameters,
    AnalysisContext analysisContext,
  ) {
    final CandiesAnalyzerPluginConfig config =
        _configs[analysisContext.root] ??= CandiesAnalyzerPluginConfig(
      context: analysisContext,
      pluginName: name,
      dartLints: dartLints,
      astVisitor: astVisitor,
      yamlLints: yamlLints,
      genericLints: genericLints,
    );
    return getAnalysisErrorFixes(
      config,
      parameters,
      analysisContext,
    );
  }

  /// This method is invoked when a new instance of [AnalysisContextCollection]
  /// is created, so the plugin can perform initial analysis of analyzed files.
  ///
  /// By default analyzes every [AnalysisContext] with [analyzeFiles].
  @override
  Future<void> afterNewContextCollection({
    required AnalysisContextCollection contextCollection,
  }) async {
    _contextCollection = contextCollection;
    for (final AnalysisContext analysisContext in contextCollection.contexts) {
      final CandiesAnalyzerPluginConfig config = CandiesAnalyzerPluginConfig(
        context: analysisContext,
        pluginName: name,
        dartLints: dartLints,
        astVisitor: astVisitor,
        yamlLints: yamlLints,
        genericLints: genericLints,
      );

      if (config.shouldAnalyze) {
        _configs[analysisContext.root] = config;
        CandiesAnalyzerPluginLogger().log(
          'create a new config for ${analysisContext.root}',
          root: analysisContext.root,
        );
      }
    }
    await super.afterNewContextCollection(contextCollection: contextCollection);
  }

  @override
  Future<void> beforeContextCollectionDispose(
      {required AnalysisContextCollection contextCollection}) async {
    for (final AnalysisContext context in contextCollection.contexts) {
      _configs.remove(context.root);
    }
  }
}

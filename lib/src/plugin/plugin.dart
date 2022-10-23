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
import 'package:candies_lints/candies_lints.dart';
//import 'package:analyzer_plugin/src/utilities/fixes/fixes.dart';
import 'package:candies_lints/src/error/dart.dart';
import 'package:candies_lints/src/lints/lint.dart';
import 'package:analyzer/error/error.dart' as error;
import 'package:path/path.dart' as path_package;
import 'package:analyzer/src/util/glob.dart';
part 'dart_mixin.dart';
part 'yaml_mixin.dart';
part 'generic_mixin.dart';

class CandiesLintsPlugin extends ServerPlugin
    with DartFilePlugin, YamlFilePlugin, GenericFilePlugin {
  CandiesLintsPlugin()
      : super(resourceProvider: PhysicalResourceProvider.INSTANCE) {
    CandiesLintsLogger().logFileName = logFileName;
  }

  /// The name of log file
  /// default this.name
  String get logFileName => name;

  /// Return the user visible name of this plugin.
  @override
  String get name => 'candies_lints';

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
  String get contactInfo => 'https://github.com/fluttercandies/candies_lints';

  late AnalysisContextCollection _contextCollection;

  /// The cache of configs
  final Map<String, CandiesLintsConfig> _configs =
      <String, CandiesLintsConfig>{};

  List<Glob>? __fileGlobsToAnalyze;

  List<Glob> get _fileGlobsToAnalyze =>
      __fileGlobsToAnalyze ??= fileGlobsToAnalyze
          .map((String e) => Glob(path_package.separator, e))
          .toList();

  /// whether should analyze this file
  bool shouldAnalyzeFile(
    String file,
    AnalysisContext analysisContext,
  ) {
    if (file.endsWith('.g.dart')) {
      return false;
    }

    final String relative = path_package.relative(
      file,
      from: analysisContext.root,
    );

    for (final Glob pattern in _fileGlobsToAnalyze) {
      if (pattern.matches(relative)) {
        return true;
      }
    }
    return false;
  }

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
      CandiesLintsLogger().log(
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
    if (dartLints.isEmpty || !shouldAnalyzeFile(path, analysisContext)) {
      return;
    }

    final bool isAnalyzed = analysisContext.contextRoot.isAnalyzed(path);
    if (!isAnalyzed) {
      return;
    }

    final CandiesLintsConfig? config = _configs[analysisContext.root];
    if (config == null || !config.shouldAnalyze || !config.include(path)) {
      config?.clearCacheErrors(path);
      // send a notification that we ignore the errors in this file.
      channel.sendNotification(
        AnalysisErrorsParams(path, <AnalysisError>[]).toNotification(),
      );
      return;
    }

    try {
      CandiesLintsLogger().log(
        'analyze file: $path',
        root: analysisContext.root,
      );

      final List<AnalysisError> errors =
          (await getAnalysisErrors(config, path, analysisContext)).toList();

      CandiesLintsLogger().log(
        'find ${errors.length} errors in $path',
        root: analysisContext.root,
      );
      // if errors is empty, we still need to send a notification
      // to clear errors if it has.
      channel.sendNotification(
        AnalysisErrorsParams(path, errors).toNotification(),
      );
    } on Exception catch (e, stackTrace) {
      CandiesLintsLogger().logError(
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

  Future<Iterable<AnalysisError>> getAnalysisErrors(
    CandiesLintsConfig config,
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

  Future<Iterable<AnalysisError>> getAnalysisErrorsForDebug(
    String path,
    AnalysisContext analysisContext,
  ) {
    final CandiesLintsConfig config =
        _configs[analysisContext.root] ??= CandiesLintsConfig(
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
    if (!shouldAnalyzeFile(path, context) || dartLints.isEmpty) {
      return EditGetFixesResult(const <AnalysisErrorFixes>[]);
    }

    try {
      //final ResolvedUnitResult unitResult = await getResolvedUnitResult(path);
      // CandiesLintsLogger()
      //     .log('start get fixes for $path', root: unitResult.root);
      // can't get candies error from ResolvedUnitResult.errors
      // so we can't use FixesMixin
      // CandiesLintsLogger().log(
      //     'has ${unitResult.errors.map((e) => e.errorCode)} errors for $path',
      //     root: unitResult.root);

      final String root = context.root;

      final CandiesLintsConfig? config = _configs[root];
      if (config == null || !config.shouldAnalyze || !config.include(path)) {
        CandiesLintsLogger().log(
          'skip get fixes for $path',
          root: root,
        );
        return EditGetFixesResult(const <AnalysisErrorFixes>[]);
      }

      CandiesLintsLogger().log(
        'start get fixes for $path',
        root: root,
      );

      final List<AnalysisErrorFixes> fixes =
          await getAnalysisErrorFixes(config, parameters, context).toList();

      CandiesLintsLogger().log(
        'get total ${fixes.length} fixes for $path',
        root: root,
      );
      return EditGetFixesResult(fixes);
    } on Exception catch (e, stackTrace) {
      // CandiesLintsLogger()
      //     .logError('get fixes failed: $e', root: unitResult.root);
      channel.sendNotification(
        PluginErrorParams(false, e.toString(), stackTrace.toString())
            .toNotification(),
      );
    }

    return EditGetFixesResult(const <AnalysisErrorFixes>[]);
  }

  Stream<AnalysisErrorFixes> getAnalysisErrorFixes(
    CandiesLintsConfig config,
    EditGetFixesParams parameters,
    AnalysisContext context,
  ) {
    return config.getAnalysisErrorFixes(
      parameters: parameters,
      analysisContext: context,
    );
  }

  Stream<AnalysisErrorFixes> getAnalysisErrorFixesForDebug(
    EditGetFixesParams parameters,
    AnalysisContext analysisContext,
  ) {
    final CandiesLintsConfig config =
        _configs[analysisContext.root] ??= CandiesLintsConfig(
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
      final CandiesLintsConfig config = CandiesLintsConfig(
        context: analysisContext,
        pluginName: name,
        dartLints: dartLints,
        astVisitor: astVisitor,
        yamlLints: yamlLints,
        genericLints: genericLints,
      );
      if (config.shouldAnalyze) {
        _configs[analysisContext.root] = config;
        CandiesLintsLogger().log(
          'create a new config for ${analysisContext.root}',
          root: analysisContext.root,
        );
      }
    }
    await super.afterNewContextCollection(contextCollection: contextCollection);
  }
}

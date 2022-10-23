// ignore_for_file: unused_import

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
//import 'package:analyzer_plugin/src/utilities/fixes/fixes.dart';
import 'package:candies_lints/src/extension.dart';
import 'package:candies_lints/src/ignore_info.dart';
import 'package:candies_lints/src/lints/error.dart';
import 'package:candies_lints/src/lints/lint.dart';
import 'package:candies_lints/src/lints/prefer_asset_const.dart';
import 'package:candies_lints/src/lints/prefer_named_routes.dart';
import 'package:candies_lints/src/lints/prefer_safe_setState.dart';
import 'package:analyzer/error/error.dart' as error;
import 'package:candies_lints/src/config.dart';

import 'log.dart';

class CandiesLintsPlugin extends ServerPlugin {
  CandiesLintsPlugin()
      : super(resourceProvider: PhysicalResourceProvider.INSTANCE) {
    CandiesLintsLogger().logFileName = logFileName;
  }

  /// AstVisitor to check lint
  AstVisitorBase get astVisitor => CandiesLintsAstVisitor();

  /// The lints to be used to analyze files
  List<CandyLint> get lints => <CandyLint>[
        PreferAssetConst(),
        PreferNamedRoutes(),
        PerferSafeSetState(),
      ];

  /// The name of log file
  /// default this.name
  String get logFileName => name;

  /// The cache of configs
  final Map<String, CandiesLintsConfig> _configs =
      <String, CandiesLintsConfig>{};

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

  /// whether should analyze this file
  bool shouldAnalyzeFile(String path) {
    return path.endsWith('.dart') && !path.endsWith('.g.dart');
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
    if (lints.isEmpty || !shouldAnalyzeFile(path)) {
      return;
    }

    final bool isAnalyzed = analysisContext.contextRoot.isAnalyzed(path);
    if (!isAnalyzed) {
      return;
    }

    final CandiesLintsConfig? config = _configs[analysisContext.root];
    if (config == null || !config.shouldAnalyze) {
      config?.astVisitor.clearCacheErrors(path);
      return;
    }

    try {
      CandiesLintsLogger().log(
        'analyze file: $path',
        root: analysisContext.root,
      );

      final ResolvedUnitResult unitResult = await getResolvedUnitResult(path);
      final List<AnalysisError> errors = getErrorsFromResult(
        unitResult,
        config.astVisitor,
        config: config,
      );
      if (errors.isNotEmpty) {
        CandiesLintsLogger().log(
          'find ${errors.length} errors in ${unitResult.path}',
          root: analysisContext.root,
        );
        channel.sendNotification(
          AnalysisErrorsParams(path, errors).toNotification(),
        );
      }
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

  /// Return AnalysisError List base on ResolvedUnitResult.
  List<AnalysisError> getErrorsFromResult(
    ResolvedUnitResult unitResult,
    AstVisitorBase astVisitor, {
    CandiesLintsConfig? config,
  }) {
    unitResult.unit.visitChildren(astVisitor);
    final CandiesLintsIgnoreInfo ignore =
        CandiesLintsIgnoreInfo.forDart(unitResult);
    final List<AnalysisError> errors = astVisitor
        .getAnalysisErrors(
          result: unitResult,
          ignore: ignore,
          config: config,
        )
        .toList();
    return errors;
  }

  /// Handle an 'edit.getFixes' request.
  ///
  /// Throw a [RequestFailure] if the request could not be handled.
  @override
  Future<EditGetFixesResult> handleEditGetFixes(
      EditGetFixesParams parameters) async {
    final String path = parameters.file;
    if (!shouldAnalyzeFile(path) || lints.isEmpty) {
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
      final AnalysisContext context = _contextCollection.contextFor(path);
      final String root = context.root;

      final CandiesLintsConfig? config = _configs[root];
      if (config == null || !config.shouldAnalyze) {
        return EditGetFixesResult(const <AnalysisErrorFixes>[]);
      }

      CandiesLintsLogger().log(
        'start get fixes for $path',
        root: root,
      );

      final List<AnalysisErrorFixes> fixes = await config.astVisitor
          .getAnalysisErrorFixes(parameters: parameters)
          .toList();
      CandiesLintsLogger().log(
        'get ${fixes.length} fixes for $path',
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
      CandiesLintsLogger().log(
          'create a new config for ${analysisContext.root}',
          root: analysisContext.root);
      _configs[analysisContext.root] = CandiesLintsConfig(
        context: analysisContext,
        pluginName: name,
        lints: lints,
        astVisitor: astVisitor,
      );
    }
    await super.afterNewContextCollection(contextCollection: contextCollection);
  }
}

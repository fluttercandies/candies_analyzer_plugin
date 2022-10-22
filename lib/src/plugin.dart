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
import 'package:candies_lints/src/lints/lint.dart';
import 'package:candies_lints/src/lints/prefer_asset_const.dart';
import 'package:candies_lints/src/lints/prefer_named_routes.dart';
import 'package:candies_lints/src/lints/prefer_safe_setState.dart';
import 'package:analyzer/error/error.dart' as error;

import 'ast_visitor.dart';
import 'log.dart';

class CandiesLintsPlugin extends ServerPlugin
//with FixesMixin, DartFixesMixin
{
  CandiesLintsPlugin({
    AstVisitorBase? astVisitor,
    List<CandyLint>? lints,
    String? name,
    String? logFileName,
  })  : astVisitor = astVisitor ?? CandiesLintsAstVisitor(),
        lints = lints ?? defaultLints,
        name = name ?? 'candies_lints',
        super(resourceProvider: PhysicalResourceProvider.INSTANCE) {
    this.astVisitor._lints = this.lints;
    CandiesLintsLogger().logFileName = logFileName ?? 'candies_lints';
  }
  final AstVisitorBase astVisitor;
  final List<CandyLint> lints;

  static List<CandyLint> defaultLints = <CandyLint>[
    PreferAssetConst(),
    PreferNamedRoutes(),
    PerferSafeSetState(),
  ];

  @override
  final String name;

  @override
  String get version => '1.0.0';

  @override
  List<String> get fileGlobsToAnalyze => const <String>['**/*.dart'];

  @override
  String get contactInfo => 'https://github.com/fluttercandies/candies_lints';

  bool shouldAnalyzeFile(String path) {
    return path.endsWith('.dart') && !path.endsWith('.g.dart');
  }

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

  @override
  Future<void> analyzeFile(
      {required AnalysisContext analysisContext, required String path}) async {
    if (!shouldAnalyzeFile(path) || lints.isEmpty) {
      return;
    }

    final bool isAnalyzed = analysisContext.contextRoot.isAnalyzed(path);
    if (!isAnalyzed) {
      return;
    }

    try {
      CandiesLintsLogger().log(
        'analyze file: $path',
        root: analysisContext.root,
      );

      final ResolvedUnitResult unitResult = await getResolvedUnitResult(path);

      final List<AnalysisError> errors = getErrorsFromResult(unitResult);
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

  List<AnalysisError> getErrorsFromResult(ResolvedUnitResult unitResult) {
    unitResult.unit.visitChildren(astVisitor);
    final CandiesLintsIgnoreInfo ignore =
        CandiesLintsIgnoreInfo.forDart(unitResult);
    final List<AnalysisError> errors = astVisitor
        .getAnalysisErrors(
          result: unitResult,
          ignore: ignore,
        )
        .toList();
    return errors;
  }

  @override
  Future<EditGetFixesResult> handleEditGetFixes(
      EditGetFixesParams parameters) async {
    final String path = parameters.file;
    if (!shouldAnalyzeFile(path) || lints.isEmpty) {
      return EditGetFixesResult(const <AnalysisErrorFixes>[]);
    }

    try {
      final ResolvedUnitResult unitResult = await getResolvedUnitResult(path);
      CandiesLintsLogger()
          .log('start get fixes for $path', root: unitResult.root);
      // can't get candies error from ResolvedUnitResult.errors
      // so we can't use FixesMixin
      // CandiesLintsLogger().log(
      //     'has ${unitResult.errors.map((e) => e.errorCode)} errors for $path',
      //     root: unitResult.root);
      unitResult.unit.visitChildren(astVisitor);

      final CandiesLintsIgnoreInfo ignore =
          CandiesLintsIgnoreInfo.forDart(unitResult);
      final List<AnalysisErrorFixes> fixes = await astVisitor
          .getAnalysisErrorFixes(
            result: unitResult,
            parameters: parameters,
            ignore: ignore,
          )
          .toList();
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

  // @override
  // List<FixContributor> getFixContributors(String path) {
  //   return <FixContributor>[MyFixContributor()];
  // }

  // @override
  // Future<EditGetFixesResult> handleEditGetFixes(
  //     EditGetFixesParams parameters) async {
  //   var path = parameters.file;
  //   var request = await getFixesRequest(parameters);
  //   var generator = FixGenerator(getFixContributors(path));
  //   var result = await generator.generateFixesResponse(request);
  //   result.sendNotifications(channel);
  //   return result.result;
  // }

  // @override
  // Future<FixesRequest> getFixesRequest(EditGetFixesParams parameters) async {
  //   var path = parameters.file;
  //   var offset = parameters.offset;
  //   var result = await getResolvedUnitResult(path);
  //   CandiesLintsLogger().log('start get fixes for $path', root: result.root);
  //   return DartFixesRequestImpl(
  //       resourceProvider, offset, _getErrors(offset, result), result);
  // }

  // List<error.AnalysisError> _getErrors(int offset, ResolvedUnitResult result) {
  //   var lineInfo = result.lineInfo;
  //   var offsetLine = lineInfo.getLocation(offset).lineNumber;
  //   return result.errors.where((error.AnalysisError error) {
  //     var errorLine = lineInfo.getLocation(error.offset).lineNumber;
  //     return errorLine == offsetLine;
  //   }).toList();
  // }
}

/// AstVisitor to check lint
///
mixin AstVisitorBase on AstVisitor<void> {
  late List<CandyLint> _lints;
  List<CandyLint> get lints => _lints;

  bool analyze(AstNode node) {
    bool handle = false;
    for (final CandyLint lint in lints) {
      handle = lint.analyze(node) || handle;
    }
    return handle;
  }

  Iterable<AnalysisError> getAnalysisErrors({
    required ResolvedUnitResult result,
    required CandiesLintsIgnoreInfo ignore,
  }) sync* {
    for (final CandyLint lint in lints) {
      yield* lint.toAnalysisErrors(
        result: result,
        ignore: ignore,
      );
    }
  }

  Stream<AnalysisErrorFixes> getAnalysisErrorFixes({
    required ResolvedUnitResult result,
    required EditGetFixesParams parameters,
    required CandiesLintsIgnoreInfo ignore,
  }) async* {
    for (final CandyLint lint in lints) {
      yield* lint.toAnalysisErrorFixesStream(
        result: result,
        parameters: parameters,
        ignore: ignore,
      );
    }
  }
}

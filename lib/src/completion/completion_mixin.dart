// ignore_for_file: implementation_imports

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/src/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/utilities/generator.dart';
import 'package:candies_analyzer_plugin/src/completion/contributors/extension_member_contributor.dart';
import 'package:candies_analyzer_plugin/src/log.dart';
import 'package:analyzer/src/util/file_paths.dart' as file_paths;
import 'package:path/path.dart' as path_context;

mixin CandiesCompletionPlugin on ServerPlugin {
  final Set<ExtensionElement> _accessibleExtensionsCache = <ExtensionElement>{};
  // final Set<ExtensionElement> _unSolvedAccessibleExtensions =
  //     <ExtensionElement>{};
  //String? _sdkPath;
  // save result for [ExtensionMemberContributor]
  Future<void> saveAccessibleExtensions({
    required AnalysisContext analysisContext,
    required String path,
    //bool solved = true,
  }) async {
    if (file_paths.isDart(path_context.context, path) &&
        completionContributors
            .whereType<ExtensionMemberContributor>()
            .isEmpty) {
      return;
    }
    final ResolvedUnitResult result = await getResolvedUnitResult(path);
    final Set<ExtensionElement> accessibleExtensions =
        _accessibleExtensionsCache;
    //solved ? _accessibleExtensions : _unSolvedAccessibleExtensions;
    for (final ExtensionElement accessibleExtension
        in result.libraryElement.accessibleExtensions) {
      // skip dart.core
      if (
          //accessibleExtension.library.name == 'dart.core' &&
          accessibleExtension.library.isDartCore) {
        continue;
      }

      if (!accessibleExtensions.contains(accessibleExtension)) {
        CandiesAnalyzerPluginLogger().log(
          'saveResolvedUnitResult at ${accessibleExtension.source.fullName}',
          root: analysisContext.contextRoot.root.path,
        );
        accessibleExtensions.add(accessibleExtension);
      }
    }
  }

  @override
  Future<void> contentChanged(List<String> paths) {
    // clear result when file is changed
    _accessibleExtensionsCache.removeWhere(
        (ExtensionElement element) => paths.contains(element.source.fullName));
    return super.contentChanged(paths);
  }

  /// The completionContributors to finish CompletionRequest
  List<CompletionContributor> get completionContributors =>
      <CompletionContributor>[
        ExtensionMemberContributor(),
      ];

  /// Return the completion request that should be passes to the contributors
  /// returned from [getCompletionContributors].
  ///
  /// Throw a [RequestFailure] if the request could not be created.
  Future<DartCompletionRequestImpl> getCompletionRequest(
      CompletionGetSuggestionsParams parameters) async {
    final ResolvedUnitResult result =
        await getResolvedUnitResult(parameters.file);
    return DartCompletionRequestImpl(
        resourceProvider, parameters.offset, result);
  }

  @override
  Future<CompletionGetSuggestionsResult> handleCompletionGetSuggestions(
    CompletionGetSuggestionsParams parameters,
  ) async {
    //final String path = parameters.file;
    final DartCompletionRequestImpl request =
        await getCompletionRequest(parameters);

    final CompletionGenerator generator =
        CompletionGenerator(completionContributors
          ..forEach(
            (CompletionContributor element) {
              if (element is ExtensionMemberContributor) {
                element.accessibleExtensions = _accessibleExtensionsCache;
              }
            },
          ));
    final GeneratorResult<CompletionGetSuggestionsResult?> result =
        await generator.generateCompletionResponse(request);
    result.sendNotifications(channel);
    CandiesAnalyzerPluginLogger().log(
      'handleCompletionGetSuggestions: find Suggestions ${result.result?.results.length}个，${result.result?.results}',
      root: request.result.session.analysisContext.contextRoot.root.path,
    );
    return result.result!;
  }

  // Future<void> saveOtherPackagesAccessibleExtensions({
  //   required AnalysisContextCollection contextCollection,
  // }) async {
  //   if (completionContributors
  //       .whereType<ExtensionMemberContributor>()
  //       .isEmpty) {
  //     return;
  //   }
  //   final List<String> includedPaths =
  //       contextCollection.contexts.map((AnalysisContext e) => e.root).toList();
  //   final Set<String> ohterPaths = <String>{};
  //   for (final AnalysisContext context in contextCollection.contexts) {
  //     try {
  //       final PackageGraph packageGraph =
  //           await PackageGraph.forPath(context.root);
  //       final Map<String, String> dependencies =
  //           _parseDependencyTypes(context.root);
  //       for (final PackageNode package in packageGraph.allPackages.values) {
  //         if (package.dependencyType == DependencyType.path) {
  //           continue;
  //         }
  //         if (!dependencies.keys.contains(package.name)) {
  //           continue;
  //         }
  //         if (!includedPaths.contains(package.path)) {
  //           ohterPaths.add(package.path);
  //         }
  //       }
  //       // ignore: empty_catches
  //     } catch (e) {}
  //   }

  //   final AnalysisContextCollectionImpl contextCollection1 =
  //       AnalysisContextCollectionImpl(
  //     resourceProvider: resourceProvider,
  //     includedPaths: <String>[
  //       ...includedPaths,
  //       ...ohterPaths,
  //     ],
  //     byteStore: createByteStore(),
  //     sdkPath: _sdkPath,
  //     fileContentCache: FileContentCache(resourceProvider),
  //   );
  //   _unSolvedAccessibleExtensions.clear();
  //   for (final DriverBasedAnalysisContext context
  //       in contextCollection1.contexts) {
  //     // if (includedPaths.contains(context.root)) {
  //     //   continue;
  //     // }
  //     for (final String path in context.contextRoot.analyzedFiles()) {
  //       if (!context.contextRoot.isAnalyzed(path)) {
  //         continue;
  //       }
  //       await saveAccessibleExtensions(
  //         analysisContext: context,
  //         path: path,
  //         solved: false,
  //       );
  //     }
  //   }
  // }

  // /// Handle a 'plugin.versionCheck' request.
  // ///
  // /// Throw a [RequestFailure] if the request could not be handled.
  // @override
  // Future<PluginVersionCheckResult> handlePluginVersionCheck(
  //     PluginVersionCheckParams parameters) async {
  //   _sdkPath = parameters.sdkPath;
  //   return super.handlePluginVersionCheck(parameters);
  // }

  // Map<String, String> _parseDependencyTypes(String rootPackagePath) {
  //   final File pubspecLock =
  //       File(path_context.join(rootPackagePath, 'pubspec.lock'));
  //   if (!pubspecLock.existsSync()) {
  //     throw StateError(
  //         'Unable to generate package graph, no `pubspec.lock` found. '
  //         'This program must be ran from the root directory of your package.');
  //   }
  //   // dependency
  //   final Map<String, String> dependencyTypes = <String, String>{};
  //   final YamlMap dependencies =
  //       loadYaml(pubspecLock.readAsStringSync()) as YamlMap;

  //   final YamlMap packages = dependencies['packages'] as YamlMap;
  //   for (final dynamic packageName in packages.keys) {
  //     final YamlMap package = packages[packageName] as YamlMap;
  //     if (package['dependency'] == 'direct main') {
  //       dependencyTypes[packageName.toString()] = 'direct main';
  //     }
  //   }

  //   return dependencyTypes;
  // }
}

part of 'plugin.dart';

/// Put properties or methods not from [ServerPlugin] here.
mixin CandiesAnalyzerPluginBase on ServerPlugin {
  /// Add git author into error message
  bool get showAnalysisErrorWithGitAuthor => false;

  /// The name of log file
  /// default this.name
  String get logFileName => name;

  /// The cache of configs
  final Map<String, CandiesAnalyzerPluginConfig> _configs =
      <String, CandiesAnalyzerPluginConfig>{};

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

  /// get analysis error fixes form cache errors
  Stream<AnalysisErrorFixes> getAnalysisErrorFixes(
    CandiesAnalyzerPluginConfig config,
    EditGetFixesParams parameters,
    AnalysisContext context,
  ) {
    return config.getAnalysisErrorFixes(
      parameters: parameters,
      analysisContext: context,
    );
  }

  /// Get git author form error line
  String? getGitAuthor(
    String fileName,
    int line,
  ) {
    final ProcessResult result = Process.runSync(
      'git',
      'blame ${path_package.basename(fileName)} -L$line,$line'.split(' '),
      runInShell: true,
      workingDirectory: path_package.dirname(fileName),
    );

    // ^bb984a5 (zmtzawqlp 2022-10-22 22:24:19 +0800 1) // ignore_for_file: unused_local_variable
    if (result.exitCode != 0) {
      return null;
    }
    final String stdout = '${result.stdout}';
    if (stdout.startsWith('fatal')) {
      return null;
    }

    final int start = stdout.indexOf('(');
    if (start > -1) {
      final int end = stdout.indexOf(')', start);
      if (end > -1) {
        final List<String> infos =
            stdout.substring(start + 1, end).trim().split(' ');
        if (infos.isNotEmpty) {
          return infos.first;
        }
      }
    }
    return null;
  }

  /// before send AnalysisErrors Notification
  /// you can edit AnalysisError before to be send
  Future<void> beforeSendAnalysisErrors({
    required List<AnalysisError> errors,
    required AnalysisContext analysisContext,
    required String path,
    required CandiesAnalyzerPluginConfig config,
  }) async {
    if (errors.isNotEmpty && showAnalysisErrorWithGitAuthor) {
      for (final AnalysisError error in errors) {
        final String? author = getGitAuthor(path, error.location.startLine);
        if (author != null) {
          error.message = '($author) ' + error.message;
        } else {
          // fatal: not a git repository (or any of the parent directories): .git
          // or has error when run git blame
          break;
        }
      }
    }
  }
}

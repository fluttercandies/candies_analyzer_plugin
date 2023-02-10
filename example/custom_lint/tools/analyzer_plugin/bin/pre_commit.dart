// ignore_for_file: dead_code

import 'dart:io';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';
import 'package:path/path.dart';

import 'plugin.dart';

Future<void> main(List<String> args) async {
  final String workingDirectory =
      args.isNotEmpty ? args.first : Directory.current.path;
  final Stopwatch stopwatch = Stopwatch();
  stopwatch.start();
  // if false, analyze whole workingDirectory
  const bool onlyAnalyzeDiffFiles = true;
  final String gitRoot = CandiesAnalyzerPlugin.processRun(
    executable: 'git',
    arguments: 'rev-parse --show-toplevel',
    workingDirectory: workingDirectory,
  ).trim();
  // find diff files.
  final List<String> diff = CandiesAnalyzerPlugin.processRun(
    executable: 'git',
    arguments: 'diff --name-status',
    throwException: false,
    workingDirectory: workingDirectory,
  ).trim().split('\n').where((String e) {
    //M       CHANGELOG.md
    //D       CHANGELOG.md
    // ignore delete file

    return e.toUpperCase().startsWith('M');
  }).map((String e) {
    return join(gitRoot, e.replaceFirst('M', '').trim());
  }).toList();

  // git ls-files --others --exclude-standard
  final List<String> untracked = CandiesAnalyzerPlugin.processRun(
    executable: 'git',
    arguments: 'ls-files --others --exclude-standard',
    throwException: false,
    workingDirectory: workingDirectory,
  )
      .trim()
      .split('\n')
      .map((String e) => join(workingDirectory, e).trim())
      .toList();

  final List<String> analyzeFiles = <String>[...diff, ...untracked]
      .where((String element) => element.startsWith(workingDirectory))
      .toList();

  if (analyzeFiles.isEmpty) {
    stopwatch.stop();
    return;
  }

  // get error from CandiesAnalyzerPlugin
  final List<String> errors = await CandiesAnalyzerPlugin.getCandiesErrorInfos(
    workingDirectory,
    plugin,
    analyzeFiles: onlyAnalyzeDiffFiles ? analyzeFiles : null,
  );

  // get errors from dart analyze command
  errors.addAll(CandiesAnalyzerPlugin.getErrorInfosFromDartAnalyze(
    workingDirectory,
    analyzeFiles: onlyAnalyzeDiffFiles ? analyzeFiles : null,
  ));
  stopwatch.stop();

  _printErrors(errors, stopwatch.elapsed.inMilliseconds);
}

void _printErrors(List<String> errors, int inMilliseconds) {
  final String seconds = (inMilliseconds / 1000).toStringAsFixed(2);
  if (errors.isEmpty) {
    print('No issues found!  ${seconds}s');
  } else {
    print('');
    print(errors
        .map((String e) => '  ${e.getHighlightErrorInfo()}')
        .join('\n\n'));
    print('\n${errors.length} issues found.'
            .wrapAnsiCode(foregroundColor: AnsiCodeForegroundColor.red) +
        '  ${seconds}s');
    print('Please fix the errors and then submit the code.'
        .wrapAnsiCode(foregroundColor: AnsiCodeForegroundColor.red));
  }
}

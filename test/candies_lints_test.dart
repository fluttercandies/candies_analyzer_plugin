// ignore_for_file: unused_import, unused_local_variable

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/analysis_options.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer/src/ignore_comments/ignore_info.dart';
import 'package:candies_lints/src/ignore_info.dart';
import 'package:candies_lints/src/plugin.dart';
import 'package:analyzer/src/util/glob.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

Future<void> main() async {
  final String debugFilePath =
      path.join(path.current, 'example', 'lib', 'main.dart');
  test('getErrors', () async {
    final String debugFilePath = Directory.current.parent.parent.parent.path;
    final AnalysisContextCollection collection =
        AnalysisContextCollection(includedPaths: <String>[debugFilePath]);

    final CandiesLintsPlugin myPlugin = CandiesLintsPlugin();
    for (final AnalysisContext context in collection.contexts) {
      for (final String file in context.contextRoot.analyzedFiles()) {
        if (!myPlugin.shouldAnalyzeFile(file)) {
          continue;
        }
        final List<AnalysisError> errors = myPlugin.getErrorsFromResultForDebug(
          await context.currentSession.getResolvedUnit(file)
              as ResolvedUnitResult,
          context,
        );
        print(errors.length);
      }
    }
    //LineInfo lineInfo = LineInfo.fromContent(result.content);
  });

  test('ignore for this line', () async {
    final ResolvedUnitResult result =
        await resolveFile2(path: debugFilePath) as ResolvedUnitResult;

    final IgnoreInfo info = IgnoreInfo.forDart(result.unit, result.content);
    // info.ignoredAt(ErrorCode(), line)

    final LineInfo lineInfo = LineInfo.fromContent(result.content);
    final int offset =
        result.content.indexOf('onDoubleTap: () => setState(() {})');
    final CharacterLocation characterLocation = lineInfo.getLocation(offset);
    final CandiesLintsIgnoreInfo ignore =
        CandiesLintsIgnoreInfo.forDart(result);
    ignore.fixIgnoreForThisLine(
        'ddd',
        Location(
          '',
          offset,
          1,
          characterLocation.lineNumber,
          characterLocation.columnNumber,
        ));
  });

  test('ignore for this line  (with ignore)', () async {
    final ResolvedUnitResult result =
        await resolveFile2(path: debugFilePath) as ResolvedUnitResult;
    final LineInfo lineInfo = LineInfo.fromContent(result.content);
    final int offset = result.content.indexOf('onTap: () => setState(() {})');
    final CharacterLocation characterLocation = lineInfo.getLocation(offset);
    final CandiesLintsIgnoreInfo ignore =
        CandiesLintsIgnoreInfo.forDart(result);
    ignore.fixIgnoreForThisLine(
        'ddd',
        Location(
          '',
          offset,
          1,
          characterLocation.lineNumber,
          characterLocation.columnNumber,
        ));
  });

  test('AnalysisContextCollection', () async {
    final AnalysisContextCollection collection = AnalysisContextCollection(
        includedPaths: <String>[path.join(path.current, 'example')]);
    for (final AnalysisContext context in collection.contexts) {
      final AnalysisOptions sss = context.analysisOptions;

      final String? optionsFilePath = context.contextRoot.optionsFile?.path;
      if (optionsFilePath != null) {
        final File file = File(optionsFilePath);
        final YamlMap yaml = loadYaml(file.readAsStringSync()) as YamlMap;

        if (yaml.containsKey('include')) {
          final YamlScalar s = yaml.nodes['include'] as YamlScalar;
          print('dd');
        }
        if (yaml.containsKey('linter')) {
          final YamlMap s = yaml.nodes['linter'] as YamlMap;
          if (s.containsKey('rules')) {
            if (s.nodes['rules'] is YamlList) {
            } else if (s.nodes['rules'] is YamlMap) {}
            final YamlNode? ss = s.nodes['rules'];

            print('ddd');
          }
          print('dd');
        }
        if (yaml.nodes['custom_lint'] is YamlMap) {
          final YamlMap pluginConfig = yaml.nodes['custom_lint'] as YamlMap;
          if (pluginConfig.nodes['include'] is YamlList) {
            final YamlList includePatterns =
                pluginConfig.nodes['include'] as YamlList;

            final List<Glob> _includePatterns = includePatterns
                .map((dynamic e) => Glob(path.separator, e.toString()))
                .toList();

            bool include(String path) {
              if (_includePatterns.isEmpty) {
                return true;
              }

              for (final Glob includePattern in _includePatterns) {
                if (includePattern.matches(path)) {
                  return true;
                }
              }
              return false;
            }

            final String testFile = path.join(
                path.current, 'example', 'lib', 'include', 'test.dart');

            final String relative =
                path.relative(testFile, from: context.contextRoot.root.path);

            final bool ddd = include(relative);

            print('ddd');
          }
        }
        print('dd');
      }

      print('dd');
    }
  });
}

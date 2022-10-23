import 'dart:convert';
import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) {
  if (args.isEmpty) {
    print('please run as \'candies_lints plugin_name\'');
  }
  final String pluginName = args.first;
  final Directory currentD = Directory.current;
  processRun(executable: 'dart', arguments: 'create $pluginName -t package');

  processRun(
    executable: 'dart',
    arguments: 'pub get',
    workingDirectory: path.join(currentD.path, pluginName),
  );

  final String toolsPath = path.join(currentD.path, pluginName, 'tools');
  final Directory directory = Directory(toolsPath);
  directory.createSync(recursive: true);

  processRun(
    executable: 'dart',
    arguments: 'create ${pluginName}_analyzer_plugin',
    workingDirectory: toolsPath,
  );

  final String analyzerPluginPath = path.join(toolsPath, 'analyzer_plugin');

  Directory(path.join(toolsPath, '${pluginName}_analyzer_plugin'))
      .renameSync(analyzerPluginPath);

  final File pubspecFile = File(path.join(analyzerPluginPath, 'pubspec.yaml'));

  pubspecFile.writeAsStringSync(pubspec.replaceAll('{0}', pluginName));

  File file = File(path.join(
      analyzerPluginPath, 'bin', '${pluginName}_analyzer_plugin.dart'));

  file = file.renameSync(path.join(analyzerPluginPath, 'bin', 'plugin.dart'));

  file.writeAsStringSync(pluginDemo.replaceAll('{0}', pluginName));

  final File debugFile =
      File(path.join(analyzerPluginPath, 'bin', 'debug.dart'));
  debugFile.createSync(recursive: true);
  debugFile.writeAsStringSync(debugDemo);

  processRun(
    executable: 'dart',
    arguments: 'pub get',
    workingDirectory: analyzerPluginPath,
  );
}

const String pluginDemo = '''
import 'dart:convert';
import 'dart:isolate';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_lints/candies_lints.dart';
import 'package:analyzer/src/pubspec/pubspec_validator.dart';

CandiesLintsPlugin get plugin => CustomLintPlugin();

// This file must be 'plugin.dart'
void main(List<String> args, SendPort sendPort) {
  CandiesLintsStarter.start(
    args,
    sendPort,
    plugin: plugin,
  );
}

class CustomLintPlugin extends CandiesLintsPlugin {
  @override
  String get name => '{0}';

  @override
  List<String> get fileGlobsToAnalyze => const <String>[
        '**/*.dart',
        '**/*.yaml',
        '**/*.json',
      ];
  // add your dart lints here
  @override
  List<DartLint> get dartLints => <DartLint>[
        PerferCandiesClassPrefix(),
        ...super.dartLints,
      ];

  // add your yaml lints here
  @override
  List<YamlLint> get yamlLints => <YamlLint>[RemoveDependency(package: 'path')];

  // add your generic lints here
  @override
  List<GenericLint> get genericLints => <GenericLint>[RemoveDuplicateValue()];
}

class PerferCandiesClassPrefix extends DartLint {
  @override
  String get code => 'perfer_candies_class_prefix';

  @override
  String? get url => 'https://github.com/fluttercandies/candies_lints';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is ClassDeclaration) {
      final String name = node.name2.toString();
      final int startIndex = _getClassNameStartIndex(name);
      if (!name.substring(startIndex).startsWith('Candies')) {
        return node.name2;
      }
    }
    return null;
  }

  @override
  String get message => 'Define a class name start with Candies';

  @override
  Future<List<SourceChange>> getDartFixes(
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async {
    // get name node
    final Token nameNode = (astNode as ClassDeclaration).name2;
    final String nameString = nameNode.toString();
    return <SourceChange>[
      await getDartFix(
        resolvedUnitResult: resolvedUnitResult,
        message: 'Use Candies as a class prefix.',
        buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
          final int startIndex = _getClassNameStartIndex(nameString);

          final RegExp regExp = RegExp(nameString);

          final String replace =
              '\${nameString.substring(0, startIndex)}Candies\${nameString.substring(startIndex)}';

          for (final Match match
              in regExp.allMatches(resolvedUnitResult.content)) {
            dartFileEditBuilder.addSimpleReplacement(
                SourceRange(match.start, match.end - match.start), replace);
          }

          dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
        },
      )
    ];
  }

  int _getClassNameStartIndex(String nameString) {
    int index = 0;
    while (nameString[index] == '_') {
      index++;
      if (index == nameString.length - 1) {
        break;
      }
    }
    return index;
  }
}

class RemoveDependency extends YamlLint {
  RemoveDependency({required this.package});
  final String package;
  @override
  String get code => 'remove_\${package}_dependency';

  @override
  String get message => 'Remove \$package dependency';

  @override
  String? get correction => 'Remove \$package dependency';

  @override
  AnalysisErrorSeverity get severity => AnalysisErrorSeverity.WARNING;

  @override
  Iterable<SourceRange> matchLint(
    YamlNode root,
    String content,
    LineInfo lineInfo,
  ) sync* {
    if (root is YamlMap && root.containsKey(PubspecField.DEPENDENCIES_FIELD)) {
      final YamlNode dependencies =
          root.nodes[PubspecField.DEPENDENCIES_FIELD]!;
      if (dependencies is YamlMap && dependencies.containsKey(package)) {
        final YamlNode get = dependencies.nodes[package]!;
        int start = dependencies.span.start.offset;
        final int end = get.span.start.offset;
        final int index = content.substring(start, end).indexOf('\$package: ');
        start += index;
        yield SourceRange(start, get.span.end.offset - start);
      }
    }
  }
}

class RemoveDuplicateValue extends GenericLint {
  @override
  String get code => 'remove_duplicate_value';

  @override
  Iterable<SourceRange> matchLint(
    String content,
    String file,
    LineInfo lineInfo,
  ) sync* {
    if (isFileType(file: file, type: '.json')) {
      final Map<dynamic, dynamic> map =
          jsonDecode(content) as Map<dynamic, dynamic>;

      final Map<dynamic, dynamic> duplicate = <dynamic, dynamic>{};
      final Map<dynamic, dynamic> checkDuplicate = <dynamic, dynamic>{};
      for (final dynamic key in map.keys) {
        final dynamic value = map[key];
        if (checkDuplicate.containsKey(value)) {
          duplicate[key] = value;
          duplicate[checkDuplicate[value]] = value;
        }
        checkDuplicate[value] = key;
      }

      if (duplicate.isNotEmpty) {
        for (final dynamic key in duplicate.keys) {
          final int start = content.indexOf('"\$key"');
          final dynamic value = duplicate[key];
          final int end = content.indexOf(
                '"\$value"',
                start,
              ) +
              value.toString().length +
              1;

          final int lineNumber = lineInfo.getLocation(end).lineNumber;

          bool hasComma = false;
          int commaIndex = end;
          int commaLineNumber = lineInfo.getLocation(commaIndex).lineNumber;

          while (!hasComma && commaLineNumber == lineNumber) {
            commaIndex++;
            final String char = content[commaIndex];
            hasComma = char == ',';
            commaLineNumber = lineInfo.getLocation(commaIndex).lineNumber;
          }

          yield SourceRange(start, (hasComma ? commaIndex : end) + 1 - start);
        }
      }
    }
  }

  @override
  String get message => 'remove duplicate value';
}
''';

const String pubspec = '''
name: {0}_analyzer_plugin
description: A sample command-line application.
version: 1.0.0
# homepage: https://www.example.com

environment:
  sdk: '>=2.17.6 <3.0.0'

dependencies:
  candies_lints: any
  path: any
  analyzer: any
  analyzer_plugin: any
dependency_overrides:

dev_dependencies:
  lints: any
  test: any
''';

const String debugDemo = '''
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:candies_lints/candies_lints.dart';
import 'plugin.dart';

Future<void> main(List<String> args) async {
  final String root = Directory.current.parent.parent.parent.path;
  final AnalysisContextCollection collection =
      AnalysisContextCollection(includedPaths: <String>[root]);

  final CandiesLintsPlugin myPlugin = plugin;
  for (final AnalysisContext context in collection.contexts) {
    for (final String file in context.contextRoot.analyzedFiles()) {
      if (!myPlugin.shouldAnalyzeFile(file, context)) {
        continue;
      }

      final bool isAnalyzed = context.contextRoot.isAnalyzed(file);
      if (!isAnalyzed) {
        continue;
      }

      final List<AnalysisError> errors =
          (await myPlugin.getAnalysisErrorsForDebug(
        file,
        context,
      ))
              .toList();
      for (final AnalysisError error in errors) {
        final List<AnalysisErrorFixes> fixes = await myPlugin
            .getAnalysisErrorFixesForDebug(
                EditGetFixesParams(file, error.location.offset), context)
            .toList();
        print(fixes.length);
      }

      print(errors.length);
    }
  }
}
''';

String processRun({
  required String executable,
  String? arguments,
  bool runInShell = false,
  String? workingDirectory,
  List<String>? argumentsList,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
}) {
  final List<String> temp = <String>[];

  if (arguments != null) {
    temp.addAll(
        arguments.split(' ')..removeWhere((String x) => x.trim() == ''));
  }

  if (argumentsList != null) {
    temp.addAll(argumentsList);
  }

  print(yellow.wrap('$executable $temp'));
  final ProcessResult result = Process.runSync(
    executable,
    temp,
    runInShell: runInShell,
    workingDirectory: workingDirectory,
    stdoutEncoding: stdoutEncoding,
    stderrEncoding: stderrEncoding,
  );
  if (result.exitCode != 0) {
    throw Exception(result.stderr);
  }

  final String stdout = result.stdout.toString();

  print(green.wrap('stdout: $stdout\n'));

  return stdout;
}

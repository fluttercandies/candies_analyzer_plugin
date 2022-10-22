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
import 'dart:isolate';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_lints/candies_lints.dart';

CandiesLintsPlugin get plugin => CandiesLintsPlugin(
      name: 'custom_lint',
      logFileName: 'custom_lint',
      lints: <CandyLint>[
        // add your line here
        PerferCandiesClassPrefix(),
        ...CandiesLintsPlugin.defaultLints,
      ],
    );

// This file must be 'plugin.dart'
void main(List<String> args, SendPort sendPort) {
  CandiesLintsStarter.start(
    args,
    sendPort,
    plugin: plugin,
  );
}

class PerferCandiesClassPrefix extends CandyLint {
  @override
  String get code => 'perfer_candies_class_prefix';

  @override
  String? get url => 'https://github.com/fluttercandies/candies_lints';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is ClassDeclaration) {
      final String name = node.name2.toString();
      int startIndex = _getClassNameStartIndex(name);
      if (!name.substring(startIndex).startsWith('Candies')) {
        return node.name2;
      }
    }
    return null;
  }

  @override
  String get message => 'Define a class name start with Candies';

  @override
  Future<List<SourceChange>> getFixes(
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async {
    // get name node
    Token nameNode = (astNode as ClassDeclaration).name2;
    String nameString = nameNode.toString();
    return <SourceChange>[
      await getFix(
        resolvedUnitResult: resolvedUnitResult,
        message: 'Use Candies as a class prefix.',
        buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
          int startIndex = _getClassNameStartIndex(nameString);

          RegExp regExp = RegExp(nameString);

          String replace =
              '\${nameString.substring(0, startIndex)}Candies\${nameString.substring(startIndex)}';

          for (Match match in regExp.allMatches(resolvedUnitResult.content)) {
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
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'plugin.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  final String debugFilePath =
      path.join('your project root', 'lib', 'main.dart');

  final ResolvedUnitResult result =
      await resolveFile2(path: debugFilePath) as ResolvedUnitResult;

  final List<AnalysisError> errors = plugin.getErrorsFromResult(result);
  print(errors.length);
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

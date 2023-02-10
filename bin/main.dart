import 'dart:convert';
import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) {
  if (args.isEmpty) {
    print('please run as \'candies_analyzer_plugin plugin_name\'');
  }

  final String arg = args.first;

  if (arg == 'clear_cache') {
    clearPluginManagerCache();
    return;
  } else if (arg == 'create_pre_commit') {
    creatPreCommitSH();
    return;
  }

  final String pluginName = arg;
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

  final File preCommitFile =
      File(path.join(analyzerPluginPath, 'bin', 'pre_commit.dart.dart'));
  preCommitFile.createSync(recursive: true);
  preCommitFile.writeAsStringSync(preCommitDemo);

  processRun(
    executable: 'dart',
    arguments: 'pub get',
    workingDirectory: analyzerPluginPath,
  );
}

void clearPluginManagerCache() {
  String? home;
  final Map<String, String> envVars = Platform.environment;
  if (Platform.isMacOS) {
    home = envVars['HOME'];
  } else if (Platform.isLinux) {
    home = envVars['HOME'];
  } else if (Platform.isWindows) {
    home = envVars['UserProfile'];
  }

  if (home != null) {
    Directory? directory;
    // macos:  `/Users/user_name/.dartServer/.plugin_manager/`
    // windows: `C:\Users\user_name\AppData\Local\.dartServer\.plugin_manager\`
    if (Platform.isMacOS) {
      directory = Directory(path.join(home, '.dartServer', '.plugin_manager'));
    } else if (Platform.isLinux) {
      directory = Directory(path.join(home, '.dartServer', '.plugin_manager'));
    } else if (Platform.isWindows) {
      directory = Directory(path.join(
          home, 'AppData', 'Local', '.dartServer', '.plugin_manager'));
    }

    if (directory != null && directory.existsSync()) {
      print(green.wrap('clear plugin_manager cache successfully!'));
      directory.deleteSync(recursive: true);
    }
  }
}

final String preCommitDartFile =
    path.join('tools', 'analyzer_plugin', 'bin', 'pre_commit.dart');

void creatPreCommitSH() {
  final String gitRoot = processRun(
    executable: 'git',
    arguments: 'rev-parse --show-toplevel',
    //runInShell: true,
    printInfo: false,
  ).trim();

  final File preCommitSH =
      File(path.join(gitRoot, '.git', 'hooks', 'pre-commit'));

  final File? file = findPreCommitFile(Directory(gitRoot));
  if (file != null) {
    if (preCommitSH.existsSync()) {
      preCommitSH.deleteSync();
    }
    preCommitSH.createSync();
    final String source = Directory.current.path;
    final File localConfig = File(path.join(source, 'pre-commit'));
    String demo = preCommitSHDemo;
    if (localConfig.existsSync()) {
      demo = localConfig.readAsStringSync();
    }
    preCommitSH.writeAsString(
      demo
          .replaceAll(
            '{0}',
            source,
          )
          .replaceAll('{1}', file.path),
    );
    if (Platform.isMacOS || Platform.isLinux) {
      processRun(
        executable: 'chmod',
        arguments: '777 ${preCommitSH.path}',
        printInfo: false,
      );
    }
    print('${preCommitSH.path} has created');
  } else {
    print(
        'not find pre_commit.dart, please run \'candies_analyzer_plugin plugin_name\' first.');
  }
}

File? findPreCommitFile(Directory directory) {
  for (final FileSystemEntity file in directory.listSync()) {
    if (file is Directory && !path.basename(file.path).startsWith('.')) {
      final File? dartFile = findPreCommitFile(file);
      if (dartFile != null) {
        return dartFile;
      }
    } else if (file is File && file.path.endsWith(preCommitDartFile)) {
      return file;
    }
  }

  return null;
}

const String pluginDemo = '''
import 'dart:convert';
import 'dart:isolate';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';
import 'package:analyzer/src/pubspec/pubspec_validator.dart';

CandiesAnalyzerPlugin get plugin => CustomLintPlugin();

// This file must be 'plugin.dart'
void main(List<String> args, SendPort sendPort) {
  // for performance, default is false, if you want to check log, set it to true.
  CandiesAnalyzerPluginLogger().shouldLog = false;  
  CandiesAnalyzerPluginStarter.start(
    args,
    sendPort,
    plugin: plugin,
  );
}

class CustomLintPlugin extends CandiesAnalyzerPlugin {
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
  String? get url =>
      'https://github.com/fluttercandies/candies_analyzer_plugin';

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
    DartAnalysisError error,
    CandiesAnalyzerPluginConfig config,
  ) async {
    final ResolvedUnitResult resolvedUnitResult = error.result;

    final Iterable<DartAnalysisError> cacheErrors = config
        .getCacheErrors(resolvedUnitResult.path, code: code)
        .whereType<DartAnalysisError>();

    final Map<DartAnalysisError, Set<SyntacticEntity>> references =
        _findClassReferences(cacheErrors, resolvedUnitResult);

    return <SourceChange>[
      await getDartFix(
        resolvedUnitResult: resolvedUnitResult,
        message: 'Use Candies as a class prefix.',
        buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
          _fix(
            error,
            resolvedUnitResult,
            dartFileEditBuilder,
            references[error]!,
          );
          dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
        },
      ),
      if (cacheErrors.length > 1)
        await getDartFix(
          resolvedUnitResult: resolvedUnitResult,
          message: 'Use Candies as a class prefix where possible in file.',
          buildDartFileEdit: (DartFileEditBuilder dartFileEditBuilder) {
            for (final DartAnalysisError error in cacheErrors) {
              _fix(
                error,
                resolvedUnitResult,
                dartFileEditBuilder,
                references[error]!,
              );
            }
            dartFileEditBuilder.formatAll(resolvedUnitResult.unit);
          },
        ),
    ];
  }

  void _fix(
    DartAnalysisError error,
    ResolvedUnitResult resolvedUnitResult,
    DartFileEditBuilder dartFileEditBuilder,
    Set<SyntacticEntity> references,
  ) {
    final AstNode astNode = error.astNode;
    // get name node
    final Token nameNode = (astNode as ClassDeclaration).name2;
    final String nameString = nameNode.lexeme;

    final int startIndex = _getClassNameStartIndex(nameString);
    final String replace =
        '\${nameString.substring(0, startIndex)}Candies\${nameString.substring(startIndex)}';

    for (final SyntacticEntity match in references) {
      dartFileEditBuilder.addSimpleReplacement(
          SourceRange(match.offset, match.length), replace);
    }
  }

  Map<DartAnalysisError, Set<SyntacticEntity>> _findClassReferences(
    Iterable<DartAnalysisError> errors,
    ResolvedUnitResult resolvedUnitResult,
  ) {
    final Map<DartAnalysisError, Set<SyntacticEntity>> references =
        <DartAnalysisError, Set<SyntacticEntity>>{};
    final Map<String, DartAnalysisError> classNames =
        <String, DartAnalysisError>{};

    for (final DartAnalysisError error in errors) {
      classNames[(error.astNode as ClassDeclaration).name2.lexeme] = error;
      references[error] = <SyntacticEntity>{};
    }

    resolvedUnitResult.unit
        .accept(_FindClassReferenceVisitor(references, classNames));

    return references;
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

class _FindClassReferenceVisitor extends GeneralizingAstVisitor<void> {
  _FindClassReferenceVisitor(this.references, this.classNames);
  final Map<DartAnalysisError, Set<SyntacticEntity>> references;
  final Map<String, DartAnalysisError> classNames;

  @override
  void visitNode(AstNode node) {
    if (node.childEntities.length == 1) {
      final String source = node.toSource();
      if (classNames.keys.contains(source)) {
        references[classNames[source]]!.add(node);
        return;
      }
    }
    super.visitNode(node);
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
  candies_analyzer_plugin: any
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
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';
import 'plugin.dart';

Future<void> main(List<String> args) async {
  final String root = Directory.current.parent.parent.parent.path;
  final AnalysisContextCollection collection =
      AnalysisContextCollection(includedPaths: <String>[root]);

  final CandiesAnalyzerPlugin myPlugin = plugin;
  for (final AnalysisContext context in collection.contexts) {
    final CandiesAnalyzerPluginConfig config = myPlugin.configs.putIfAbsent(
        context.root,
        () => CandiesAnalyzerPluginConfig(
              context: context,
              pluginName: myPlugin.name,
              dartLints: myPlugin.dartLints,
              astVisitor: myPlugin.astVisitor,
              yamlLints: myPlugin.yamlLints,
              genericLints: myPlugin.genericLints,
            ));

    if (!config.shouldAnalyze) {
      continue;
    }
    for (final String file in context.contextRoot.analyzedFiles()) {
      if (!config.include(file)) {
        continue;
      }
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

const String preCommitDemo = '''
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
    print('No issues found!  \${seconds}s');
  } else {
    print('');
    print(errors
        .map((String e) => '  \${e.getHighlightErrorInfo()}')
        .join('\n\n'));
    print('\n\${errors.length} issues found.'
            .wrapAnsiCode(foregroundColor: AnsiCodeForegroundColor.red) +
        '  \${seconds}s');
    print('Please fix the errors and then submit the code.'
        .wrapAnsiCode(foregroundColor: AnsiCodeForegroundColor.red));
  }
}
''';

const String preCommitSHDemo = '''
#!/bin/sh

# project path
base_dir="{0}"

dart format "\$base_dir"

# pre_commit.dart path
pre_commit="{1}"
 
echo "Checking the code before submit..."
echo "Analyzing \$base_dir..."

info=\$(dart "\$pre_commit" "\$base_dir")

echo "\$info"

if [[ -n \$info && \$info != *"No issues found"* ]];then
exit 1
fi
''';

String processRun({
  required String executable,
  String? arguments,
  bool runInShell = false,
  String? workingDirectory,
  List<String>? argumentsList,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
  bool printInfo = true,
}) {
  final List<String> temp = <String>[];

  if (arguments != null) {
    temp.addAll(
        arguments.split(' ')..removeWhere((String x) => x.trim() == ''));
  }

  if (argumentsList != null) {
    temp.addAll(argumentsList);
  }
  if (printInfo) {
    print(yellow.wrap('$executable $temp'));
  }
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
  if (printInfo) {
    print(green.wrap('stdout: $stdout\n'));
  }

  return stdout;
}

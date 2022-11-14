# candies_lints

[![pub package](https://img.shields.io/pub/v/candies_lints.svg)](https://pub.dartlang.org/packages/candies_lints) [![GitHub stars](https://img.shields.io/github/stars/fluttercandies/candies_lints)](https://github.com/fluttercandies/candies_lints/stargazers) [![GitHub forks](https://img.shields.io/github/forks/fluttercandies/candies_lints)](https://github.com/fluttercandies/candies_lints/network) [![GitHub license](https://img.shields.io/github/license/fluttercandies/candies_lints)](https://github.com/fluttercandies/candies_lints/blob/master/LICENSE) [![GitHub issues](https://img.shields.io/github/issues/fluttercandies/candies_lints)](https://github.com/fluttercandies/candies_lints/issues) <a target="_blank" href="https://jq.qq.com/?_wv=1027&k=5bcc0gy"><img border="0" src="https://pub.idqqimg.com/wpa/images/group.png" alt="flutter-candies" title="flutter-candies"></a>

Languages: English | [中文简体](README-ZH.md)

## Description

The plugin to help create custom lint quickly.

- [candies_lints](#candies_lints)
  - [Description](#description)
  - [Create Template](#create-template)
  - [Add your lint](#add-your-lint)
    - [start plugin](#start-plugin)
    - [create a lint](#create-a-lint)
      - [dart lint](#dart-lint)
      - [yaml lint](#yaml-lint)
      - [generic lint](#generic-lint)
  - [Debug](#debug)
    - [debug lint](#debug-lint)
    - [update code](#update-code)
    - [restart server](#restart-server)
  - [Log](#log)
  - [Config](#config)
    - [disable a lint](#disable-a-lint)
    - [include](#include)
    - [custom lint severity](#custom-lint-severity)
  - [Default lints](#default-lints)
    - [PerferClassPrefix](#perferclassprefix)
    - [PreferAssetConst](#preferassetconst)
    - [PreferNamedRoutes](#prefernamedroutes)
    - [PerferSafeSetState](#perfersafesetstate)
    - [MustCallSuperDispose](#mustcallsuperdispose)
    - [EndCallSuperDispose](#endcallsuperdispose)
  - [Note](#note)
    - [print lag](#print-lag)
    - [pubspec.yaml and analysis_options.yaml](#pubspecyaml-and-analysis_optionsyaml)
    - [quick fixes are only supported for dart files.](#quick-fixes-are-only-supported-for-dart-files)

* [example](https://github.com/fluttercandies/candies_lints/example)

* [analyzer_plugin doc](https://github.com/dart-lang/sdk/blob/master/pkg/analyzer_plugin/doc/tutorial/tutorial.md)
## Create Template

1. activate plugin

   run `dart pub global activate candies_lints`


2. cd to your project

   Let us suppose:
   
   your project is `example`
   
   your lint plugin is `custom_lint`
   
   run `candies_lints custom_lint`, a simple lint plugin is generated.

3. add `custom_lint` into `dev_dependencies` of the root `pubspec.yaml`  

```yaml
dev_dependencies:
  # zmtzawqlp  
  custom_lint:
    path: custom_lint/
```

4. add `custom_lint` into `analyzer plugins` of the root `analysis_options.yaml`

```yaml
analyzer:
  # zmtzawqlp  
  plugins:
    custom_lint
```

after analysis are finished, you will see some custom lint in your ide.

## Add your lint

find `plugin.dart` base on following project tree

```
├─ example
│  ├─ custom_lint
│  │  └─ tools
│  │     └─ analyzer_plugin
│  │        ├─ bin
│  │        │  └─ plugin.dart
```

`plugin.dart` is the entrance of plugin.

### start plugin

we start plugin in this file.

``` dart
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
  String get name => 'custom_lint';

  @override
  List<String> get fileGlobsToAnalyze => const <String>[
        '**/*.dart',
        '**/*.yaml',
        '**/*.json',
      ];

  @override
  List<DartLint> get dartLints => <DartLint>[
        // add your dart lint here
        PerferCandiesClassPrefix(),
        ...super.dartLints,
      ];

  @override
  List<YamlLint> get yamlLints => <YamlLint>[RemoveDependency(package: 'path')];

  @override
  List<GenericLint> get genericLints => <GenericLint>[RemoveDuplicateValue()];
}
```

### create a lint

you just need to make a custom lint which extends from  `DartLint` ,`YamlLint`, `GenericLint`.


Properties: 

| Property | Description  | Default |
| --- | --- | --- |
| code | The name, as a string, of the error code associated with this error. | required | 
| message | The message to be displayed for this error. The message should indicate what is wrong with the code and why it is wrong. | required | 
| url | The URL of a page containing documentation associated with this error. |  | 
| type | The type of the error. <br/>CHECKED_MODE_COMPILE_TIME_ERROR<br/>COMPILE_TIME_ERROR<br/>HINT<br/>LINT<br/>STATIC_TYPE_WARNING<br/>STATIC_WARNING<br/>SYNTACTIC_ERROR<br/>TODO | The default is LINT. | 
| severity | The severity of the error.<br/>INFO<br/>WARNING<br/>ERROR | The default is INFO. | 
| correction | The correction message to be displayed for this error. The correction message should indicate how the user can fix the error. The field is omitted if there is no correction message associated with the error code. |  | 
| contextMessages | Additional messages associated with this diagnostic that provide context to help the user understand the diagnostic. |  | 


Important methodes:

| Method | Description  | Override |
| --- | --- | --- |
| matchLint | return whether is match lint. | must | 
| getDartFixes/getYamlFixes/getGenericFixes | return fixes if has. | getYamlFixes/getGenericFixes doesn't work for now, leave it in case dart team maybe support it someday in the future, see [issue](https://github.com/dart-lang/sdk/issues/50306)  | 


#### dart lint

Here is a demo for a dart lint:

``` dart
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
              '${nameString.substring(0, startIndex)}Candies${nameString.substring(startIndex)}';

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
```
#### yaml lint

Here is a demo for a yaml lint:

``` dart
class RemoveDependency extends YamlLint {
  RemoveDependency({required this.package});
  final String package;
  @override
  String get code => 'remove_${package}_dependency';

  @override
  String get message => 'don\'t use $package!';

  @override
  String? get correction => 'Remove $package dependency';

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
        final int index = content.substring(start, end).indexOf('$package: ');
        start += index;
        yield SourceRange(start, get.span.end.offset - start);
      }
    }
  }
}
```

#### generic lint

Here is a demo for a generic lint:

``` dart
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
          final int start = content.indexOf('"$key"');
          final dynamic value = duplicate[key];
          final int end = content.indexOf(
                '"$value"',
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
```

## Debug


### debug lint

find `debug.dart` base on following project tree

```
├─ example
│  ├─ custom_lint
│  │  └─ tools
│  │     └─ analyzer_plugin
│  │        ├─ bin
│  │        │  └─ debug.dart
```

change root to which you want to debug, default is example folder.
 
``` dart
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
```

### update code

```
├─ example
│  ├─ custom_lint
│  │  └─ tools
│  │     └─ analyzer_plugin
```

you have two options to update new code into dartServer.

1. delete .plugin_manager folder

Note, `analyzer_plugin` folder will be copyed into `.plugin_manager` and create a folder base on encrypt plugin path.

macos:  `/Users/user_name/.dartServer/.plugin_manager/`

windows: `C:\Users\user_name\AppData\Local\.dartServer\.plugin_manager\`

if your code is changed, please remove the files under `.plugin_manager`.

or you can run `candies_lints clear_cache` to remove the files under `.plugin_manager`. 


1. write new code under custom_lint folder

you can write new code under custom_lint, for exmaple, in custom_lint.dart. 

```
├─ example
│  ├─ custom_lint
│  │  ├─ lib
│  │  │  └─ custom_lint.dart
```

so you should add `custom_lint` dependencies into `analyzer_plugin\pubspec.yaml`

you should use `absolute path` due to analyzer_plugin folder will copy to `.plugin_manager`.

if your don't publish `custom_lint` as new package, i don't suggest do as this.

```
├─ example
│  ├─ custom_lint
│  │  ├─ lib
│  │  │  └─ custom_lint.dart
│  │  └─ tools
│  │     └─ analyzer_plugin
│  │        ├─ analysis_options.yaml
```

``` yaml
dependencies:
  custom_lint: 
    # absolute path  
    path: xxx/xxx/custom_lint
  candies_lints: any
  path: any
  analyzer: any
  analyzer_plugin: any
```

### restart server

after update code, you should restart analysis server by following steps in vscode.

1. find `Command Palette` in `View`

![](command_palette.png)

2. enter `Restart Analysis Server`

![](analysis_command.png)


now, you can see the new change.

## Log

Under the project  `custom_lint.log` will be generated.

1. you can close Log. 

   `CandiesLintsLogger().shouldLog = false;`

2. you can custom log name 

   `CandiesLintsLogger().logFileName = 'your name';`

3. log info
   
``` dart
   CandiesLintsLogger().log(
        'info',
        // which location custom_lint.log will be generated
        root: result.root,
      );
```

4. log error

``` dart
   CandiesLintsLogger().logError(
     'analyze file failed:',
     root: analysisContext.root,
     error: e,
     stackTrace: stackTrace,
   );
```

## Config

### disable a lint

As default, all of the custom lints are enable. And you can also write a config in analysis_options.yaml to disable they.

1. add ignore for a lint.

``` yaml
analyzer:
  errors:
    perfer_candies_class_prefix: ignore
```

2. exclude files
  
``` yaml
analyzer:
  exclude:
    - lib/exclude/*.dart
```

3. disable a lint

``` yaml
linter:
  rules:
    # disable a lint
    perfer_candies_class_prefix: false 
```

### include

we can define `include` tag under `custom_lint` (it's your plugin name).
it means that we only analyze the include files.

``` yaml

# your plugin name
custom_lint:
  # if we define this, we only analyze include files
  include: 
    - lib/include/*.dart
```

### custom lint severity

you can change lint severity by following setting.

change the severity of `perfer_candies_class_prefix` from `info` to `warning`.

support `warning` , `info` , `error`.

``` yaml
analyzer:
  errors:
    # override error severity
    perfer_candies_class_prefix: warning
```

## Default lints

### PerferClassPrefix

Define a class name start with prefix

``` dart
class PerferClassPrefix extends DartLint {
  PerferClassPrefix(this.prefix);

  final String prefix;

  @override
  String get code => 'perfer_${prefix}_class_prefix';
}
```

### PreferAssetConst

Prefer to use asset const instead of a string.

``` dart
class PreferAssetConst extends DartLint {
  @override
  String get code => 'prefer_asset_const';
  @override
  String? get url => 'https://pub.dev/packages/assets_generator';  
}
```
### PreferNamedRoutes

Prefer to use named routes.

``` dart
class PreferNamedRoutes extends DartLint {
  @override
  String get code => 'prefer_named_routes';
  @override
  String? get url => 'https://pub.dev/packages/ff_annotation_route';  
}
```

### PerferSafeSetState

Prefer to check mounted before setState

``` dart
class PerferSafeSetState extends DartLint {
  @override
  String get code => 'prefer_safe_setState';
}
```
### MustCallSuperDispose

Implementations of this method should end with a call to the inherited method, as in `super.dispose()`.

``` dart
class MustCallSuperDispose extends DartLint with CallSuperDisposeMixin {
  @override
  String get code => 'must_call_super_dispose';
}
```

### EndCallSuperDispose

Should call `super.dispose()` at the end of this method.

``` dart
class EndCallSuperDispose extends DartLint with CallSuperDisposeMixin {
  @override
  String get code => 'end_call_super_dispose';
}
```

## Note 
### print lag

don't write `print` in the process of analyzing in your plugin, analysis will lag.

### pubspec.yaml and analysis_options.yaml

you must do following things to support your project to be analyzed.
   
1. add `custom_lint` into `dev_dependencies` in `pubspec.yaml` , see [pubspec.yaml](https://github.com/fluttercandies/candies_lints/example/pubspec.yaml)
   
2. add `custom_lint` into `analyzer` `plugins` in `analysis_options.yaml` see [analysis_options.yaml](https://github.com/fluttercandies/candies_lints/example/analysis_options.yaml)

### quick fixes are only supported for dart files.

[issue](https://github.com/dart-lang/sdk/issues/50306)




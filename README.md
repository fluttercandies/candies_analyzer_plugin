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
  - [Debug](#debug)
    - [debug lint](#debug-lint)
    - [update code](#update-code)
    - [restart server](#restart-server)
  - [Log](#log)
  - [Config](#config)
    - [disable a lint](#disable-a-lint)
    - [include](#include)
    - [custom a lint](#custom-a-lint)
  - [Note](#note)

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

3. add `custom_lint` into dev_dependencies in root `pubspec.yaml`  

```yaml
dev_dependencies:
  # zmtzawqlp  
  custom_lint:
    path: custom_lint/
```

4. add `custom_lint` into analyzer plugins in root `analysis_options.yaml`

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
void main(List<String> args, SendPort sendPort) {
  CandiesLintsStarter.start(
    args,
    sendPort,
    plugin: CustomLintPlugin(),
  );
}

class CustomLintPlugin extends CandiesLintsPlugin {
  @override
  String get name => 'custom_lint';
  @override
  List<CandyLint> get lints => <CandyLint>[
        // add your line here
        PerferCandiesClassPrefix(),
        ...super.lints,
      ];
}
```

### create a lint

you just need to make a custom lint which extends `CandyLint`.


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
| getFixes | return fixes if has. |  | 


Here is a demo for a custom lint:

``` dart
class PerferCandiesClassPrefix extends CandyLint {
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
  Future<List<SourceChange>> getFixes(
    ResolvedUnitResult resolvedUnitResult,
    AstNode astNode,
  ) async {
    // get name node
    final Token nameNode = (astNode as ClassDeclaration).name2;
    final String nameString = nameNode.toString();
    return <SourceChange>[
      await getFix(
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

change debugFilePath to the file path which you want to debug.
 
``` dart
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
```

### update code

```
├─ example
│  ├─ custom_lint
│  │  └─ tools
│  │     └─ analyzer_plugin
```

you have two options to update new code into dartServer.

1. update .plugin_manager folder

Note, `analyzer_plugin` folder will be copy into following, and it has cache.

macos:  `/Users/user_name/.dartServer/.plugin_manager/`

windows: `C:\Users\user_name\AppData\Local\.dartServer\.plugin_manager\`

if your code is changed, please remove the files under `.plugin_manager`.


2. write new code under custom_lint folder

you can write new code under custom_lint, for exmaple, in custom_lint.dart. 

```
├─ example
│  ├─ custom_lint
│  │  ├─ lib
│  │  │  └─ custom_lint.dart
```

so you should add `custom_lint` dependencies into `analyzer_plugin\analysis_options.yaml`

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

1. find Command Palette in View

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

### custom a lint

you can change lint severity by following setting.

change the severity of `perfer_candies_class_prefix` from `info` to `warning`.

``` yaml
analyzer:
  errors:
    # override error severity
    perfer_candies_class_prefix: warning
```


## Note 


1. don't write `print` in the process of analyzing in your plugin, analysis server will crash.
2. you must do following things to support your project to be analyzed.
   
   add `custom_lint` into `dev_dependencies` in `pubspec.yaml` , see [pubspec.yaml](https://github.com/fluttercandies/candies_lints/example/pubspec.yaml)
   add `custom_lint` into `analyzer` `plugins` in `analysis_options.yaml` see [analysis_options.yaml](https://github.com/fluttercandies/candies_lints/example/analysis_options.yaml)





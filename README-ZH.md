# candies_lints

[![pub package](https://img.shields.io/pub/v/candies_lints.svg)](https://pub.dartlang.org/packages/candies_lints) [![GitHub stars](https://img.shields.io/github/stars/fluttercandies/candies_lints)](https://github.com/fluttercandies/candies_lints/stargazers) [![GitHub forks](https://img.shields.io/github/forks/fluttercandies/candies_lints)](https://github.com/fluttercandies/candies_lints/network) [![GitHub license](https://img.shields.io/github/license/fluttercandies/candies_lints)](https://github.com/fluttercandies/candies_lints/blob/master/LICENSE) [![GitHub issues](https://img.shields.io/github/issues/fluttercandies/candies_lints)](https://github.com/fluttercandies/candies_lints/issues) <a target="_blank" href="https://jq.qq.com/?_wv=1027&k=5bcc0gy"><img border="0" src="https://pub.idqqimg.com/wpa/images/group.png" alt="flutter-candies" title="flutter-candies"></a>

语言: [English](README.md) | 中文简体

## 描述

帮助快速创建自定义 lint 的插件.

- [candies_lints](#candies_lints)
  - [描述](#描述)
  - [模版创建](#模版创建)
  - [增添你的 lint](#增添你的-lint)
    - [启动插件](#启动插件)
    - [创建一个 lint](#创建一个-lint)
      - [dart lint](#dart-lint)
      - [yaml lint](#yaml-lint)
      - [generic lint](#generic-lint)
  - [调试](#调试)
    - [调试错误](#调试错误)
    - [更新代码](#更新代码)
    - [重启 dart analysis 服务](#重启-dart-analysis-服务)
  - [Log](#log)
  - [配置](#配置)
    - [禁止一个 lint](#禁止一个-lint)
    - [包含文件](#包含文件)
    - [自定义 lint 严肃性](#自定义-lint-严肃性)
  - [Default lints](#default-lints)
    - [PerferClassPrefix](#perferclassprefix)
    - [PreferAssetConst](#preferassetconst)
    - [PreferNamedRoutes](#prefernamedroutes)
    - [PerferSafeSetState](#perfersafesetstate)
  - [注意事项](#注意事项)
    - [print lag](#print-lag)
    - [pubspec.yaml and analysis_options.yaml](#pubspecyaml-and-analysis_optionsyaml)
    - [快速修复只支持 dart 文件.](#快速修复只支持-dart-文件)

* [example](https://github.com/fluttercandies/candies_lints/example)

* [analyzer_plugin 文档](https://github.com/dart-lang/sdk/blob/master/pkg/analyzer_plugin/doc/tutorial/tutorial.md)
  
## 模版创建

1. 激活插件

   执行命令 `dart pub global activate candies_lints`


2. 到你的项目的根目录

   假设:
   
   你的项目叫做 `example`
   
   你想创建的插件叫做 `custom_lint`
   
   执行命令 `candies_lints custom_lint`, 一个简单插件模板创建成功.

3. 将 `custom_lint` 增加到 根目录 `pubspec.yaml` 的 `dev_dependencies` 中

```yaml
dev_dependencies:
  # zmtzawqlp  
  custom_lint:
    path: custom_lint/
```

4. 将 `custom_lint` 增加到根目录 `analysis_options.yaml` 的 `analyzer plugins` tag 下面

```yaml
analyzer:
  # zmtzawqlp  
  plugins:
    custom_lint
```

当分析结束的时候，在你的 ide 中可以看到一些自定义的 lint 。

## 增添你的 lint

在下面的项目结构下面找到  `plugin.dart`

```
├─ example
│  ├─ custom_lint
│  │  └─ tools
│  │     └─ analyzer_plugin
│  │        ├─ bin
│  │        │  └─ plugin.dart
```

`plugin.dart` 是整个插件的入口。

### 启动插件

我们将在 main 方法中启动我们的插件.

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

### 创建一个 lint

你只需要创一个新的类来继承 `DartLint` ,`YamlLint`, `GenericLint` 即可。


属性: 

| 属性 | 描述  | 默认 |
| --- | --- | --- |
| code | 这个错误的名字，唯一. | 必填 | 
| message | 描述这个错误的信息 | required | 
| url | 这个错误文档的链接. |  | 
| type | 在IDE中错误的类型. <br/>CHECKED_MODE_COMPILE_TIME_ERROR<br/>COMPILE_TIME_ERROR<br/>HINT<br/>LINT<br/>STATIC_TYPE_WARNING<br/>STATIC_WARNING<br/>SYNTACTIC_ERROR<br/>TODO | 默认为 LINT. | 
| severity | 这个错误的严肃性(一般我们修改的是这个).<br/>INFO<br/>WARNING<br/>ERROR | 默认为 INFO. | 
| correction | 修复这个错误的一些描述. |  | 
| contextMessages | 额外的信息帮助修复这个错误。 |  | 


重要的方法:

| 方法 | 描述  | 重载 |
| --- | --- | --- |
| matchLint | 判断是否是你定义的lint | 必须 | 
| getFixes | 返回快速修复 |  | 
| getDartFixes/getYamlFixes/getGenericFixes | 返回快速修复 | getYamlFixes/getGenericFixes 没有效果，保留它以备 dart team 未来某天支持, 查看 [issue](https://github.com/dart-lang/sdk/issues/50306)  | 

#### dart lint

下面是一个 dart lint 的例子:

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
#### yaml lint

下面是一个 yaml lint 的例子:

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

下面是一个 generic lint 的例子:

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

## 调试

### 调试错误

在下面的项目结构下面找到  `debug.dart`，已经自动为你创建了 debug 的例子。你可以通过调试来编写符合你条件的 lint

```
├─ example
│  ├─ custom_lint
│  │  └─ tools
│  │     └─ analyzer_plugin
│  │        ├─ bin
│  │        │  └─ debug.dart
```

把 root 修改为你想要调试的项目路径, 默认为 example 的根目录

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

### 更新代码

```
├─ example
│  ├─ custom_lint
│  │  └─ tools
│  │     └─ analyzer_plugin
```

你有2种方式更新代码到 dartServer。


1. 删除 .plugin_manager 文件夹

注意, `analyzer_plugin` 文件夹下面的东西会复制到 `.plugin_manager` 下面，根据插件的路径加密生成对应的文件夹。

macos:  `/Users/user_name/.dartServer/.plugin_manager/`

windows: `C:\Users\user_name\AppData\Local\.dartServer\.plugin_manager\`

如果你的代码改变了, 请删除掉 `.plugin_manager` 下面的文件

或者通过执行 `candies_lints clear_cache` 来删除 `.plugin_manager` 下面的文件. 


1. 把新的代码写到 custom_lint 下面

你可以把新代码写到 custom_lint 下面, 比如在 custom_lint.dart. 

```
├─ example
│  ├─ custom_lint
│  │  ├─ lib
│  │  │  └─ custom_lint.dart
```

如果这样的话，你必须增加 `custom_lint` 引用到 `analyzer_plugin\pubspec.yaml` 当中

你必须使用 `绝对路径`，因为 analyzer_plugin 文件夹是会被复制到 `.plugin_manager` 下面的.

如果你不是要发布一个新的 package 的话，我不建议你使用第2种方式。


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

### 重启 dart analysis 服务

更新完毕代码之后，你可以通过在 vscode 中，通过下面的方式重启服务。

1. 在 `View` 下面找到 `Command Palette`

![](command_palette.png)

2. 输入 `Restart Analysis Server`

![](analysis_command.png)


分析结束之后，你可以看到最新的结果.

## Log

在被分析的项目根目录会生成  `custom_lint.log`，用于查看分析过程的信息。

1. 你可以关闭. 

   `CandiesLintsLogger().shouldLog = false;`

2. 你可以更改日志的名字 

   `CandiesLintsLogger().logFileName = 'your name';`

3. 记录信息
   
``` dart
   CandiesLintsLogger().log(
        'info',
        // which location custom_lint.log will be generated
        root: result.root,
      );
```

4. 记录错误

``` dart
   CandiesLintsLogger().logError(
     'analyze file failed:',
     root: analysisContext.root,
     error: e,
     stackTrace: stackTrace,
   );
```

## 配置

### 禁止一个 lint

编写的自定义 lints 默认是全部开启的。当然你可以通过在 analysis_options.yaml 增加配置来禁止它。

1. 使用 ignore tag 来禁止.

``` yaml
analyzer:
  errors:
    perfer_candies_class_prefix: ignore
```

2. 使用 exclude 来过滤掉不想分析的文件
  
``` yaml
analyzer:
  exclude:
    - lib/exclude/*.dart
```

3. 通过将某个lint 设置为 false

``` yaml
linter:
  rules:
    # disable a lint
    perfer_candies_class_prefix: false 
```

### 包含文件

我们可以通过在 `custom_lint`(你定义的插件名字) 下面的 `include` 标记下面增加包含的文件。
如果我们做了这个设置，那么我们就只会分析这些文件。

``` yaml

# your plugin name
custom_lint:
  # if we define this, we only analyze include files
  include: 
    - lib/include/*.dart
```

### 自定义 lint 严肃性

你可以设置某个 lint 的严肃性。

比如 `perfer_candies_class_prefix` 把它的严肃性从 `info` 改为 `warning`.

支持 `warning` , `info` , `error`.

``` yaml
analyzer:
  errors:
    # override error severity
    perfer_candies_class_prefix: warning
```

## Default lints

### PerferClassPrefix

全部的类已某个前缀开始

``` dart
class PerferClassPrefix extends DartLint {
  PerferClassPrefix(this.prefix);

  final String prefix;

  @override
  String get code => 'perfer_${prefix}_class_prefix';
}
```

### PreferAssetConst

asset 资源使用不要直接写字符串，而应该使用定义好的 const

``` dart
class PreferAssetConst extends DartLint {
  @override
  String get code => 'prefer_asset_const';
}
```
### PreferNamedRoutes

推荐使用命名路由

``` dart
class PreferNamedRoutes extends DartLint {
  @override
  String get code => 'prefer_named_routes';
}
```

### PerferSafeSetState

在使用 `setState` 之前请先检查 `mounted`

``` dart
class PerferSafeSetState extends DartLint {
  @override
  String get code => 'prefer_safe_setState';
}
```


## 注意事项 
### print lag

不要在插件的分析代码中使用 `print` ，这会导致 analysis 卡顿

### pubspec.yaml and analysis_options.yaml

只有当你在 `pubspec.yaml` 和 `analysis_options.yaml` 中添加了 `custom_lint`，分析才会进行
   
1. 将 `custom_lint` 添加到  `pubspec.yaml` 中的 `dev_dependencies`  , 查看 [pubspec.yaml](https://github.com/fluttercandies/candies_lints/example/pubspec.yaml)
   
2. 将 `custom_lint` 添加到 `analysis_options.yaml` 中的 `analyzer` `plugins` ，查看 [analysis_options.yaml](https://github.com/fluttercandies/candies_lints/example/analysis_options.yaml)


### 快速修复只支持 dart 文件.

[issue](https://github.com/dart-lang/sdk/issues/50306)


import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' as error;
import 'package:analyzer/source/error_processor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_analyzer_plugin/src/error/lints/lint.dart';
import 'package:path/path.dart' as path;

import 'ansi_code.dart';

/// The extension for ResolvedUnitResult
extension ResolvedUnitResultE on ResolvedUnitResult {
  /// Return root path
  String get root => session.analysisContext.contextRoot.root.path;

  /// Return line base on offset
  int lineNumber(int offset) => lineInfo.getLocation(offset).lineNumber;
}

/// The extension for AnalysisContext
extension AnalysisContextE on AnalysisContext {
  /// Return root path
  String get root => contextRoot.root.path;

  Future<String> get getSdkRoot async {
    if (this.sdkRoot != null) {
      return this.sdkRoot!.path;
    }
    final SomeLibraryElementResult coreSource =
        await currentSession.getLibraryByUri('dart:core');
    late String sdkRoot;
    final path.Context pathContext =
        currentSession.resourceProvider.pathContext;
    if (coreSource is LibraryElementResult) {
      // "flutter/3.0.0/bin/cache/pkg/sky_engine/lib/core/core.dart"
      sdkRoot = coreSource.element.source.fullName;

      while (pathContext.basename(sdkRoot) != 'lib') {
        final String parent = pathContext.dirname(sdkRoot);
        if (parent == sdkRoot) {
          break;
        }
        sdkRoot = parent;
      }
    } else {
      // flutter/3.0.0/bin/cache/dart-sdk
      sdkRoot = path.dirname(path.dirname(Platform.resolvedExecutable));
    }
    return sdkRoot;
  }

  Future<String?> get flutterSdkRoot async {
    final String sdk = await getSdkRoot;
    final path.Context pathContext =
        currentSession.resourceProvider.pathContext;
    final String tag = pathContext.join(
      'bin',
      'cache',
    );
    // flutter/3.0.0/
    // dart sdk in flutter
    if (sdk.contains(tag)) {
      //
      return sdk.substring(
        0,
        sdk.indexOf(tag),
      );
    }

    return null;
  }
}

/// The extension for DartFileEditBuilder
extension DartFileEditBuilderE on DartFileEditBuilder {
  /// Format all content
  void formatAll(CompilationUnit unit) => format(SourceRange(0, unit.end));
}

extension ErrorProcessorE on ErrorProcessor {
  /// If severity is `null`, this processor will "filter" the associated error code.
  bool get filtered => severity == null;

  bool ignore(CandyLint lint) {
    return filtered && same(lint);
  }

  AnalysisErrorSeverity getSeverity(CandyLint lint) {
    if (same(lint) && !filtered) {
      switch (severity) {
        case error.ErrorSeverity.INFO:
          return AnalysisErrorSeverity.INFO;
        case error.ErrorSeverity.WARNING:
          return AnalysisErrorSeverity.WARNING;
        case error.ErrorSeverity.ERROR:
          return AnalysisErrorSeverity.ERROR;
        default:
      }
    }
    return lint.severity;
  }

  bool same(CandyLint lint) => lint.code.toUpperCase() == code;
}

extension LibraryElementE on LibraryElement {
  bool get isInFlutterSdk {
    final Uri uri = definingCompilationUnit.source.uri;
    if (uri.scheme == 'package') {
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first == 'flutter';
      }
    }
    return false;
  }
}

extension ElementE on Element {
  bool get isInFlutterSdk {
    if (library == null) {
      return false;
    }
    return library!.isInFlutterSdk;
  }

  bool get isInSdk {
    if (library == null) {
      return false;
    }
    return library!.isInSdk;
  }
}

extension SyntacticEntityE on SyntacticEntity {
  int startLineNumber(LineInfo lineInfo) =>
      lineInfo.getLocation(offset).lineNumber;

  int endLineNumber(LineInfo lineInfo) => lineInfo.getLocation(end).lineNumber;
}

extension AnalysisErrorE on AnalysisError {
  String toConsoleInfo(String root) {
    final String link =
        '${path.relative(location.file, from: root)}:${location.startLine}:${location.startColumn}';
    return <String>[
      severity.name.toLowerCase(),
      link,
      message,
      code,
    ].join(ErrorInfoE.separator);
  }
}

extension ErrorInfoE on String {
  static const String separator = ' - ';
  String getHighlightErrorInfo() {
    //    info - bin/pre_commit.dart:17:10 - The value of the local variable 'info' isn't used. Try removing the variable or using it. - unused_local_variable

    final List<String> infos =
        trim().split(separator).map((String e) => e.trim()).toList();
    if (infos.length == 4) {
      infos[1] = infos[1].wrapAnsiCode(
        foregroundColor: AnsiCodeForegroundColor.blue,
        style: AnsiCodeStyle.underlined,
      );
      infos[3] =
          infos[3].wrapAnsiCode(foregroundColor: AnsiCodeForegroundColor.green);

      String severity = infos[0];
      switch (severity) {
        case 'error':
          severity = severity.wrapAnsiCode(
              foregroundColor: AnsiCodeForegroundColor.red);
          break;
        case 'warning':
          severity = severity.wrapAnsiCode(
              foregroundColor: AnsiCodeForegroundColor.yellow);
          break;
        case 'info':
          break;
        default:
      }
      infos[0] = severity;

      return infos.join(separator);
    }

    return this;
  }

  List<String> getErrorsFromDartAnalyze() {
    // Analyzing analyzer_plugin...

    //   info - bin/pre_commit.dart:17:10 - The value of the local variable 'info' isn't used. Try removing the variable or using it. - unused_local_variable

    // 1 issue found.

    if (!contains('No issues found')) {
      final List<String> lines = split('\n');
      lines.removeWhere((String element) => element.trim().isEmpty);
      if (lines.length > 2) {
        lines.removeLast();
        lines.removeAt(0);
      }

      return lines.map((String e) => e.trim()).toList();
    }
    return <String>[];
  }
}

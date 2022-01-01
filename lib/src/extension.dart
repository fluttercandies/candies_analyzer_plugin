import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/error_processor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_analyzer_plugin/src/error/lints/lint.dart';
import 'package:path/path.dart' as path;

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
        case ErrorSeverity.INFO:
          return AnalysisErrorSeverity.INFO;
        case ErrorSeverity.WARNING:
          return AnalysisErrorSeverity.WARNING;
        case ErrorSeverity.ERROR:
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

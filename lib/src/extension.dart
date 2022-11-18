import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/error_processor.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:candies_analyzer_plugin/src/error/lints/lint.dart';

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
    return same(lint) && filtered;
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

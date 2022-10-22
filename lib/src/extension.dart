import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';

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

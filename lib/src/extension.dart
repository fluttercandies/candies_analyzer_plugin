import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';

extension ResolvedUnitResultE on ResolvedUnitResult {
  String get root => session.analysisContext.contextRoot.root.path;
  int lineNumber(int offset) => lineInfo.getLocation(offset).lineNumber;
}

extension AnalysisContextE on AnalysisContext {
  String get root => contextRoot.root.path;
}

extension DartFileEditBuilderE on DartFileEditBuilder {
  void formatAll(CompilationUnit unit) => format(SourceRange(0, unit.end));
}

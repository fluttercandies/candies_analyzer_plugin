import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:candies_analyzer_plugin/src/ignore_info.dart';

/// The cache error for get fixes
class DartAnalysisError extends AnalysisError {
  DartAnalysisError(
    super.severity,
    super.type,
    super.location,
    super.message,
    super.code, {
    super.correction,
    super.url,
    super.contextMessages,
    super.hasFix,
    required this.astNode,
    required this.result,
    required this.ignoreInfo,
  });

  /// The ast node to be used to quick fix
  /// astNode' location is not always equal to this.location
  /// for example, [PerferClassPrefix]
  /// astNode is ClassDeclaration
  /// but location is (astNode as ClassDeclaration).name2
  /// we need full astNode to get more info
  final AstNode astNode;

  /// The result of the file which this error is in.
  final ResolvedUnitResult result;

  /// The ignore info for file which this error is in.
  final CandiesAnalyzerPluginIgnoreInfo ignoreInfo;
}

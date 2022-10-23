import 'package:analyzer_plugin/protocol/protocol_common.dart';

/// The cache error for get fixes
class GenericAnalysisError extends AnalysisError {
  GenericAnalysisError(
    super.severity,
    super.type,
    super.location,
    super.message,
    super.code, {
    super.correction,
    super.url,
    super.contextMessages,
    super.hasFix,
    required this.content,
  });

  /// The file whole content
  final String content;
}

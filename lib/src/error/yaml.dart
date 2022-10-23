import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:candies_lints/candies_lints.dart';

/// The cache error for get fixes
class YamlAnalysisError extends AnalysisError {
  YamlAnalysisError(
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
    required this.root,
  });

  /// The yaml whole content
  final String content;
  final YamlNode root;
}

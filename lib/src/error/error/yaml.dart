import 'package:yaml/yaml.dart';

import 'generic.dart';

/// The cache error for get fixes
class YamlAnalysisError extends GenericAnalysisError {
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
    required super.content,
    required this.root,
  });

  final YamlNode root;
}

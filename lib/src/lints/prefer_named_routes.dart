import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';

import 'lint.dart';

/// The 'prefer_named_routes' lint
class PreferNamedRoutes extends CandyLint {
  @override
  String get code => 'prefer_named_routes';

  @override
  String get message => 'Prefer to use named routes.';

  @override
  String? get correction =>
      'Click \'prefer_named_routes\' to show how to generate named routes const automatically.';

  @override
  String? get url => 'https://pub.dev/packages/ff_annotation_route';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is MethodInvocation) {
      final String methodName = node.methodName.toString();
      final String nodeString = node.toString();
      if ((nodeString.startsWith('Navigator.') ||
              nodeString.contains('MaterialPageRoute') ||
              nodeString.contains('CupertinoPageRoute')) &&
          (methodName.toLowerCase().contains('push') &&
              !methodName.contains('Named'))) {
        return node;
      }
    }
    return null;
  }
}

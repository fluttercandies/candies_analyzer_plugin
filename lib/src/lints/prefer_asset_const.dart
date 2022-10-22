import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';

import 'lint.dart';

/// The 'prefer_asset_const' lint
class PreferAssetConst extends CandyLint {
  @override
  String get code => 'prefer_asset_const';

  @override
  String? get url => 'https://pub.dev/packages/assets_generator';

  @override
  String get message => 'Prefer to use asset const instead of a string.';

  @override
  String? get correction =>
      'Click \'prefer_asset_const\' to show how to generate asset const automatically.';

  bool _isString(ArgumentList argumentList) {
    for (final Expression argument in argumentList.arguments) {
      final String argumentString = argument.toString();
      return argumentString.startsWith('\'') && argumentString.endsWith('\'');
    }
    return false;
  }

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is MethodInvocation) {
      final String astNodeString = node.toString();
      if (astNodeString.startsWith('rootBundle.load') &&
          _isString(node.argumentList)) {
        return node;
      }
    } else if (node is InstanceCreationExpression) {
      final String astNodeString = node.toString();
      if ((astNodeString.startsWith('AssetImage(') ||
              astNodeString.startsWith('Image.asset(')) &&
          _isString(node.argumentList)) {
        return node;
      }
    }

    return null;
  }
}

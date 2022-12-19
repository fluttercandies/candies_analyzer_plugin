// ignore_for_file: implementation_imports

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';

class PreferSingleton extends DartLint {
  @override
  String get code => 'prefer_singleton';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    if (node is InstanceCreationExpressionImpl &&
        (node.parent is PropertyAccess || node.parent is MethodInvocation)) {
      final DartType? type = node.staticType;
      final Element? element = type?.element2;
      final LibraryElement? library = element?.library;
      if (node.keyword?.type != Keyword.CONST &&
          library != null &&
          !library.isInSdk &&
          !library.isInFlutterSdk) {
        if (element != null && element is ClassElementImpl) {
          bool hasSingleton = false;
          for (final ConstructorElement ctor in element.constructors) {
            if (ctor.isDefaultConstructor &&
                ctor.isFactory &&
                ctor.isPublic &&
                !ctor.isGenerative) {
              hasSingleton = true;
              break;
            }
          }
          if (!hasSingleton) {
            return node;
          }
        }
      }
    }
    return null;
  }

  @override
  String get message => 'This is not a singleton, and new Object every time.';

  @override
  String? get correction => 'use as a singleton or use as const ctor';
}

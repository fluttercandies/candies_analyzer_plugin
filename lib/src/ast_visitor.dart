import 'package:analyzer/dart/ast/ast.dart';

import 'package:analyzer/dart/ast/visitor.dart';
import 'package:candies_lints/src/plugin.dart';

class CandiesLintsAstVisitor extends GeneralizingAstVisitor<void>
    with AstVisitorBase {
  @override
  void visitNode(AstNode node) {
    analyze(node);
    super.visitNode(node);
  }
}

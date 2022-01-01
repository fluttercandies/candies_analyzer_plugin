// ignore_for_file: implementation_imports

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';

class GoodDocComments extends DartLint {
  @override
  String get code => 'good_doc_comments';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    CommentToken? precedingComments = node.beginToken.precedingComments;
    if (precedingComments == null && node.beginToken is CommentToken?) {
      precedingComments = node.beginToken as CommentToken?;
    }
    // SINGLE_LINE_COMMENT

    while (precedingComments != null) {
      if (precedingComments.type == TokenType.MULTI_LINE_COMMENT) {
        precedingComments = precedingComments.next as CommentToken?;
        continue;
      }

      //TokenType.SINGLE_LINE_COMMENT;
      // if (precedingComments is DartDocToken) {
      // } else

      final String value = precedingComments.lexeme;
      // =>  ///
      if (precedingComments is DocumentationCommentToken) {
        if ((!value.startsWith('/// ') &&
                // single comment without content
                !(value == '///' &&
                    (precedingComments.previous != null ||
                        precedingComments.next != null))) ||
            node.parent is Block) {
          return precedingComments;
        }
      }
      // is //
      else {
        if (
            //node.parent is! Block ||
            !value.startsWith('// ') &&
                !(value == '//' &&
                    (precedingComments.previous != null ||
                        precedingComments.next != null))) {
          return precedingComments;
        }
      }

      precedingComments = precedingComments.next as CommentToken?;
    }
    return null;
  }

  @override
  String get message =>
      'wrong comments format. (/// xxx) for public api and (// xxx) for other cases.';
}

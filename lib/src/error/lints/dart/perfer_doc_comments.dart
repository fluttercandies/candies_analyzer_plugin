import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:candies_analyzer_plugin/src/error/lints/dart/util/ast.dart'
    as ast;

import 'dart_lint.dart';

/// The 'perfer_doc_comments' lint
/// https://dart.dev/guides/language/effective-dart/documentation
/// The same like public_member_api_docs
/// but we can ignore lint or ignore file by override [ignoreLint] and [ignoreFile]
/// and you can override [isPrivate] and [inPrivateMember] to filter lint
class PerferDocComments extends DartLint {
  @override
  String get code => 'perfer_doc_comments';

  @override
  String? get url =>
      'https://github.com/fluttercandies/candies_analyzer_plugin';

  @override
  AstVisitor<void> get astVisitor => _Visitor(this);

  @override
  SyntacticEntity? matchLint(AstNode node) => null;

  /// DON’T use block comments for documentation
  /// block comments /* Assume we have a valid name. */
  /// doc comments to document members and types
  /// DO use /// doc comments to document members and types.
  /// DO put doc comments before metadata annotations.
  @override
  String get message =>
      'DO use /// doc comments to document members and types.';

  /// Returns `true` if this [node] is the child of a private compilation unit
  /// member.
  bool inPrivateMember(AstNode node) {
    final AstNode? parent = node.parent;
    if (parent is NamedCompilationUnitMember) {
      return isPrivate(parent.name2, parent);
    }
    if (parent is ExtensionDeclaration) {
      return parent.name2 == null || isPrivate(parent.name2, parent);
    }
    return false;
  }

  /// Check if the given identifier has a private name.
  bool isPrivate(Token? name, AstNode parent) {
    return ast.isPrivate(name);
  }

  /// Check whether it's valid comment
  bool isValidDocumentationComment(Declaration node) =>
      node.documentationComment != null;
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.dartLint);
  final PerferDocComments dartLint;
  SyntacticEntity? check(Declaration node) {
    if (!dartLint.isValidDocumentationComment(node) &&
        !isOverridingMember(node)) {
      final SyntacticEntity errorNode = ast.getNodeToAnnotate(node);
      dartLint.reportLint(errorNode, node);
      return errorNode;
    }
    return null;
  }

  void checkMethods(List<ClassMember> members) {
    // Check methods

    final Map<String, MethodDeclaration> getters =
        <String, MethodDeclaration>{};
    final List<MethodDeclaration> setters = <MethodDeclaration>[];

    // Non-getters/setters.
    final List<MethodDeclaration> methods = <MethodDeclaration>[];

    // Identify getter/setter pairs.
    for (final ClassMember member in members) {
      if (member is MethodDeclaration &&
          !dartLint.isPrivate(member.name2, member)) {
        if (member.isGetter) {
          getters[member.name2.lexeme] = member;
        } else if (member.isSetter) {
          setters.add(member);
        } else {
          methods.add(member);
        }
      }
    }

    // Check all getters, and collect offenders along the way.
    final Set<MethodDeclaration> missingDocs = <MethodDeclaration>{};
    for (final MethodDeclaration getter in getters.values) {
      if (check(getter) != null) {
        missingDocs.add(getter);
      }
    }

    // But only setters whose getter is missing a doc.
    for (final MethodDeclaration setter in setters) {
      final MethodDeclaration? getter = getters[setter.name2.lexeme];
      if (getter != null && missingDocs.contains(getter)) {
        check(setter);
      }
    }

    // Check remaining methods.
    methods.forEach(check);
  }

  Element? getOverriddenMember(Element? member) {
    if (member == null) {
      return null;
    }

    final InterfaceElement? interfaceElement =
        member.thisOrAncestorOfType<InterfaceElement>();
    if (interfaceElement == null) {
      return null;
    }
    final String? name = member.name;
    if (name == null) {
      return null;
    }

    for (final ElementAnnotation annotation in member.metadata) {
      if (annotation.isOverride) {
        return annotation.element;
      }
    }

    return null;
    // final Uri libraryUri = interfaceElement.library.source.uri;
    // return context.inheritanceManager.getInherited(
    //   interfaceElement.thisType,
    //   Name(libraryUri, name),
    // );
  }

  bool isOverridingMember(Declaration node) =>
      getOverriddenMember(node.declaredElement2) != null;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _visitMembers(node, node.name2, node.members);
    node.visitChildren(this);
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    if (!dartLint.isPrivate(node.name2, node)) {
      check(node);
    }
    node.visitChildren(this);
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final Map<String, FunctionDeclaration> getters =
        <String, FunctionDeclaration>{};
    final List<FunctionDeclaration> setters = <FunctionDeclaration>[];

    // Check functions.

    // Non-getters/setters.
    final List<FunctionDeclaration> functions = <FunctionDeclaration>[];

    // Identify getter/setter pairs.
    for (final CompilationUnitMember member in node.declarations) {
      if (member is FunctionDeclaration) {
        final Token name = member.name2;
        if (!dartLint.isPrivate(name, member) && name.lexeme != 'main') {
          if (member.isGetter) {
            getters[member.name2.lexeme] = member;
          } else if (member.isSetter) {
            setters.add(member);
          } else {
            functions.add(member);
          }
        }
      }
    }

    // Check all getters, and collect offenders along the way.
    final Set<FunctionDeclaration> missingDocs = <FunctionDeclaration>{};
    for (final FunctionDeclaration getter in getters.values) {
      if (check(getter) != null) {
        missingDocs.add(getter);
      }
    }

    // But only setters whose getter is missing a doc.
    for (final FunctionDeclaration setter in setters) {
      final FunctionDeclaration? getter = getters[setter.name2.lexeme];
      if (getter != null && missingDocs.contains(getter)) {
        check(setter);
      }
    }

    // Check remaining functions.
    functions.forEach(check);

    node.visitChildren(this);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (!dartLint.inPrivateMember(node) &&
        !dartLint.isPrivate(node.name2, node)) {
      check(node);
    }
  }

  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    if (!dartLint.inPrivateMember(node) &&
        !dartLint.isPrivate(node.name2, node)) {
      check(node);
    }
    node.visitChildren(this);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    if (dartLint.isPrivate(node.name2, node)) {
      return;
    }

    check(node);
    checkMethods(node.members);
    node.visitChildren(this);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    if (node.name2 == null || dartLint.isPrivate(node.name2, node)) {
      return;
    }

    check(node);
    checkMethods(node.members);
    node.visitChildren(this);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!dartLint.inPrivateMember(node)) {
      for (final VariableDeclaration field in node.fields.variables) {
        if (!dartLint.isPrivate(field.name2, node)) {
          check(field);
        }
      }
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    if (!dartLint.isPrivate(node.name2, node)) {
      check(node);
    }
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    if (!dartLint.isPrivate(node.name2, node)) {
      check(node);
    }
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _visitMembers(node, node.name2, node.members);
    node.visitChildren(this);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final VariableDeclaration decl in node.variables.variables) {
      if (!dartLint.isPrivate(decl.name2, node)) {
        check(decl);
      }
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (!dartLint.isPrivate(node.name2, node)) {
      check(node);
    }
  }

  void _visitMembers(Declaration node, Token name, List<ClassMember> members) {
    if (dartLint.isPrivate(name, node)) {
      return;
    }

    check(node);
    checkMethods(members);
  }
}

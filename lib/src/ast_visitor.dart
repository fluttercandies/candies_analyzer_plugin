part of 'config.dart';

/// The default AstVisitor to analyze lints
class CandiesLintsAstVisitor extends GeneralizingAstVisitor<void>
    with AstVisitorBase {
  @override
  void visitNode(AstNode node) {
    analyze(node);
    super.visitNode(node);
  }
}

/// AstVisitor to check lint
///
mixin AstVisitorBase on AstVisitor<void> {
  List<DartLint>? _lints;
  List<DartLint> get lints => _lints ??= <DartLint>[];

  bool analyze(AstNode node) {
    bool handle = false;
    for (final DartLint lint in lints) {
      handle = lint.analyze(node) || handle;
    }
    return handle;
  }
}

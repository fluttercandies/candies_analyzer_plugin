// ignore_for_file: implementation_imports

import 'dart:collection';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart'
    as protocol_common;
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';
import 'package:analyzer/src/error/imports_verifier.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';
import 'package:analyzer/src/dart/element/element.dart';

/// https://github.com/dart-lang/sdk/blob/master/pkg/analyzer/lib/src/dart/analysis/library_analyzer.dart#L267

/// The 'unused_file' lint
class UnusedFile extends DartLint with AnalyzeErrorAfterFilesAnalyzed {
  @override
  String get code => 'unused_file';

  @override
  String get message => 'This file is not used.';

  @override
  SyntacticEntity? matchLint(AstNode node) {
    return null;
  }

  static final Map<String, Set<String>> _usedDartFiles =
      <String, Set<String>>{};

  static final Set<String> _unUsedDartFiles = <String>{};

  static void remove(String file) {
    _usedDartFiles.remove(file);
    _unUsedDartFiles.remove(file);
  }

  /// whether import means it's used
  bool get importIsUsed => false;

  @override
  bool get addIgnoreForThisLineFix => false;

  @override
  List<DartAnalysisError> toDartAnalysisErrors({
    required ResolvedUnitResult result,
    required CandiesAnalyzerPluginIgnoreInfo ignoreInfo,
    required CandiesAnalyzerPluginConfig? config,
  }) =>
      <DartAnalysisError>[];

  @override
  void accept(
    ResolvedUnitResult result,
    CandiesAnalyzerPluginIgnoreInfo ignoreInfo,
  ) {
    final CompilationUnit unit = result.unit;
    final String filePath = result.path;
    final Set<String> usedImportedFiles = <String>{};
    _usedDartFiles[filePath] = usedImportedFiles;

    if (ignoreInfo.ignored(code) || result.isPart) {
      CandiesAnalyzerPluginLogger().log(
        'unused file is ignore: ${result.path}}',
        root: result.root,
      );
      usedImportedFiles.add(filePath);
    }

    final _GatherUsedImportedElementsVisitor visitor =
        _GatherUsedImportedElementsVisitor(result.libraryElement);
    unit.accept(visitor);

    // if this file contains entry point
    if (visitor._containsEntrypoint) {
      usedImportedFiles.add(filePath);
    }

    final UsedImportedElements usedImportedElements = visitor.usedElements;

    for (final Element element in usedImportedElements.elements) {
      final String? fullName = element.source?.fullName;
      if (fullName != null) {
        usedImportedFiles.add(fullName);
      }
    }

    for (final ExtensionElement element
        in usedImportedElements.usedExtensions) {
      final String fullName = element.source.fullName;
      usedImportedFiles.add(fullName);
    }

    for (final PrefixElement key in usedImportedElements.prefixMap.keys) {
      for (final Element element in usedImportedElements.prefixMap[key]!) {
        final String? fullName = element.source?.fullName;
        if (fullName != null) {
          usedImportedFiles.add(fullName);
        }
      }
    }

    // find used imports
    //
    final _ImportsVerifier verifier = _ImportsVerifier();
    verifier.addImports(unit);
    verifier.removeUsedElements(usedImportedElements);
    final Set<ImportDirective> usedImports = <ImportDirective>{
      ...verifier._allImports
    };
    if (!importIsUsed) {
      usedImports.removeAll(verifier._unusedImports);
    }

    for (final ImportDirective element in usedImports) {
      final LibraryElement? library = element.element2?.importedLibrary;
      if (library != null && (!library.isInSdk && !library.isInFlutterSdk)) {
        final String? fullName = library.source.fullName;
        if (fullName != null) {
          usedImportedFiles.add(fullName);
        }
      }
    }

    //final ImportsVerifier verifier1 = ImportsVerifier();
  }

  protocol_common.AnalysisError toAnalysisError(
      CandiesAnalyzerPluginConfig config, String path) {
    return protocol_common.AnalysisError(
      config.getSeverity(this),
      type,
      protocol_common.Location(path, 0, 1, 1, 1),
      message,
      code,
      correction: correction,
      contextMessages: contextMessages,
      url: url,
      //hasFix: hasFix,
    );
  }

  @override
  Future<void> handleError(
    CandiesAnalyzerPlugin plugin, {
    AnalysisContext? analysisContext,
  }) async {
    for (final CandiesAnalyzerPluginConfig config in plugin.configs.values) {
      final UnusedFile? unusedFile = config.unusedFile;
      if (unusedFile != null) {
        final Set<String> unusedFiles = _usedDartFiles.keys.toSet();

        if (unusedFiles.isNotEmpty) {
          _usedDartFiles.values.forEach(unusedFiles.removeAll);
        }
        for (final String file in unusedFiles) {
          await _sendUnusedFileErrorNotification(
            file,
            plugin,
            unusedFile,
          );
        }
        if (analysisContext != null) {
          // final Set<String> add =
          //     unusedFiles.difference(UnusedFile.unUsedDartFiles);
          // for (final String element in add) {
          //   await _sendUnusedFileErrorNotification(
          //     element,
          //     plugin,
          //     unusedFile,
          //     remove: false,
          //   );
          // }

          // update
          final Set<String> remove = _unUsedDartFiles.difference(unusedFiles);
          for (final String element in remove) {
            await _sendUnusedFileErrorNotification(
              element,
              plugin,
              unusedFile,
              remove: true,
            );
          }
        }
        // else {}

        _unUsedDartFiles.clear();
        _unUsedDartFiles.addAll(unusedFiles);
        return;
      }
    }

    _unUsedDartFiles.clear();
    _usedDartFiles.clear();
  }

  Future<void> _sendUnusedFileErrorNotification(
    String file,
    CandiesAnalyzerPlugin plugin,
    UnusedFile unusedFile, {
    bool remove = false,
  }) async {
    final AnalysisContext analysisContext =
        plugin.contextCollection.contextFor(file);
    final CandiesAnalyzerPluginConfig? config =
        plugin.configs[analysisContext.root];

    if (config != null) {
      CandiesAnalyzerPluginLogger().log(
        '${remove ? 'remove' : 'add'} unusedFile: $file',
        root: config.context.root,
      );

      final List<protocol_common.AnalysisError> errors =
          <protocol_common.AnalysisError>[
        if (!remove) unusedFile.toAnalysisError(config, file),
      ];
      await plugin.beforeSendAnalysisErrors(
        errors: errors,
        analysisContext: config.context,
        path: file,
        config: config,
      );

      errors.addAll(config.getCacheErrors(file));

      plugin.channel.sendNotification(AnalysisErrorsParams(
        file,
        errors,
      ).toNotification());
    }
  }

  @override
  Stream<AnalysisErrorFixes> toDartAnalysisErrorFixesStream({
    required EditGetFixesParams parameters,
    required AnalysisContext analysisContext,
  }) async* {
    final Set<String> unusedFiles = _usedDartFiles.keys.toSet();
    if (unusedFiles.isNotEmpty) {
      _usedDartFiles.values.forEach(unusedFiles.removeAll);
    }
    if (unusedFiles.contains(parameters.file)) {
      final SomeResolvedUnitResult result =
          await analysisContext.currentSession.getResolvedUnit(parameters.file);
      if (result is ResolvedUnitResult) {
        final DartAnalysisError error = toDartAnalysisError(
          result: result,
          location: protocol_common.Location(result.path, 0, 1, 1, 1),
          astNode: result.unit,
          ignoreInfo: CandiesAnalyzerPluginIgnoreInfo.forDart(result),
          config: null,
        );
        if (error.location.offset <= parameters.offset &&
            parameters.offset <=
                error.location.offset + error.location.length) {
          CandiesAnalyzerPluginLogger().log(
            'unused_file get fix: ${parameters.file}',
            root: analysisContext.root,
          );
          yield await toAnalysisErrorFixes(error: error);
        }
      }
    }
  }
}

class _GatherUsedImportedElementsVisitor extends RecursiveAstVisitor<void> {
  _GatherUsedImportedElementsVisitor(this.library);
  final LibraryElement library;

  final UsedImportedElements usedElements = UsedImportedElements();

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _recordAssignmentTarget(node, node.leftHandSide);
    return super.visitAssignmentExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _recordIfExtensionMember(node.staticElement);
    return super.visitBinaryExpression(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _visitDirective(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _recordIfExtensionMember(node.staticElement);
    return super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    _visitDirective(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    _recordIfExtensionMember(node.staticElement);
    return super.visitIndexExpression(node);
  }

  @override
  void visitLibraryDirective(LibraryDirective node) {
    _visitDirective(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _recordAssignmentTarget(node, node.operand);
    return super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    _recordAssignmentTarget(node, node.operand);
    _recordIfExtensionMember(node.staticElement);
    return super.visitPrefixExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _visitIdentifier(node, node.staticElement);
  }

  void _recordAssignmentTarget(
    CompoundAssignmentExpression node,
    Expression target,
  ) {
    if (target is PrefixedIdentifier) {
      _visitIdentifier(target.identifier, node.readElement);
      _visitIdentifier(target.identifier, node.writeElement);
    } else if (target is PropertyAccess) {
      _visitIdentifier(target.propertyName, node.readElement);
      _visitIdentifier(target.propertyName, node.writeElement);
    } else if (target is SimpleIdentifier) {
      _visitIdentifier(target, node.readElement);
      _visitIdentifier(target, node.writeElement);
    }
  }

  void _recordIfExtensionMember(Element? element) {
    if (element != null) {
      final Element? enclosingElement = element.enclosingElement3;
      if (enclosingElement is ExtensionElement) {
        _recordUsedExtension(enclosingElement);
      }
    }
  }

  /// If the given [identifier] is prefixed with a [PrefixElement], fill the
  /// corresponding `UsedImportedElements.prefixMap` entry and return `true`.
  bool _recordPrefixMap(SimpleIdentifier identifier, Element element) {
    bool recordIfTargetIsPrefixElement(Expression? target) {
      if (target is SimpleIdentifier) {
        final Element? targetElement = target.staticElement;
        if (targetElement is PrefixElement) {
          final List<Element> prefixedElements = usedElements.prefixMap
              .putIfAbsent(targetElement, () => <Element>[]);
          prefixedElements.add(element);
          return true;
        }
      }
      return false;
    }

    final AstNode? parent = identifier.parent;
    if (parent is MethodInvocation && parent.methodName == identifier) {
      return recordIfTargetIsPrefixElement(parent.target);
    }
    if (parent is PrefixedIdentifier && parent.identifier == identifier) {
      return recordIfTargetIsPrefixElement(parent.prefix);
    }
    return false;
  }

  /// Records use of an unprefixed [element].
  void _recordUsedElement(Element element) {
    // Ignore if an unknown library.
    final LibraryElement? containingLibrary = element.library;
    if (containingLibrary == null) {
      return;
    }
    // Ignore if a local element.
    if (library == containingLibrary) {
      return;
    }

    // Remember the element.
    usedElements.elements.add(element);
  }

  void _recordUsedExtension(ExtensionElement extension) {
    // Ignore if a local element.
    if (library == extension.library) {
      return;
    }

    // Remember the element.
    usedElements.usedExtensions.add(extension);
  }

  /// Visit identifiers used by the given [directive].
  void _visitDirective(Directive directive) {
    directive.documentationComment?.accept(this);
    directive.metadata.accept(this);
  }

  void _visitIdentifier(SimpleIdentifier identifier, Element? element) {
    if (element == null) {
      return;
    }
    // Ignore if it is in sdk.
    // zmtzawqlp
    if (element.library != null &&
        (element.library!.isInSdk || element.library!.isInFlutterSdk)) {
      return;
    }

    // Record `importPrefix.identifier` into 'prefixMap'.
    if (_recordPrefixMap(identifier, element)) {
      return;
    }
    final Element? enclosingElement = element.enclosingElement3;
    if (enclosingElement is CompilationUnitElement) {
      _recordUsedElement(element);
    } else if (enclosingElement is ExtensionElement) {
      _recordUsedExtension(enclosingElement);
      return;
    } else if (element is PrefixElement) {
      usedElements.prefixMap.putIfAbsent(element, () => <Element>[]);
    } else if (element is MultiplyDefinedElement) {
      // If the element is multiply defined then call this method recursively
      // for each of the conflicting elements.
      final List<Element> conflictingElements = element.conflictingElements;
      final int length = conflictingElements.length;
      for (int i = 0; i < length; i++) {
        final Element elt = conflictingElements[i];
        _visitIdentifier(identifier, elt);
      }
    }
    //  else {
    //   // zmtzawqlp
    //   _recordUsedElement(element);
    // }
  }

  /// zmtzawqlp
  bool _containsEntrypoint = false;
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (_isEntrypoint(node.name2.lexeme, node.metadata)) {
      _containsEntrypoint = true;
    }
    super.visitFunctionDeclaration(node);
  }

  /// https://github.com/dart-lang/sdk/blob/master/pkg/vm/lib/transformations/pragma.dart
  ///
  ///
  bool _isEntrypoint(String name, NodeList<Annotation> metadata) =>
      name == 'main' ||
      _isPragmaVmEntryPoint(metadata) ||
      _flutterInternalEntryFunctions.contains(name);

  final List<String> _flutterInternalEntryFunctions = const <String>[
    'registerPlugins',
    'testExecutable'
  ];

  /// https://github.com/dart-lang/sdk/blob/master/pkg/analyzer/lib/src/dart/element/element.dart
  ///
  bool _isPragmaVmEntryPoint(Iterable<Annotation> metadata) {
    for (final Annotation annotation in metadata) {
      if (annotation is ElementAnnotationImpl &&
          (annotation as ElementAnnotationImpl).isPragmaVmEntryPoint) {
        return true;
      }
    }
    return false;
  }
}

/// copy from https://github.com/dart-lang/sdk/blob/master/pkg/analyzer/lib/src/error/imports_verifier.dart
class _ImportsVerifier {
  /// All [ImportDirective]s of the current library.
  final List<ImportDirective> _allImports = <ImportDirective>[];

  /// A list of [ImportDirective]s that the current library imports, but does
  /// not use.
  ///
  /// As identifiers are visited by this visitor and an import has been
  /// identified as being used by the library, the [ImportDirective] is removed
  /// from this list. After all the sources in the library have been evaluated,
  /// this list represents the set of unused imports.
  ///
  /// See [ImportsVerifier.generateUnusedImportErrors].
  final List<ImportDirective> _unusedImports = <ImportDirective>[];

  /// This is a map between prefix elements and the import directives from which
  /// they are derived. In cases where a type is referenced via a prefix
  /// element, the import directive can be marked as used (removed from the
  /// unusedImports) by looking at the resolved `lib` in `lib.X`, instead of
  /// looking at which library the `lib.X` resolves.
  final HashMap<PrefixElement, List<ImportDirective>> _prefixElementMap =
      HashMap<PrefixElement, List<ImportDirective>>();

  /// A map of identifiers that the current library's imports show, but that the
  /// library does not use.
  ///
  /// Each import directive maps to a list of the identifiers that are imported
  /// via the "show" keyword.
  ///
  /// As each identifier is visited by this visitor, it is identified as being
  /// used by the library, and the identifier is removed from this map (under
  /// the import that imported it). After all the sources in the library have
  /// been evaluated, each list in this map's values present the set of unused
  /// shown elements.
  ///
  /// See [ImportsVerifier.generateUnusedShownNameHints].
  final HashMap<ImportDirective, List<SimpleIdentifier>> _unusedShownNamesMap =
      HashMap<ImportDirective, List<SimpleIdentifier>>();

  /// The cache of [Namespace]s for [ImportDirective]s.
  final HashMap<ImportDirective, Namespace> _namespaceMap =
      HashMap<ImportDirective, Namespace>();

  void addImports(CompilationUnit node) {
    final List<_ImportDirective> importsWithLibraries = <_ImportDirective>[];
    for (final Directive directive in node.directives) {
      if (directive is ImportDirective) {
        final LibraryElement? libraryElement =
            directive.element2?.importedLibrary;
        if (libraryElement == null) {
          continue;
        }
        _allImports.add(directive);
        _unusedImports.add(directive);
        importsWithLibraries.add(
          _ImportDirective(
            node: directive,
            importedLibrary: libraryElement,
          ),
        );
        //
        // Initialize prefixElementMap
        //
        if (directive.asKeyword != null) {
          final SimpleIdentifier? prefixIdentifier = directive.prefix;
          if (prefixIdentifier != null) {
            final Element? element = prefixIdentifier.staticElement;
            if (element is PrefixElement) {
              List<ImportDirective>? list = _prefixElementMap[element];
              if (list == null) {
                list = <ImportDirective>[];
                _prefixElementMap[element] = list;
              }
              list.add(directive);
            }
            // TODO1 (jwren) Can the element ever not be a PrefixElement?
          }
        }
        _addShownNames(directive);
      }
      // if (directive is NamespaceDirective) {
      //   _addDuplicateShownHiddenNames(directive);
      // }
    }
    // if (importsWithLibraries.length > 1) {
    //   // order the list of unusedImports to find duplicates in faster than
    //   // O(n^2) time
    //   importsWithLibraries
    //       .sort((_ImportDirective import1, _ImportDirective import2) {
    //     return import1.libraryUriStr.compareTo(import2.libraryUriStr);
    //   });
    //   _ImportDirective currentDirective = importsWithLibraries[0];
    //   for (int i = 1; i < importsWithLibraries.length; i++) {
    //     final _ImportDirective nextDirective = importsWithLibraries[i];
    //     if (currentDirective.libraryUriStr == nextDirective.libraryUriStr &&
    //         ImportDirectiveImpl.areSyntacticallyIdenticalExceptUri(
    //           currentDirective.node,
    //           nextDirective.node,
    //         )) {
    //       // Add either the currentDirective or nextDirective depending on which
    //       // comes second, this guarantees that the first of the duplicates
    //       // won't be highlighted.
    //       if (currentDirective.node.offset < nextDirective.node.offset) {
    //         _duplicateImports.add(nextDirective.node);
    //       } else {
    //         _duplicateImports.add(currentDirective.node);
    //       }
    //     }
    //     currentDirective = nextDirective;
    //   }
    // }
  }

  /// Add every shown name from [importDirective] into [_unusedShownNamesMap].
  void _addShownNames(ImportDirective importDirective) {
    final List<SimpleIdentifier> identifiers = <SimpleIdentifier>[];
    _unusedShownNamesMap[importDirective] = identifiers;
    for (final Combinator combinator in importDirective.combinators) {
      if (combinator is ShowCombinator) {
        for (final SimpleIdentifier name in combinator.shownNames) {
          if (name.staticElement != null) {
            identifiers.add(name);
          }
        }
      }
    }
  }

  /// Remove elements from [_unusedImports] using the given [usedElements].
  void removeUsedElements(UsedImportedElements usedElements) {
    bool everythingIsKnownToBeUsed() =>
        _unusedImports.isEmpty && _unusedShownNamesMap.isEmpty;

    // Process import prefixes.
    for (final MapEntry<PrefixElement, List<Element>> entry
        in usedElements.prefixMap.entries) {
      if (everythingIsKnownToBeUsed()) {
        return;
      }
      final PrefixElement prefix = entry.key;
      final List<ImportDirective>? importDirectives = _prefixElementMap[prefix];
      if (importDirectives == null) {
        continue;
      }
      final List<Element> elements = entry.value;
      // Find import directives using namespaces.
      for (final ImportDirective importDirective in importDirectives) {
        if (elements.isEmpty) {
          // [prefix] and [elements] were added to [usedElements.prefixMap] but
          // [elements] is empty, so the prefix was referenced incorrectly.
          // Another diagnostic about the prefix reference is reported, and we
          // shouldn't confuse by also reporting an unused prefix.
          _unusedImports.remove(importDirective);
        }
        final Namespace? namespace =
            _namespaceMap.computeNamespace(importDirective);
        if (namespace == null) {
          continue;
        }
        for (final Element element in elements) {
          if (namespace.providesPrefixed(prefix.name, element)) {
            _unusedImports.remove(importDirective);
            _removeFromUnusedShownNamesMap(element, importDirective);
          }
        }
      }
    }

    // Process top-level elements.
    for (final Element element in usedElements.elements) {
      if (everythingIsKnownToBeUsed()) {
        return;
      }
      // Find import directives using namespaces.
      for (final ImportDirective importDirective in _allImports) {
        final Namespace? namespace =
            _namespaceMap.computeNamespace(importDirective);
        if (namespace == null) {
          continue;
        }
        if (namespace.provides(element)) {
          _unusedImports.remove(importDirective);
          _removeFromUnusedShownNamesMap(element, importDirective);
        }
      }
    }
    // Process extension elements.
    for (final ExtensionElement extensionElement
        in usedElements.usedExtensions) {
      if (everythingIsKnownToBeUsed()) {
        return;
      }
      final String elementName = extensionElement.name!;
      // Find import directives using namespaces.
      for (final ImportDirective importDirective in _allImports) {
        final Namespace? namespace =
            _namespaceMap.computeNamespace(importDirective);
        if (namespace == null) {
          continue;
        }
        final String? prefix = importDirective.prefix?.name;
        if (prefix == null) {
          if (namespace.get(elementName) == extensionElement) {
            _unusedImports.remove(importDirective);
            _removeFromUnusedShownNamesMap(extensionElement, importDirective);
          }
        } else {
          // An extension might be used solely because one or more instance
          // members are referenced, which does not require explicit use of the
          // prefix. We still indicate that the import directive is used.
          if (namespace.getPrefixed(prefix, elementName) == extensionElement) {
            _unusedImports.remove(importDirective);
            _removeFromUnusedShownNamesMap(extensionElement, importDirective);
          }
        }
      }
    }
  }

  /// Remove [element] from the list of names shown by [importDirective].
  void _removeFromUnusedShownNamesMap(
      Element element, ImportDirective importDirective) {
    final List<SimpleIdentifier>? identifiers =
        _unusedShownNamesMap[importDirective];
    if (identifiers == null) {
      return;
    }

    /// When an element is used, it might be converted into a `Member`,
    /// to apply substitution, or turn it into legacy. But using something
    /// is purely declaration based.
    bool hasElement(SimpleIdentifier identifier, Element element) {
      return identifier.staticElement?.declaration == element.declaration;
    }

    final int length = identifiers.length;
    for (int i = 0; i < length; i++) {
      final SimpleIdentifier identifier = identifiers[i];
      if (element is PropertyAccessorElement) {
        // If the getter or setter of a variable is used, then the variable (the
        // shown name) is used.
        if (hasElement(identifier, element.variable)) {
          identifiers.remove(identifier);
          break;
        }
      } else {
        if (hasElement(identifier, element)) {
          identifiers.remove(identifier);
          break;
        }
      }
    }
    if (identifiers.isEmpty) {
      _unusedShownNamesMap.remove(importDirective);
    }
  }
}

/// [ImportDirective] with non-null imported [LibraryElement].
class _ImportDirective {
  _ImportDirective({
    required this.node,
    required this.importedLibrary,
  });
  final ImportDirective node;
  final LibraryElement importedLibrary;

  /// Returns the absolute URI of the imported library.
  String get libraryUriStr => '${importedLibrary.source.uri}';
}

extension on Map<ImportDirective, Namespace> {
  /// Lookup and return the [Namespace] in this Map.
  ///
  /// If this map does not have the computed namespace, compute it and cache it
  /// in this map. If [importDirective] is not resolved or is not resolvable,
  /// `null` is returned.
  Namespace? computeNamespace(ImportDirective importDirective) {
    Namespace? namespace = this[importDirective];
    if (namespace == null) {
      final LibraryImportElement? importElement = importDirective.element2;
      if (importElement != null) {
        namespace = importElement.namespace;
        this[importDirective] = namespace;
      }
    }
    return namespace;
  }
}

extension on Namespace {
  /// Returns whether this provides [element], taking into account system
  /// library shadowing.
  bool provides(Element element) {
    final Element? elementFromNamespace = get(element.name!);
    return elementFromNamespace != null &&
        !_isShadowing(element, elementFromNamespace);
  }

  /// Returns whether this provides [element] with [prefix], taking into account
  /// system library shadowing.
  bool providesPrefixed(String prefix, Element element) {
    final Element? elementFromNamespace = getPrefixed(prefix, element.name!);
    return elementFromNamespace != null &&
        !_isShadowing(element, elementFromNamespace);
  }

  /// Returns whether [e1] shadows [e2], assuming each is an imported element,
  /// and that each is imported with the same prefix.
  ///
  /// Returns false if the source of either element is `null`.
  bool _isShadowing(Element e1, Element e2) {
    final Source? source1 = e1.source;
    if (source1 == null) {
      return false;
    }
    final Source? source2 = e2.source;
    if (source2 == null) {
      return false;
    }
    return !source1.uri.isScheme('dart') && source2.uri.isScheme('dart');
  }
}

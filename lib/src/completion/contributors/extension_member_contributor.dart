// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:analyzer_plugin/src/utilities/completion/completion_target.dart';
import 'package:analyzer_plugin/src/utilities/completion/suggestion_builder.dart';
import 'package:analyzer_plugin/src/utilities/visitors/local_declaration_visitor.dart';
import 'package:analyzer_plugin/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/utilities/completion/relevance.dart';
import 'package:candies_analyzer_plugin/src/completion/display_string_builder.dart'
    as candies_analyzer_plugin;
import 'package:candies_analyzer_plugin/src/extension.dart';
import 'package:candies_analyzer_plugin/src/log.dart';
import 'package:analyzer/src/dart/resolver/applicable_extensions.dart';
import 'package:analyzer_plugin/src/utilities/completion/optype.dart';
import 'package:path/path.dart' as path_package;

/// A completion contributor that will generate suggestions for instance
/// invocations and accesses.
///
///
/// _computeSuggestions from https://github.com/dart-lang/sdk/blob/master/pkg/analyzer_plugin/lib/utilities/completion/type_member_contributor.dart
///
///
/// _computeSuggestions1 form https://github.com/dart-lang/sdk/blob/master/pkg/analysis_server/lib/src/services/completion/dart/extension_member_contributor.dart
///
class ExtensionMemberContributor implements CompletionContributor {
  /// Plugin contributors should primarily overload this function.
  /// Should more parameters be needed for autocompletion needs, the
  /// overloaded function should define those parameters and
  /// call on `computeSuggestionsWithEntryPoint`.
  ///

  Set<ExtensionElement> accessibleExtensions = <ExtensionElement>{};

  @override
  Future<void> computeSuggestions(
    DartCompletionRequest request,
    CompletionCollector collector,
  ) async {
    _computeSuggestions(request, collector);
  }

  /// Update the completion [target] and [dotTarget] based on the given [unit].
  Expression? _computeDotTarget(AstNode entryPoint, int offset) {
    final CompletionTarget target =
        CompletionTarget.forOffset(entryPoint, offset);
    return target.dotTarget;
  }

  /// https://github.com/dart-lang/sdk/blob/master/pkg/analyzer_plugin/lib/utilities/completion/type_member_contributor.dart
  ///
  void _computeSuggestions(
    DartCompletionRequest request,
    CompletionCollector collector,
  ) {
    final LibraryElement containingLibrary = request.result.libraryElement;

    // Recompute the target since resolution may have changed it
    final Expression? expression =
        _computeDotTarget(request.result.unit, request.offset);
    if (expression == null || expression.isSynthetic) {
      return;
    }
    CandiesAnalyzerPluginLogger().log(
      'ExtensionMemberContributor: try to find extension in \n${accessibleExtensions.map((ExtensionElement e) => e.source.fullName + '(${e.displayName}}').join('\n')}\n---',
      root: request.result.root,
    );

    if (expression is Identifier) {
      final Element? element = expression.staticElement;
      if (element is ClassElement) {
        // Suggestions provided by StaticMemberContributor
        return;
      }
      if (element is PrefixElement) {
        // Suggestions provided by LibraryMemberContributor
        return;
      }
    }

    // Determine the target expression's type
    DartType? type = expression.staticType;
    if (type == null || type.isDynamic) {
      // If the expression does not provide a good type
      // then attempt to get a better type from the element
      if (expression is Identifier) {
        final Element? elem = expression.staticElement;
        if (elem is FunctionTypedElement) {
          type = elem.returnType;
        } else if (elem is ParameterElement) {
          type = elem.type;
        } else if (elem is LocalVariableElement) {
          type = elem.type;
        }
        if ((type == null || type.isDynamic) &&
            expression is SimpleIdentifier) {
          // If the element does not provide a good type
          // then attempt to get a better type from a local declaration
          final _LocalBestTypeVisitor visitor =
              _LocalBestTypeVisitor(expression.name, request.offset);
          if (visitor.visit(expression) && visitor.typeFound != null) {
            type = visitor.typeFound;
          }
        }
      }
    }
    String? containingMethodName;
    if (expression is SuperExpression && type is InterfaceType) {
      // Suggest members from superclass if target is "super"
      type = type.superclass;
      // Determine the name of the containing method because
      // the most likely completion is a super expression with same name
      final MethodDeclaration? containingMethod =
          expression.thisOrAncestorOfType<MethodDeclaration>();
      final Token? id = containingMethod?.name2;
      if (id != null) {
        containingMethodName = id.lexeme;
      }
    }
    if (type == null || type.isDynamic) {
      // Suggest members from object if target is "dynamic"
      type = request.result.typeProvider.objectType;
      return;
    }

    // type_member_contributor code
    // Build the suggestions
    // if (type is InterfaceType) {
    //   var builder = _SuggestionBuilder(
    //       request.resourceProvider, collector, containingLibrary);
    //   builder.buildSuggestions(type, containingMethodName);
    // }

    // zmtzawqlp
    // find applicable extensions
    final List<InstantiatedExtensionWithoutMember> applicableExtensions =
        accessibleExtensions.toList().applicableTo(
              targetLibrary: request.result.libraryElement,
              targetType: type,
            );

    for (final InstantiatedExtensionWithoutMember applicableExtension
        in applicableExtensions) {
      final ExtensionElement accessibleExtension =
          applicableExtension.extension;
      final String filePath = accessibleExtension.source.fullName;
      // the same file
      if (request.result.path == filePath) {
        continue;
      }

      bool _skip = false;
      // skip ,may be in same file , import already , hide
      for (final LibraryElement importedLibrary
          in request.result.libraryElement.importedLibraries) {
        if (importedLibrary.source.fullName == filePath) {
          _skip = true;
          break;
        }

        if (_skipLibrary(
          importedLibrary,
          accessibleExtension,
          request.result.root,
          0,
        )) {
          _skip = true;
          break;
        }
      }
      if (_skip) {
        continue;
      }

      final _SuggestionBuilder builder = _SuggestionBuilder(
          request.resourceProvider, collector, containingLibrary);
      CandiesAnalyzerPluginLogger().log(
        'ExtensionMemberContributor: find extension  $type , accessibleExtension ${accessibleExtension.displayName} at $filePath',
        root: request.result.root,
      );

      builder.buildSuggestions(
        accessibleExtension,
        containingMethodName,
        accessibleExtension,
      );
    }
  }

  bool _skipLibrary(
    LibraryElement library,
    ExtensionElement accessibleExtension,
    String root,
    int depth,
  ) {
    final String path = accessibleExtension.source.fullName;
    for (final PartElement partElement in library.parts2) {
      if (partElement.uri is DirectiveUriWithUnit) {
        final DirectiveUriWithUnit uri =
            partElement.uri as DirectiveUriWithUnit;
        if (uri.source.fullName == path) {
          return true;
        }
      }
    }
    final String dirname = path_package.dirname(library.source.fullName);
    for (final LibraryExportElement libraryExport in library.libraryExports) {
      final LibraryElement? exportedLibrary = libraryExport.exportedLibrary;
      if (exportedLibrary == null) {
        continue;
      }

      // dart will not ddd

      if (depth == 0) {
        // analysis_server not check other library to export

        // package dartx export package time

        // import 'package:dartx/dartx.dart';
        // int i =1;
        // i.weeks
        // analysis_server not show 'weeks'
        // so we need show completion
        if (!exportedLibrary.source.fullName.startsWith(dirname)) {
          CandiesAnalyzerPluginLogger().log(
            'ExtensionMemberContributor: skip library export ${exportedLibrary.source.fullName}  for ${library.source.fullName} ',
            root: root,
          );
          continue;
        }
      }

      bool hide = false;
      bool show = true;
      for (final NamespaceCombinator combinator in libraryExport.combinators) {
        if (combinator is HideElementCombinator) {
          hide =
              combinator.hiddenNames.contains(accessibleExtension.displayName);
        } else if (combinator is ShowElementCombinator) {
          show =
              combinator.shownNames.contains(accessibleExtension.displayName);
        }
      }

      if (exportedLibrary.source.fullName == path && !hide && show) {
        return true;
      }

      // take too much time
      if (depth < 100 &&
          _skipLibrary(exportedLibrary, accessibleExtension, root, depth + 1)) {
        return true;
      }
    }

    return false;
  }

  /// zmtzawqlp
  /// https://github.com/dart-lang/sdk/blob/master/pkg/analysis_server/lib/src/services/completion/dart/extension_member_contributor.dart
  // ignore: unused_element
  void _computeSuggestions1(
    DartCompletionRequest request,
    CompletionCollector collector,
  ) {
    final LibraryElement containingLibrary = request.result.libraryElement;
    final CompletionTarget target =
        CompletionTarget.forOffset(request.result.unit, request.offset);
    final OpType opType = OpType.forCompletion(target, request.offset);
    final CompletionSuggestionKind defaultKind = target.isFunctionalArgument()
        ? CompletionSuggestionKind.IDENTIFIER
        : opType.suggestKind;
    // Recompute the target since resolution may have changed it
    final Expression? expression = target.dotTarget;
    final List<ExtensionElement> extensions = accessibleExtensions.toList();
    if (expression == null) {
      if (!opType.includeIdentifiers) {
        return;
      }

      final InterfaceType? thisClassType =
          target.enclosingClassElement?.thisType;
      if (thisClassType != null) {
        _addExtensionMembers(extensions, defaultKind, thisClassType, request);
      } else {
        final DartType? thisExtendedType =
            target.enclosingExtensionElement?.extendedType;
        if (thisExtendedType is InterfaceType) {
          final List<InterfaceType> types = <InterfaceType>[
            thisExtendedType,
            ...thisExtendedType.allSupertypes
          ];
          for (final InterfaceType type in types) {
            // var inheritanceDistance = memberBuilder.request.featureComputer
            //     .inheritanceDistanceFeature(
            //         thisExtendedType.element, type.element);
            const double inheritanceDistance = 1.0;
            _addTypeMembers(type, defaultKind, inheritanceDistance);
          }
          _addExtensionMembers(
              extensions, defaultKind, thisExtendedType, request);
        }
      }
      return;
    }

    if (expression.isSynthetic) {
      return;
    }

    if (expression is Identifier) {
      final Element? elem = expression.staticElement;
      if (elem is InterfaceElement) {
        // Suggestions provided by StaticMemberContributor.
        return;
      } else if (elem is ExtensionElement) {
        // Suggestions provided by StaticMemberContributor.
        return;
      } else if (elem is PrefixElement) {
        // Suggestions provided by LibraryMemberContributor.
        return;
      }
    }
    if (expression is ExtensionOverride) {
      final ExtensionElement? staticElement = expression.staticElement;
      if (staticElement != null) {
        _addInstanceMembers(staticElement, defaultKind, 0.0);
      }
    } else {
      DartType? type = expression.staticType;
      if (type == null) {
        // Without a type we can't find the extensions that apply. We shouldn't
        // get to this point, but there's an NPE if we invoke
        // `resolvedExtendedType` when `type` is `null`, so we guard against it
        // to ensure that we can return the suggestions from other providers.
        return;
      }
      final AstNode containingNode = target.containingNode;
      if (containingNode is PropertyAccess &&
          containingNode.operator.lexeme == '?.') {
        // After a null-safe operator we know that the member will only be
        // invoked on a non-null value.
        type = containingLibrary.typeSystem.promoteToNonNull(type);
      }
      _addExtensionMembers(extensions, defaultKind, type, request);
    }
  }

  void _addTypeMembers(InterfaceType type, CompletionSuggestionKind kind,
      double inheritanceDistance) {
    // ignore: unused_local_variable
    for (final MethodElement method in type.methods) {
      // memberBuilder.addSuggestionForMethod(
      //     method: method, kind: kind, inheritanceDistance: inheritanceDistance);
    }
    // ignore: unused_local_variable
    for (final PropertyAccessorElement accessor in type.accessors) {
      // memberBuilder.addSuggestionForAccessor(
      //     accessor: accessor, inheritanceDistance: inheritanceDistance);
    }
  }

  void _addInstanceMembers(ExtensionElement extension,
      CompletionSuggestionKind kind, double inheritanceDistance) {
    for (final MethodElement method in extension.methods) {
      if (!method.isStatic) {
        // memberBuilder.addSuggestionForMethod(
        //     method: method,
        //     kind: kind,
        //     inheritanceDistance: inheritanceDistance);
      }
    }
    for (final PropertyAccessorElement accessor in extension.accessors) {
      if (!accessor.isStatic) {
        // memberBuilder.addSuggestionForAccessor(
        //     accessor: accessor, inheritanceDistance: inheritanceDistance);
      }
    }
  }

  void _addExtensionMembers(
    List<ExtensionElement> extensions,
    CompletionSuggestionKind kind,
    DartType type,
    DartCompletionRequest request,
  ) {
    final List<InstantiatedExtensionWithoutMember> applicableExtensions =
        extensions.applicableTo(
      targetLibrary: request.result.libraryElement,
      targetType: type,
    );
    for (final InstantiatedExtensionWithoutMember instantiatedExtension
        in applicableExtensions) {
      final DartType extendedType = instantiatedExtension.extendedType;
      CandiesAnalyzerPluginLogger().log(
        'ExtensionMemberContributor:  $type --- ${instantiatedExtension.extension.source.fullName}',
        root: request.result.root,
      );
      const double inheritanceDistance = 0.0;
      if (type is InterfaceType && extendedType is InterfaceType) {
        // inheritanceDistance = memberBuilder.request.featureComputer
        //     .inheritanceDistanceFeature(type.element2, extendedType.element2);
      }
      _addInstanceMembers(
          instantiatedExtension.extension, kind, inheritanceDistance);
    }
  }
}

/// An [AstVisitor] which looks for a declaration with the given name
/// and if found, tries to determine a type for that declaration.
class _LocalBestTypeVisitor extends LocalDeclarationVisitor {
  /// Construct a new instance to search for a declaration
  _LocalBestTypeVisitor(this.targetName, int offset) : super(offset);

  /// The name for the declaration to be found.
  final String targetName;

  /// The best type for the found declaration,
  /// or `null` if no declaration found or failed to determine a type.
  DartType? typeFound;

  @override
  void declaredClass(ClassDeclaration declaration) {
    if (declaration.name2.lexeme == targetName) {
      // no type
      finished();
    }
  }

  @override
  void declaredClassTypeAlias(ClassTypeAlias declaration) {
    if (declaration.name2.lexeme == targetName) {
      // no type
      finished();
    }
  }

  @override
  void declaredExtension(ExtensionDeclaration declaration) {}

  @override
  void declaredField(FieldDeclaration fieldDecl, VariableDeclaration varDecl) {
    if (varDecl.name2.lexeme == targetName) {
      // Type provided by the element in computeFull above
      finished();
    }
  }

  @override
  void declaredFunction(FunctionDeclaration declaration) {
    if (declaration.name2.lexeme == targetName) {
      final TypeAnnotation? typeName = declaration.returnType;
      if (typeName != null) {
        typeFound = typeName.type;
      }
      finished();
    }
  }

  @override
  void declaredFunctionTypeAlias(FunctionTypeAlias declaration) {
    if (declaration.name2.lexeme == targetName) {
      final TypeAnnotation? typeName = declaration.returnType;
      if (typeName != null) {
        typeFound = typeName.type;
      }
      finished();
    }
  }

  @override
  void declaredGenericTypeAlias(GenericTypeAlias declaration) {
    if (declaration.name2.lexeme == targetName) {
      final TypeAnnotation? typeName = declaration.functionType?.returnType;
      if (typeName != null) {
        typeFound = typeName.type;
      }
      finished();
    }
  }

  @override
  void declaredLabel(Label label, bool isCaseLabel) {
    if (label.label.name == targetName) {
      // no type
      finished();
    }
  }

  @override
  void declaredLocalVar(SimpleIdentifier name, TypeAnnotation? type) {
    if (name.name == targetName) {
      final VariableElement element = name.staticElement as VariableElement;
      typeFound = element.type;
      finished();
    }
  }

  @override
  void declaredMethod(MethodDeclaration declaration) {
    if (declaration.name2.lexeme == targetName) {
      final TypeAnnotation? typeName = declaration.returnType;
      if (typeName != null) {
        typeFound = typeName.type;
      }
      finished();
    }
  }

  @override
  void declaredParam(SimpleIdentifier name, TypeAnnotation? type) {
    if (name.name == targetName) {
      // Type provided by the element in computeFull above
      finished();
    }
  }

  @override
  void declaredTopLevelVar(
      VariableDeclarationList varList, VariableDeclaration varDecl) {
    if (varDecl.name2.lexeme == targetName) {
      // Type provided by the element in computeFull above
      finished();
    }
  }
}

/// This class provides suggestions based upon the visible instance members in
/// an interface type.
class _SuggestionBuilder {
  _SuggestionBuilder(
      this.resourceProvider, this.collector, this.containingLibrary)
      : builder = SuggestionBuilderImpl(resourceProvider);

  /// Enumerated value indicating that we have not generated any completions for
  /// a given identifier yet.
  static const int _COMPLETION_TYPE_NONE = 0;

  /// Enumerated value indicating that we have generated a completion for a
  /// getter.
  static const int _COMPLETION_TYPE_GETTER = 1;

  /// Enumerated value indicating that we have generated a completion for a
  /// setter.
  static const int _COMPLETION_TYPE_SETTER = 2;

  /// Enumerated value indicating that we have generated a completion for a
  /// field, a method, or a getter/setter pair.
  static const int _COMPLETION_TYPE_FIELD_OR_METHOD_OR_GETSET = 3;

  /// The resource provider used to access the file system.
  final ResourceProvider resourceProvider;

  /// The collector being used to collect completion suggestions.
  final CompletionCollector collector;

  /// The library containing the unit in which the completion is requested.
  final LibraryElement containingLibrary;

  /// Map indicating, for each possible completion identifier, whether we have
  /// already generated completions for a getter, setter, or both. The "both"
  /// case also handles the case where have generated a completion for a method
  /// or a field.
  ///
  /// Note: the enumerated values stored in this map are intended to be bitwise
  /// compared.
  final Map<String, int> _completionTypesGenerated = HashMap<String, int>();

  /// Map from completion identifier to completion suggestion
  // final Map<String, CompletionSuggestion> _suggestionMap =
  //     <String, CompletionSuggestion>{};

  /// The builder used to build suggestions.
  final SuggestionBuilderImpl builder;

  //Iterable<CompletionSuggestion> get suggestions => _suggestionMap.values;

  // /// Create completion suggestions for 'dot' completions on the given [type].
  // /// If the 'dot' completion is a super expression, then [containingMethodName]
  // /// is the name of the method in which the completion is requested.
  // void buildSuggestions(InterfaceType type, String? containingMethodName) {
  //   // Visit all of the types in the class hierarchy, collecting possible
  //   // completions. If multiple elements are found that complete to the same
  //   // identifier, addSuggestion will discard all but the first (with a few
  //   // exceptions to handle getter/setter pairs).
  //   var types = _getTypeOrdering(type);
  //   for (var targetType in types) {
  //     for (var method in targetType.methods) {
  //       // Exclude static methods when completion on an instance
  //       if (!method.isStatic) {
  //         // Boost the relevance of a super expression
  //         // calling a method of the same name as the containing method
  //         _addSuggestion(method,
  //             relevance: method.name == containingMethodName
  //                 ? DART_RELEVANCE_HIGH
  //                 : null);
  //       }
  //     }
  //     for (var propertyAccessor in targetType.accessors) {
  //       if (!propertyAccessor.isStatic) {
  //         if (propertyAccessor.isSynthetic) {
  //           // Avoid visiting a field twice
  //           if (propertyAccessor.isGetter) {
  //             _addSuggestion(propertyAccessor.variable);
  //           }
  //         } else {
  //           _addSuggestion(propertyAccessor);
  //         }
  //       }
  //     }
  //   }
  //   for (var suggestion in suggestions) {
  //     collector.addSuggestion(suggestion);
  //   }
  // }

  /// Create completion suggestions for 'dot' completions on the given [type].
  /// If the 'dot' completion is a super expression, then [containingMethodName]
  /// is the name of the method in which the completion is requested.
  void buildSuggestions(
    ExtensionElement extensionElement,
    String? containingMethodName,
    ExtensionElement accessibleExtension,
  ) {
    // Visit all of the types in the class hierarchy, collecting possible
    // completions. If multiple elements are found that complete to the same
    // identifier, addSuggestion will discard all but the first (with a few
    // exceptions to handle getter/setter pairs).
    final ExtensionElement targetType = extensionElement;

    for (final MethodElement method in targetType.methods) {
      // Exclude static methods when completion on an instance
      if (!method.isStatic) {
        // Boost the relevance of a super expression
        // calling a method of the same name as the containing method
        _addSuggestion(
          method,
          accessibleExtension,
          relevance:
              method.name == containingMethodName ? DART_RELEVANCE_HIGH : null,
        );
      }
    }
    for (final PropertyAccessorElement propertyAccessor
        in targetType.accessors) {
      if (!propertyAccessor.isStatic) {
        if (propertyAccessor.isSynthetic) {
          // Avoid visiting a field twice
          if (propertyAccessor.isGetter) {
            _addSuggestion(
              propertyAccessor.variable,
              accessibleExtension,
            );
          }
        } else {
          _addSuggestion(
            propertyAccessor,
            accessibleExtension,
          );
        }
      }
    }

    // for (CompletionSuggestion suggestion in suggestions) {
    //   collector.addSuggestion(suggestion);
    // }
  }

  /// Add a suggestion based upon the given element, provided that it is not
  /// shadowed by a previously added suggestion.
  void _addSuggestion(Element element, ExtensionElement accessibleExtension,
      {int? relevance}) {
    if (element.isPrivate) {
      if (element.library != containingLibrary) {
        // Do not suggest private members for imported libraries
        return;
      }
    }
    final String identifier = element.displayName;

    if (relevance == null) {
      // Decrease relevance of suggestions starting with $
      // https://github.com/dart-lang/sdk/issues/27303
      if (identifier.startsWith(r'$')) {
        relevance = DART_RELEVANCE_LOW;
      } else {
        relevance = DART_RELEVANCE_DEFAULT;
      }
    }

    final int alreadyGenerated = _completionTypesGenerated.putIfAbsent(
        identifier, () => _COMPLETION_TYPE_NONE);
    if (element is MethodElement) {
      // Anything shadows a method.
      if (alreadyGenerated != _COMPLETION_TYPE_NONE) {
        return;
      }
      _completionTypesGenerated[identifier] =
          _COMPLETION_TYPE_FIELD_OR_METHOD_OR_GETSET;
    } else if (element is PropertyAccessorElement) {
      if (element.isGetter) {
        // Getters, fields, and methods shadow a getter.
        if ((alreadyGenerated & _COMPLETION_TYPE_GETTER) != 0) {
          return;
        }
        _completionTypesGenerated[identifier] =
            _completionTypesGenerated[identifier]! | _COMPLETION_TYPE_GETTER;
      } else {
        // Setters, fields, and methods shadow a setter.
        if ((alreadyGenerated & _COMPLETION_TYPE_SETTER) != 0) {
          return;
        }
        _completionTypesGenerated[identifier] =
            _completionTypesGenerated[identifier]! | _COMPLETION_TYPE_SETTER;
      }
    } else if (element is FieldElement) {
      // Fields and methods shadow a field. A getter/setter pair shadows a
      // field, but a getter or setter by itself doesn't.
      if (alreadyGenerated == _COMPLETION_TYPE_FIELD_OR_METHOD_OR_GETSET) {
        return;
      }
      _completionTypesGenerated[identifier] =
          _COMPLETION_TYPE_FIELD_OR_METHOD_OR_GETSET;
    } else {
      // Unexpected element type; skip it.
      assert(false);
      return;
    }

    final CompletionSuggestion? suggestion =
        // https://github.com/dart-lang/sdk/blob/master/pkg/analyzer_plugin/lib/utilities/completion/type_member_contributor.dart
        // relevance is for type_member_contributor
        // extension member should has lower relevance
        builder.forElement(element, relevance: relevance ~/ 2);
    if (suggestion != null) {
      suggestion.libraryUri = accessibleExtension.source.uri.toString();
      for (final PartElement partElement
          in accessibleExtension.library.parts2) {
        if (partElement.uri is DirectiveUriWithUnit) {
          final DirectiveUriWithUnit uri =
              partElement.uri as DirectiveUriWithUnit;
          // it is part file
          if (uri.source.fullName == accessibleExtension.source.fullName) {
            suggestion.libraryUri =
                accessibleExtension.librarySource.uri.toString();
            break;
          }
        }
      }
      suggestion.isNotImported = true;
      // final String libraryInfo =
      //     ' \'${suggestion.libraryUri}\'(${accessibleExtension.displayName})';
      final String libraryInfo = ' (${suggestion.libraryUri})';
      String formalParameters = '';
      if (element is ExecutableElement && element is! PropertyAccessorElement) {
        final candies_analyzer_plugin.ElementDisplayStringBuilder
            elementDisplayStringBuilder =
            candies_analyzer_plugin.ElementDisplayStringBuilder(
                skipAllDynamicArguments: true, withNullability: true);

        elementDisplayStringBuilder.writeFormalParameters(
          element.parameters,
          forElement: true,
        );
        formalParameters = elementDisplayStringBuilder.toString();
      }

      suggestion.displayText =
          suggestion.completion + formalParameters + libraryInfo;
      // if (suggestion.parameterNames != null &&
      //     suggestion.parameterNames!.isNotEmpty) {
      //   suggestion.displayText = suggestion.completion + '(…)' + libraryInfo;
      // } else {
      //   suggestion.displayText = suggestion.completion + libraryInfo;
      // }

      // suggestion.docComplete =
      //     '${suggestion.libraryUri}(${accessibleExtension.displayName})\n${suggestion.docComplete ?? ''}';
      //_suggestionMap[suggestion.displayText!] = suggestion;
      collector.addSuggestion(suggestion);
    }
  }

  // /// Get a list of [InterfaceType]s that should be searched to find the
  // /// possible completions for an object having type [type].
  // List<InterfaceType> _getTypeOrdering(InterfaceType type) {
  //   // Candidate completions can come from [type] as well as any types above it
  //   // in the class hierarchy (including mixins, superclasses, and interfaces).
  //   // If a given completion identifier shows up in multiple types, we should
  //   // use the element that is nearest in the superclass chain, so we will
  //   // visit [type] first, then its mixins, then its superclass, then its
  //   // superclass's mixins, etc., and only afterwards visit interfaces.
  //   //
  //   // We short-circuit loops in the class hierarchy by keeping track of the
  //   // classes seen (not the interfaces) so that we won't be fooled by nonsense
  //   // like "class C<T> extends C<List<T>> {}"
  //   final List<InterfaceType> result = <InterfaceType>[];
  //   final Set<ClassElement> classesSeen = HashSet<ClassElement>();
  //   final List<InterfaceType> typesToVisit = <InterfaceType>[type];
  //   while (typesToVisit.isNotEmpty) {
  //     final InterfaceType nextType = typesToVisit.removeLast();
  //     if (!classesSeen.add(nextType.element)) {
  //       // Class had already been seen, so ignore this type.
  //       continue;
  //     }
  //     result.add(nextType);
  //     // typesToVisit is a stack, so push on the interfaces first, then the
  //     // superclass, then the mixins. This will ensure that they are visited
  //     // in the reverse order.
  //     typesToVisit.addAll(nextType.interfaces);
  //     if (nextType.superclass != null) {
  //       typesToVisit.add(nextType.superclass!);
  //     }
  //     typesToVisit.addAll(nextType.mixins);
  //   }
  //   return result;
  // }
}

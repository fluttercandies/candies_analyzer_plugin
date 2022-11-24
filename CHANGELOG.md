## 3.1.1

* `perfer_doc_comments` add check FunctionDeclaration

## 3.1.0

* add `perfer_doc_comments`, it's same like `public_member_api_docs` but we can ignore lint or ignore file by override [ignoreLint] and [ignoreFile] and you can override [isPrivate] and [inPrivateMember] to check private member.
* add [ignoreLint] and [ignoreFile] methods for [DartLint], override they base on your rule.
* add [astVisitor] for [DartLint], you can custom astVisitor for one lint.

## 3.0.0

* rename `candies_lints` to `candies_analyzer_plugin`.
* support to get suggestion and auto import for extension member.
* breaking change some classes are refactored.

## 2.0.3

* remove dartLints.isEmpty in analyzeFile and handleEditGetFixes methods.
  
## 2.0.2

* add `must_call_super_dispose` and `end_call_super_dispose` lints.

## 2.0.1

* add command `clear_cache` to clear plugin_manager cache.

## 2.0.0

* refactor code to support dart, yaml, generic file lint.
* support yaml lint 
* support generic lint 

## 1.0.2

* rename prefer_safe_set_state.dart

## 1.0.1

* Update method to debug

## 1.0.0

* Initial version.

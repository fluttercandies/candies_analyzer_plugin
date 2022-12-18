// ignore_for_file: implementation_imports, unused_import

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer/src/ignore_comments/ignore_info.dart';
import 'package:candies_analyzer_plugin/candies_analyzer_plugin.dart';

/// The class to help ignore error
class CandiesAnalyzerPluginIgnoreInfo {
  CandiesAnalyzerPluginIgnoreInfo.forDart(this.result) {
    final String content = result.content;
    final LineInfo lineInfo = result.lineInfo;
    //final IgnoreInfo info = IgnoreInfo.forDart(result.unit, result.content);
    for (final RegExpMatch match in _ignoreMatchers.allMatches(content)) {
      // store for quick fix
      _ignoreForThisLIneMatches.add(match);
      final List<String> codes =
          match.group(1)!.split(',').map(_toLowerCase).toList();
      // remove empty code
      codes.remove('');
      final CharacterLocation location = lineInfo.getLocation(match.start);
      // IgnoreInfo from analyzer
      // The comment is on its own line, so it refers to the next line.
      // TODO(zmtzawqlp): don't understand about this.

      // This is line number in ide
      final int lineNumber = location.lineNumber;
      _ignoreForThisLineMap
          .putIfAbsent(
            lineNumber,
            () => <String>[],
          )
          .addAll(codes);
    }

    for (final RegExpMatch match in _ignoreForFileMatcher.allMatches(content)) {
      // store for quick fix
      _ignoreForThisFileMatches.add(match);
      _ignoreForFileSet.addAll(match.group(1)!.split(',').map(_toLowerCase));
      // remove empty code
      _ignoreForFileSet.remove('');
    }
  }

  final Map<int, List<String>> _ignoreForThisLineMap = <int, List<String>>{};
  final Set<String> _ignoreForFileSet = <String>{};
  final List<RegExpMatch> _ignoreForThisLIneMatches = <RegExpMatch>[];
  final List<RegExpMatch> _ignoreForThisFileMatches = <RegExpMatch>[];
  final ResolvedUnitResult result;

  static final RegExp _ignoreMatchers =
      //IgnoreInfo.IGNORE_MATCHER;
      RegExp('//[ ]*ignore:(.*)', multiLine: true);

  static final RegExp _ignoreForFileMatcher =
      // IgnoreInfo.IGNORE_FOR_FILE_MATCHER;
      RegExp('//[ ]*ignore_for_file:(.*)', multiLine: true);

  /// Return `true` if the [code] is ignored at the file.
  bool ignored(String code) => _ignoreForFileSet.contains(_toLowerCase(code));

  /// Return `true` if the [code] is ignored at the given [line].
  bool ignoredAt(String code, int line) =>
      ignored(code) ||
      (_ignoreForThisLineMap[line - 1]?.contains(_toLowerCase(code)) ?? false);

  String _toLowerCase(String code) => code.trim().toLowerCase();

  /// The builder of ignore for this file.
  void fixIgnoreForThisFile(
    String code, {
    DartFileEditBuilder? dartFileEditBuilder,
    bool formatAll = true,
  }) {
    if (_ignoreForThisFileMatches.isEmpty) {
      dartFileEditBuilder?.addSimpleInsertion(
          0, '\/\/ ignore_for_file: $code\n');
    } else {
      for (final RegExpMatch match in _ignoreForThisFileMatches) {
        dartFileEditBuilder?.addSimpleInsertion(
            match.end, '${_ignoreForFileSet.isEmpty ? '' : ','} $code');
      }
    }

    if (formatAll) {
      dartFileEditBuilder?.formatAll(result.unit);
    }
  }

  /// The builder of ignore for this line.
  void fixIgnoreForThisLine(
    String code,
    Location location, {
    DartFileEditBuilder? dartFileEditBuilder,
    bool formatAll = true,
  }) {
    // ide line number
    final int ideLineNumber = location.startLine;
    // add after ignore:
    // previous line has ignore
    if (_ignoreForThisLineMap.containsKey(ideLineNumber - 1)) {
      final List<String> codes =
          _ignoreForThisLineMap[ideLineNumber - 1] ?? <String>[];
      for (final RegExpMatch match in _ignoreForThisLIneMatches) {
        // ide number
        final int line = result.lineInfo.getLocation(match.start).lineNumber;
        if (line == ideLineNumber - 1) {
          dartFileEditBuilder?.addSimpleInsertion(
              match.end, '${codes.isEmpty ? '' : ','} $code');
        }
      }
    }
    // add previous line
    else {
      // getOffsetOfLine line number should be index number
      //
      // current line
      // ideLineNumber
      // index is begin with 0
      // ide is begin with 1
      // getOffsetOfLine should use index number
      final int indexLine = ideLineNumber - 1;
      final int firstChartOffset = result.lineInfo.getOffsetOfLine(indexLine);

      final int columnNumber =
          result.lineInfo.getLocation(firstChartOffset).columnNumber;
      String space = '';
      for (int i = firstChartOffset; i < location.offset; i++) {
        final String char = result.content[i];
        if (char.trim() != '') {
          break;
        }
        space += char;
      }

      final int lineStartOffset = firstChartOffset - columnNumber;
      final String fix = '\/\/ ignore: $code';
      dartFileEditBuilder?.addSimpleInsertion(
        lineStartOffset,
        '\n$space$fix',
      );
    }
    if (formatAll) {
      dartFileEditBuilder?.formatAll(result.unit);
    }
  }
}

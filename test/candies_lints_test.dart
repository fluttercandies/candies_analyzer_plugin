// ignore_for_file: unused_import, unused_local_variable

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer/src/ignore_comments/ignore_info.dart';
import 'package:candies_lints/src/ignore_info.dart';
import 'package:candies_lints/src/plugin.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  final String debugFilePath =
      path.join(path.current, 'example', 'lib', 'main.dart');
  test('getErrors', () async {
    final ResolvedUnitResult result =
        await resolveFile2(path: debugFilePath) as ResolvedUnitResult;

    final List<AnalysisError> errors =
        CandiesLintsPlugin().getErrorsFromResult(result);
    //LineInfo lineInfo = LineInfo.fromContent(result.content);
  });

  test('ignore for this line', () async {
    final ResolvedUnitResult result =
        await resolveFile2(path: debugFilePath) as ResolvedUnitResult;

    final IgnoreInfo info = IgnoreInfo.forDart(result.unit, result.content);
    // info.ignoredAt(ErrorCode(), line)

    final LineInfo lineInfo = LineInfo.fromContent(result.content);
    final int offset =
        result.content.indexOf('onDoubleTap: () => setState(() {})');
    final CharacterLocation characterLocation = lineInfo.getLocation(offset);
    final CandiesLintsIgnoreInfo ignore =
        CandiesLintsIgnoreInfo.forDart(result);
    ignore.fixIgnoreForThisLine(
        'ddd',
        Location(
          '',
          offset,
          1,
          characterLocation.lineNumber,
          characterLocation.columnNumber,
        ));
  });

  test('ignore for this line  (with ignore)', () async {
    final ResolvedUnitResult result =
        await resolveFile2(path: debugFilePath) as ResolvedUnitResult;
    final LineInfo lineInfo = LineInfo.fromContent(result.content);
    final int offset = result.content.indexOf('onTap: () => setState(() {})');
    final CharacterLocation characterLocation = lineInfo.getLocation(offset);
    final CandiesLintsIgnoreInfo ignore =
        CandiesLintsIgnoreInfo.forDart(result);
    ignore.fixIgnoreForThisLine(
        'ddd',
        Location(
          '',
          offset,
          1,
          characterLocation.lineNumber,
          characterLocation.columnNumber,
        ));
  });
}

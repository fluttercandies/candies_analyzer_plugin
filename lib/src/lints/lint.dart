// ignore_for_file: implementation_imports
import 'package:analyzer_plugin/protocol/protocol_common.dart';

/// The lint base
abstract class CandyLint {
  /// The severity of the error.
  AnalysisErrorSeverity get severity => AnalysisErrorSeverity.INFO;

  /// The type of the error.
  AnalysisErrorType get type => AnalysisErrorType.LINT;

  /// The location associated with the error.
  //Location location;

  /// The message to be displayed for this error. The message should indicate
  /// what is wrong with the code and why it is wrong.
  String get message;

  /// The correction message to be displayed for this error. The correction
  /// message should indicate how the user can fix the error. The field is
  /// omitted if there is no correction message associated with the error code.
  String? get correction => null;

  /// The name, as a string, of the error code associated with this error.
  String get code;

  /// The URL of a page containing documentation associated with this error.
  String? get url => null;

  /// Additional messages associated with this diagnostic that provide context
  /// to help the user understand the diagnostic.
  List<DiagnosticMessage>? get contextMessages => null;

  /// A hint to indicate to interested clients that this error has an
  /// associated fix (or fixes). The absence of this field implies there are
  /// not known to be fixes. Note that since the operation to calculate whether
  /// fixes apply needs to be performant it is possible that complicated tests
  /// will be skipped and a false negative returned. For this reason, this
  /// attribute should be treated as a "hint". Despite the possibility of false
  /// negatives, no false positives should be returned. If a client sees this
  /// flag set they can proceed with the confidence that there are in fact
  /// associated fixes.
  //bool? get hasFix => false;
}

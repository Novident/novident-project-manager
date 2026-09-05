import 'package:novident_project_manager/src/ast/ast.dart';
import 'package:novident_project_manager/src/layout/options/new_page_options.dart';

/// External conversion of [NewPageOptions] into AST page-break content.
///
/// Lives outside the data class so model changes never rewrite the conversion.
class NewPageOptionsBuilder {
  const NewPageOptionsBuilder._();

  /// Builds the new-line [NewLine]s to insert for [options].
  ///
  /// Uses [customNewLine] as the line content (defaults to `\n`); [newLines]
  /// overrides the configured count; [addCommaAfterNewLine] wraps each line
  /// with a comma prefix/suffix.
  static List<NewLine> getNewLines(
    NewPageOptions options, {
    String? customNewLine,
    int? newLines,
    bool addCommaAfterNewLine = false,
  }) {
    final String comma = addCommaAfterNewLine ? ',' : '';
    final NewLine toCopy = NewLine.fixed(
      prefix: comma,
      newLine: customNewLine ?? '\n',
      suffix: comma,
    );
    if ((newLines == null || newLines < 1) &&
        options.newLinesCount.value < 1) {
      return <NewLine>[];
    }
    return newLines != null
        ? List<NewLine>.filled(newLines, toCopy)
        : List<NewLine>.filled(options.newLinesCount.value, toCopy);
  }

  /// Uppercases the configured leading characters of [content].
  ///
  /// Currently a pass-through: the transformation is applied by the compiler
  /// pipeline that owns the delta (see the option's `charactersToUpperCase`).
  static Content? toUpperCase(
    NewPageOptions options, {
    required Content content,
  }) {
    return content;
  }
}

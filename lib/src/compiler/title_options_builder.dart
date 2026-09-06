import 'package:novident_editor_styles/novident_editor_styles.dart';
import 'package:novident_project_manager/src/ast/ast.dart';
import 'package:novident_project_manager/src/constants/novident_project_defaults.dart';
import 'package:novident_project_manager/src/extensions/string_extension.dart';
import 'package:novident_project_manager/src/layout/options/title_options.dart';

/// External conversion of [TitleOptions] into AST paragraphs.
///
/// Lives outside the data class so model changes never rewrite the conversion.
class TitleOptionsBuilder {
  const TitleOptionsBuilder._();

  /// Builds the paragraph(s) written before the title, splitting
  /// `options.titlePrefix` on the layout's newline representation when present.
  static List<Paragraph> buildPrefix(
    TitleOptions options, {
    NovidentStyleDefinition? style,
  }) {
    final defaultStyle = style == null
        ? options.attrSuffix.toStyle()
        : options.attrSuffix.toStyle().merge(style);
    Paragraph paragraph = Paragraph.empty(style: defaultStyle);
    final contents = <Paragraph>[];
    if (options.titlePrefix.hasFormatNewLine) {
      final List<String> tokenized = options.titlePrefix.split(
        NovidentProjectDefaults.kDefaultLayoutNewlineRepresentation,
      );
      for (final String str in tokenized) {
        final bool isNewline = str ==
                NovidentProjectDefaults.kDefaultLayoutNewlineRepresentation ||
            str == '\n';
        if (isNewline) {
          contents.add(paragraph);
          paragraph = Paragraph.empty(style: defaultStyle);
          continue;
        }
        paragraph.insert(applyCase(str, lettercase: options.lettercaseSuffix));
      }
      contents.add(paragraph);
      return contents;
    }
    paragraph.insert(
        applyCase(options.titlePrefix, lettercase: options.lettercasePrefix));
    return [paragraph];
  }

  /// Builds the paragraph(s) written after the title, splitting
  /// `options.titleSuffix` on the layout's newline representation when present.
  static List<Paragraph> buildSuffix(
    TitleOptions options, {
    NovidentStyleDefinition? style,
  }) {
    final defaultStyle = style == null
        ? options.attrSuffix.toStyle()
        : options.attrSuffix.toStyle().merge(style);
    Paragraph paragraph = Paragraph.empty(style: defaultStyle);
    final contents = <Paragraph>[];
    if (options.titleSuffix.hasFormatNewLine) {
      final List<String> tokenized = options.titleSuffix.split(
        NovidentProjectDefaults.kDefaultLayoutNewlineRepresentation,
      );
      for (final String str in tokenized) {
        final bool isNewline = str ==
                NovidentProjectDefaults.kDefaultLayoutNewlineRepresentation ||
            str == '\n';
        if (isNewline) {
          contents.add(paragraph);
          paragraph = Paragraph.empty(style: defaultStyle);
          continue;
        }
        paragraph.insert(applyCase(str, lettercase: options.lettercaseSuffix));
      }
      contents.add(paragraph);
      return contents;
    }
    paragraph.insert(
        applyCase(options.titleSuffix, lettercase: options.lettercaseSuffix));
    return [paragraph];
  }

  /// Transforms [str] according to [lettercase].
  static String applyCase(String str, {required LetterCase lettercase}) {
    switch (lettercase) {
      case LetterCase.titlecase:
        final StringBuffer buffer = StringBuffer();
        bool ignoreUntilNextWhitespace = false;
        for (int i = 0; i < str.length; i++) {
          final bool isWhitespace = str[i].isStrictWhiteSpace;
          if (isWhitespace) {
            buffer.write(str[i]);
            ignoreUntilNextWhitespace = false;
            continue;
          }
          if (ignoreUntilNextWhitespace) {
            buffer.write(str[i]);
            continue;
          }
          ignoreUntilNextWhitespace = true;
          buffer.write(str[i].toUpperCase());
        }
        return '$buffer';
      case LetterCase.uppercase:
        return str.toUpperCase();
      case LetterCase.lowercase:
        return str.toLowerCase();
      default:
        return str;
    }
  }
}

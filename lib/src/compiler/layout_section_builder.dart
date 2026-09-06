import 'package:novident_project_manager/src/ast/ast.dart';
import 'package:novident_project_manager/src/compiler/title_options_builder.dart';
import 'package:novident_project_manager/src/layout/options/layout_sections.dart';
import 'package:novident_project_manager/src/layout/options/title_options.dart';
import 'package:novident_project_manager/src/layout/processor_context.dart';

/// External conversion of a [LayoutSection] into AST content.
///
/// Lives outside the data class so model changes never rewrite the conversion.
class LayoutSectionBuilder {
  const LayoutSectionBuilder._();

  /// Builds the compiled content blocks of [section].
  ///
  /// [options] supplies the title prefix/suffix behavior; [context] the
  /// compilation state; [assignFamilyBySection] lets the layout pick the font
  /// family; [ignorePreffixSuffix] skips the title prefix/suffix when the
  /// section is not the title; [fontFamily] the font to use; [content] the
  /// section payload (a `String` of plain text or a `List<Content>`).
  ///
  /// Returns `null` (through the caller) when nothing should be written.
  static List<Content>? build(
    LayoutSection section, {
    required TitleOptions options,
    required Context context,
    required bool assignFamilyBySection,
    required bool ignorePreffixSuffix,
    required String fontFamily,
    required dynamic content,
  }) {
    final defaultStyle = section.attributes
        .toStyle(fontFamily: assignFamilyBySection ? fontFamily : null);
    Paragraph paragraph = Paragraph.empty(
      style: defaultStyle,
    );
    final List<Content> contents = [];
    if (!ignorePreffixSuffix) {
      final ops = TitleOptionsBuilder.buildPrefix(options, style: defaultStyle);
      contents.insertAll(0, ops);
    }
    if (section.show && content != null && content.isNotEmpty) {
      if (content is String) {
        paragraph.insert(
          TitleOptionsBuilder.applyCase(
            content,
            lettercase: options.lettercaseTitle,
          ),
        );
        contents.add(paragraph);
      }
      if (content is List<Content>) {
        contents.addAll(content);
      }
    }

    if (!ignorePreffixSuffix) {
      final ops = TitleOptionsBuilder.buildSuffix(options, style: defaultStyle);
      contents.addAll(ops);
    }
    return contents;
  }
}

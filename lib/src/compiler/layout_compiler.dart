import 'package:novident_editor_styles/novident_editor_styles.dart';
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_editor_document/novident_editor_document.dart' as nov;

import 'package:novident_project_manager/src/compiler/new_page_options_builder.dart';
import '../constants/novident_project_defaults.dart';
import '../extensions/cast_extension.dart';
import '../extensions/project_delta_content_extension.dart';
import '../extensions/string_extension.dart';
import '../layout/layout.dart';
import '../ast/ast.dart';
import 'layout_section_builder.dart';
import 'content_parser.dart';

/// External Layout → AST compiler.
///
/// Converts a [Layout] (and its option data classes) plus a binder [Node] and
/// a compilation [Context] into the AST `DocumentPage` consumed by the
/// compiler. Keeping this mapping outside the data classes means changes to the
/// `Layout`/`TitleOptions`/… models never rewrite the conversion logic (and the
/// conversion can be versioned/tested on its own).
class LayoutCompiler {
  const LayoutCompiler._();

  /// Compiles [layout] against [file] into a new `DocumentPage`.
  ///
  /// Behavior mirrors the legacy `Layout.applyLayout` flow: new-line page
  /// options, title/synopsis section building (through the section builders),
  /// notes/metadata stubs, and the text-section content (with placeholder
  /// replacement when the context does not defer it).
  ///
  /// Returns `null` for non-normal folders.
  static DocumentPage? compileLayout(
    Layout layout,
    Node file,
    Context context, {
    String? fontFamily,
  }) {
    fontFamily = getDefaultFont();
    final DocumentPage page = DocumentPage.empty();
    // we do not accept non normal folders
    if (file is Folder && !file.type.isNormalFolder) {
      return null;
    }

    // if font family is ["by-layout"] then layout decide the font family
    bool assignFamilyBySection = false;
    if (fontFamily.equals(NovidentProjectDefaults.kDefaultFormatFontFamily,
        caseSensitive: false)) {
      fontFamily = "";
      assignFamilyBySection = true;
    }
    Document? doc;
    if (file is Document) doc = file;
    final LayoutSection titleMapped = layout.layoutManager.titleSection;
    final LayoutSection metadataMapped = layout.layoutManager.metadataSection;
    final LayoutSection synopsisMapped = layout.layoutManager.synopsisSection;
    final LayoutSection notesMapped = layout.layoutManager.notesSection;
    final LayoutSection textMapped = layout.layoutManager.textSection;
    final bool showTitle = titleMapped.show;
    final bool showText = textMapped.show;
    final bool showSynopsis = synopsisMapped.show;
    if (context.shouldWritePageOptions &&
        layout.newPageOptions.newLinesCount.value > 0) {
      context.shouldWritePageOptions = false;
      // adds all the new lines before the content
      page.insert(
          Paragraph(value: NewPageOptionsBuilder.getNewLines(layout.newPageOptions)));
    }

    final title = LayoutSectionBuilder.build(
      titleMapped,
      options: layout.titleOptions,
      context: context,
      assignFamilyBySection: assignFamilyBySection,
      fontFamily: fontFamily,
      content: !showTitle ? '' : file.cast<UniversalName>().objectName,
      ignorePreffixSuffix: false,
    );
    if (title != null && title.isNotEmpty) {
      page.addAll(title);
    }
    // metadata section
    // TODO: how should we add this? (kept from the legacy implementation)
    if (metadataMapped.show) {
      throw UnimplementedError('metadata section is not implemented yet');
    }
    // synopsis section
    if (showSynopsis && doc != null) {
      final synopsis = LayoutSectionBuilder.build(
        synopsisMapped,
        options: layout.titleOptions,
        context: context,
        assignFamilyBySection: assignFamilyBySection,
        fontFamily: fontFamily,
        content: ContentParser.parseDocument(
            context.getNodeSynopsis<nov.Document>(doc.id).value),
        ignorePreffixSuffix: true,
      );
      if (synopsis != null) {
        page.addAll(synopsis);
      }
    }
    // notes section (kept from the legacy implementation)
    if (notesMapped.show) {
      final notes = LayoutSectionBuilder.build(
        notesMapped,
        options: layout.titleOptions,
        context: context,
        assignFamilyBySection: assignFamilyBySection,
        fontFamily: fontFamily,
        content: context.getNodeContent(file.id),
        ignorePreffixSuffix: true,
      );
      if (notes != null) {
        page.addAll(notes);
      }
    }
    // text section
    if (showText) {
      if (fontFamily.isEmpty) {
        fontFamily = textMapped.attributes.fontFamily;
      }
      final nov.Document content = context.getNodeContent(file.id).value;
      final nov.Document effective = context.processPlaceholderAtEnd
          ? content
          : content.replacePlaceholders(context);
      page.addAll(ContentParser.parseDocument(effective));
    }
    return page;
  }
}

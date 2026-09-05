import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/layout/layout.dart';
import 'package:novident_project_manager/src/layout/options/new_page_options.dart';
import 'package:novident_project_manager/src/layout/options/section_attributes.dart';
import 'package:novident_project_manager/src/layout/options/title_options.dart';

void main() {
  test('Layout.toMap uses spec keys (snake_case, no camelCase)', () {
    final layout = Layout.basic(
      id: 'l1',
      name: 'Chapter Layout',
      assigned: 'chapter',
      titleOptions: TitleOptions(
        titlePrefix: 'Chapter <\$n>',
        titleSuffix: '',
        lettercasePrefix: LetterCase.normal,
        lettercaseSuffix: LetterCase.normal,
        lettercaseTitle: LetterCase.titlecase,
        attrPrefix: SectionAttributes.common(align: 'center'),
        attrSuffix: SectionAttributes.common(align: 'center'),
      ),
      newPageOptions: NewPageOptions(
        newLinesCount: 3,
        charactersToUpperCase: 2,
      ),
    );

    final map = layout.toMap();

    // Top-level keys.
    expect(map['schema_version'], 1);
    expect(map['id'], 'l1');
    expect(map['name'], 'Chapter Layout');
    expect(map['section'], 'chapter');
    expect(map.containsKey('layout_manager'), isTrue);
    expect(map.containsKey('title_options'), isTrue);
    expect(map.containsKey('new_page_options'), isTrue);
    expect(map.containsKey('separator_options'), isTrue);
    expect(map.containsKey('settings'), isTrue);

    // No legacy camelCase keys remain.
    expect(map.containsKey('assignedSection'), isFalse);
    expect(map.containsKey('layoutManager'), isFalse);
    expect(map.containsKey('pageOptions'), isFalse);
    expect(map.containsKey('titleOptions'), isFalse);
    expect(map.containsKey('separatorSections'), isFalse);

    // Nested structures.
    final titleOptions = map['title_options'] as Map<String, dynamic>;
    expect(titleOptions['prefix'], 'Chapter <\$n>');
    expect(titleOptions['suffix'], '');
    expect(titleOptions['letter_case_title'], 1); // titlecase
    expect(titleOptions['letter_case_prefix'], 3); // normal
    expect(titleOptions.containsKey('attr_prefix'), isTrue);
    expect(titleOptions.containsKey('attr_suffix'), isTrue);

    final newPageOptions = map['new_page_options'] as Map<String, dynamic>;
    expect(newPageOptions['new_lines_count'], 3);
    expect(newPageOptions['characters_to_uppercase'], 2);

    final layoutManager = map['layout_manager'] as Map<String, dynamic>;
    expect(layoutManager.containsKey('title_section'), isTrue);
    expect(layoutManager.containsKey('metadata_section'), isTrue);
    expect(layoutManager.containsKey('synopsis_section'), isTrue);
    expect(layoutManager.containsKey('notes_section'), isTrue);
    expect(layoutManager.containsKey('text_section'), isTrue);
    expect(layoutManager.containsKey('titleSection'), isFalse);

    final separatorOptions = map['separator_options'] as Map<String, dynamic>;
    expect(separatorOptions.containsKey('before'), isTrue);
    expect(separatorOptions.containsKey('between'), isTrue);
    expect(separatorOptions.containsKey('after_section'), isTrue);
    expect(separatorOptions.containsKey('override_separator_after'), isTrue);
    expect(separatorOptions.containsKey('ignore_blank_lines_with_styles'), isTrue);

    final settings = map['settings'] as Map<String, dynamic>;
    expect(settings.containsKey('apply_changes'), isTrue);
    expect(settings.containsKey('indent_paragraph'), isTrue);
    expect(settings.containsKey('indent_just_after_first_paragraph'), isTrue);
  });

  test('Layout roundtrips through toMap/fromMap', () {
    final layout = Layout.basic(
      id: 'l1',
      name: 'Chapter',
      assigned: 'chapter',
      titleOptions: TitleOptions(
        titlePrefix: 'Chapter <\$n>',
        titleSuffix: '',
        lettercasePrefix: LetterCase.uppercase,
        lettercaseSuffix: LetterCase.lowercase,
        lettercaseTitle: LetterCase.titlecase,
        attrPrefix: SectionAttributes.common(align: 'center', fontSize: 16),
        attrSuffix: SectionAttributes.common(align: 'left', fontSize: 12),
      ),
      newPageOptions: NewPageOptions(
        newLinesCount: 3,
        charactersToUpperCase: 2,
      ),
    );

    final map = layout.toMap();
    final decoded = Layout.fromMap(map);

    expect(decoded.toMap(), map);
  });

  test('TitleOptions.fromMap reads each letter_case_* key independently', () {
    final options = TitleOptions(
      titlePrefix: 'P',
      titleSuffix: 'S',
      lettercasePrefix: LetterCase.uppercase, // 0
      lettercaseSuffix: LetterCase.lowercase, // 2
      lettercaseTitle: LetterCase.titlecase, // 1
      attrPrefix: SectionAttributes.common(),
      attrSuffix: SectionAttributes.common(),
    );

    final decoded = TitleOptions.fromMap(options.toMap());

    expect(decoded.lettercasePrefix, LetterCase.uppercase);
    expect(decoded.lettercaseSuffix, LetterCase.lowercase);
    expect(decoded.lettercaseTitle, LetterCase.titlecase);
    expect(decoded.titlePrefix, 'P');
    expect(decoded.titleSuffix, 'S');
  });

  test('Layout.fromMap tolerates missing fields', () {
    final decoded = Layout.fromMap(const <String, dynamic>{});

    expect(decoded.id, '');
    expect(decoded.name, '');
    expect(decoded.assignedSection, '');
    expect(decoded.titleOptions.titlePrefix, '');
    expect(decoded.newPageOptions.newLinesCount.value, 0);
    expect(decoded.settings.applyChanges, false);
  });
}

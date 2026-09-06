import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/section/section.dart';
import 'package:novident_project_manager/src/project/section/section_manager.dart';
import 'package:novident_project_manager/src/project/section/section_types_configuration.dart';
import 'package:novident_project_manager/src/project/sections_codec.dart';

void main() {
  group('SectionsCodec', () {
    test('roundtrips sections.index.json', () {
      final manager = SectionManager(
        sections: <Section>[
          Section(id: 'structured-based', name: 'structured-based'),
          Section(id: 'chapter', name: 'chapter'),
          Section(id: 'scene', name: 'scene'),
        ],
        config: SectionTypeConfigurations(
          outlineFolder: const <String, String>{'0': 'chapter', '1': 'scene'},
          outlineDocs: const <String, String>{'0': 'scene'},
        ),
      );

      final encoded = SectionsCodec.encode(manager);
      final decoded = SectionsCodec.decode(encoded);

      expect(decoded.sections.length, 3);
      expect(decoded.sections[1].id, 'chapter');
      expect(decoded.sections[1].name, 'chapter');
      expect(decoded.config.outlineFolder,
          <String, String>{'0': 'chapter', '1': 'scene'});
      expect(decoded.config.outlineDocs, <String, String>{'0': 'scene'});
    });

    test('decodes empty/missing fields gracefully', () {
      final decoded = SectionsCodec.decode('{}');
      expect(decoded.sections, isEmpty);
      expect(decoded.config.outlineFolder, isEmpty);
      expect(decoded.config.outlineDocs, isEmpty);
    });
  });
}

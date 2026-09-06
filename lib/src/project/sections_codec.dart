import 'dart:convert';

import 'package:novident_project_manager/src/project/section/section.dart';
import 'package:novident_project_manager/src/project/section/section_manager.dart';
import 'package:novident_project_manager/src/project/section/section_types_configuration.dart';
import 'package:novident_project_manager/src/schema/registry.dart';

/// Maps `indexation/sections.index.json` to/from the Dart section model
/// (`SectionManager` + `SectionTypeConfigurations`).
///
/// The `.nov` shape is:
/// ```json
/// {
///   "schema_version": 1,
///   "sections": ["structured-based", "chapter", "scene"],
///   "outline": {
///     "folder": { "0": "chapter" },
///     "file":   { "0": "scene" }
///   }
/// }
/// ```
///
/// Mapping:
/// - `sections` (list of strings) ↔ `SectionManager.sections` (`Section.id` and
///   `Section.name` both equal the string — a `.nov` section is a free string).
/// - `outline.folder` ↔ `SectionTypeConfigurations.outlineFolder`.
/// - `outline.file` ↔ `SectionTypeConfigurations.outlineDocs`.
class SectionsCodec {
  SectionsCodec._();

  static String encode(SectionManager manager) {
    return jsonEncode(<String, dynamic>{
      'schema_version': kCurrentSchemaVersion,
      'sections': manager.sections.map((s) => s.name).toList(),
      'outline': <String, dynamic>{
        'folder': manager.config.outlineFolder,
        'file': manager.config.outlineDocs,
      },
    });
  }

  static SectionManager decode(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final sections =
        ((map['sections'] as List?)?.cast<String>() ?? const <String>[])
            .map((s) => Section(id: s, name: s))
            .toList();
    final outline = map['outline'] as Map<String, dynamic>? ?? const {};
    return SectionManager(
      sections: sections,
      config: SectionTypeConfigurations(
        outlineFolder:
            (outline['folder'] as Map?)?.cast<String, String>() ?? const {},
        outlineDocs:
            (outline['file'] as Map?)?.cast<String, String>() ?? const {},
      ),
    );
  }
}

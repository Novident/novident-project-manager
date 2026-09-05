import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/export/export.dart';

void main() {
  final Map<String, dynamic> fixture = jsonDecode('''
{
  "schema_version": 1,
  "id": "e1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "name": "PDF Export — Standard Novel",
  "format_id": "f1e2d3c4-b5a6-7890-abcd-ef1234567890",
  "output_type": "pdf",
  "last_exported": null,
  "config": {
    "include_title_page": true,
    "include_toc": true,
    "include_copyright": true,
    "embed_fonts": true,
    "image_quality": 90
  }
}
''') as Map<String, dynamic>;

  test('Export roundtrips the real fixture shape', () {
    final decoded = Export.fromJson(fixture);
    expect(json.decode(decoded.toJsonString()), fixture);
  });

  test('Export reads nested values', () {
    final export = Export.fromJson(fixture);

    expect(export.schemaVersion, 1);
    expect(export.id, 'e1a2b3c4-d5e6-7890-abcd-ef1234567890');
    expect(export.formatId, 'f1e2d3c4-b5a6-7890-abcd-ef1234567890');
    expect(export.outputType, 'pdf');
    expect(export.lastExported, isNull);
    expect(export.config.includeTitlePage, isTrue);
    expect(export.config.imageQuality, 90);
  });

  test('Export.fromJson tolerates missing fields', () {
    final export = Export.fromJson(const <String, dynamic>{});
    expect(export.id, '');
    expect(export.name, '');
    expect(export.config.includeToc, isFalse);
    expect(export.config.imageQuality, 0);
  });
}

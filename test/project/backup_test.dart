import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/backup/backup.dart';

void main() {
  final Map<String, dynamic> fixture = jsonDecode('''
{
  "schema_version": 1,
  "format": "novident_backup",
  "version": 1,
  "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "project_name": "The Crystal Labyrinth",
  "created_at": "2026-07-23T14:30:00Z",
  "checksum": "sha256:placeholder",
  "tree": {
    "root": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "folders": {
      "b2c3d4e5-f6a7-8901-bcde-f12345678901": {
        "n": "Draft",
        "t": "manuscript",
        "p": null,
        "c": ["c3d4e5f6-a7b8-9012-cdef-123456789012"]
      }
    },
    "documents": {
      "d4e5f6a7-b8c9-0123-defa-234567890123": {
        "n": "The Awakening",
        "p": "c3d4e5f6-a7b8-9012-cdef-123456789012"
      },
      "d6e7f8a9-b0c1-2345-defa-456789012345": {
        "n": "Original Opening",
        "p": "c5d6e7f8-a9b0-1234-cdef-345678901234",
        "x": true
      }
    },
    "external": {
      "x1a2b3c4-d5e6-7890-abcd-ef1234567890.png": {
        "n": "Labyrinth Map",
        "a": "f2a3b4c5-d6e7-8901-fabc-012345678901"
      }
    }
  }
}
''') as Map<String, dynamic>;

  test('Backup roundtrips the real fixture shape', () {
    final decoded = Backup.fromJson(fixture);
    expect(json.decode(decoded.toJsonString()), fixture);
  });

  test('Backup reads the compact tree entries', () {
    final backup = Backup.fromJson(fixture);

    expect(backup.schemaVersion, 1);
    expect(backup.format, 'novident_backup');
    expect(backup.tree.root, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');

    final folder = backup.tree.folders['b2c3d4e5-f6a7-8901-bcde-f12345678901']!;
    expect(folder.name, 'Draft');
    expect(folder.type, 'manuscript');
    expect(folder.parent, isNull);
    expect(folder.children, contains('c3d4e5f6-a7b8-9012-cdef-123456789012'));

    final trashed =
        backup.tree.documents['d6e7f8a9-b0c1-2345-defa-456789012345']!;
    expect(trashed.trashed, isTrue);

    final external = backup.tree.external.values.single;
    expect(external.name, 'Labyrinth Map');
    expect(external.attachedTo, 'f2a3b4c5-d6e7-8901-fabc-012345678901');
  });

  test('BackupDocument omits the trashed key when not trashed', () {
    final document = const BackupDocument(
      name: 'The Awakening',
      parent: 'c3d4e5f6-a7b8-9012-cdef-123456789012',
    ).toJson();
    expect(document.containsKey('x'), isFalse);

    final trashed = const BackupDocument(
      name: 'Old',
      parent: 'p',
      trashed: true,
    ).toJson();
    expect(trashed['x'], isTrue);
  });

  test('Backup.fromJson tolerates missing fields', () {
    final backup = Backup.fromJson(const <String, dynamic>{});
    expect(backup.format, 'novident_backup');
    expect(backup.version, 1);
    expect(backup.tree.folders, isEmpty);
    expect(backup.tree.documents, isEmpty);
  });
}

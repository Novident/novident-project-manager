import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_project_manager/src/schema/registry.dart';

/// Roundtrips a top-level schema binding through its own typed codec.
Map<String, dynamic> roundtrip<T>(SchemaFile<T> file, String source) =>
    json.decode(file.encode(file.decode(source))) as Map<String, dynamic>;

/// Roundtrips a collection item through its own typed codec.
Map<String, dynamic> roundtripCollection<T>(
        SchemaCollection<T> collection, String source) =>
    json.decode(collection.encode(collection.decode(source)))
        as Map<String, dynamic>;

void main() {
  group('structural contract mirrors schema-v1.yaml', () {
    test('required dirs', () {
      expect(
          SchemaRegistry.requiredDirs,
          containsAll(<String>[
            'files',
            'files/external',
            'indexation',
            'history',
            'layouts',
            'compiler/formats',
            'compiler/exports',
            'snapshots',
          ]));
    });

    test('required files', () {
      expect(
          SchemaRegistry.requiredFiles,
          containsAll(<String>[
            'files/metadata.json',
            'files/backup.json',
            'indexation/binder.index.json',
            'indexation/sections.index.json',
            'indexation/icon.index.json',
            'indexation/corkboard.index.json',
            'indexation/search.index.json',
            'indexation/target.index.json',
          ]));
    });

    test('every writeable required file has a typed binding path', () {
      final boundPaths = SchemaRegistry.topLevelPaths.values.toSet();
      // search.index.json is engine-managed (no Dart write binding).
      final dartWriteable = SchemaRegistry.requiredFiles
          .where((f) => !SchemaRegistry.engineManagedFiles.contains(f));
      for (final file in dartWriteable) {
        expect(boundPaths, contains(file), reason: 'missing binding for $file');
      }
    });

    test('collection dirs + item key match the contract', () {
      expect(
          SchemaRegistry.collectionDirs,
          containsAll(<(String, String)>[
            ('layouts', 'id'),
            ('compiler/formats', 'id'),
            ('compiler/exports', 'id'),
            ('history', 'session_date'),
          ]));
    });
  });

  group('top-level codec bindings', () {
    test('metadata binding maps files/metadata.json', () {
      const source = '{"schema_version":1,"project":{"id":"p1","name":"N"}}';
      final metadata = SchemaRegistry.metadata.decode(source);
      expect(metadata.project.id, 'p1');
      expect(metadata.project.name, 'N');

      final map = roundtrip(SchemaRegistry.metadata, source);
      expect(map['schema_version'], 1);
      expect((map['project'] as Map<String, dynamic>)['id'], 'p1');
    });

    test('binder binding decodes a minimal tree', () {
      const source = '''
      {
        "project_id": "p1",
        "project_name": "N",
        "schema_version": 1,
        "tree": [
          {"id": "d1", "name": "Doc", "node_type": "document", "path": "files/d1"}
        ]
      }
      ''';
      final binder = SchemaRegistry.binder.decode(source);
      expect(binder.projectId, 'p1');
      expect((binder.root.children.single as Document).name, 'Doc');

      final map = json.decode(SchemaRegistry.binder.encode(binder))
          as Map<String, dynamic>;
      expect(map['project_id'], 'p1');
      expect((map['tree'] as List).length, 1);
    });

    test('sections binding roundtrips', () {
      const source =
          '{"schema_version":1,"sections":["structured-based","chapter"],'
          '"outline":{"folder":{"0":"chapter"},"file":{"0":"scene"}}}';
      final sections = SchemaRegistry.sections.decode(source);
      expect(sections.length, 2);

      final map = roundtrip(SchemaRegistry.sections, source);
      expect((map['sections'] as List).length, 2);
      expect(map['schema_version'], 1);
    });

    test('icon binding roundtrips defaults + flattened overrides', () {
      const source =
          '{"schema_version":1,"defaults":{"file":{"icon":"file","type":"internal","path":null}}}';
      final icons = SchemaRegistry.icon.decode(source);
      expect(icons.defaults['file']!.icon, 'file');

      final map = roundtrip(SchemaRegistry.icon, source);
      expect((map['defaults'] as Map<String, dynamic>)['file'], isNotNull);
    });

    test('corkboard binding roundtrips', () {
      const source = '{"schema_version":1,"corkboards":[]}';
      final map = roundtrip(SchemaRegistry.corkboard, source);
      expect(map['schema_version'], 1);
      expect((map['corkboards'] as List), isEmpty);
    });

    test('target binding roundtrips', () {
      const source =
          '{"schema_version":1,"general":{"type_target":"nanowrimo","target":50000}}';
      final target = SchemaRegistry.target.decode(source);
      expect(target.general.typeTarget, 'nanowrimo');

      final map = roundtrip(SchemaRegistry.target, source);
      expect(
          (map['general'] as Map<String, dynamic>)['type_target'], 'nanowrimo');
    });

    test('backup binding roundtrips', () {
      const source =
          '{"schema_version":1,"format":"novident_backup","project_id":"p1","tree":{}}';
      final backup = SchemaRegistry.backup.decode(source);
      expect(backup.format, 'novident_backup');

      final map = roundtrip(SchemaRegistry.backup, source);
      expect(map['format'], 'novident_backup');
      expect((map['tree'] as Map<String, dynamic>)['folders'], isEmpty);
    });
  });

  group('collection codec bindings', () {
    test('each collection codec roundtrips a minimal item', () {
      expect(
          roundtripCollection(SchemaRegistry.layouts,
              '{"schema_version":1,"id":"l1","name":"Chapter"}')['id'],
          'l1');
      expect(
          roundtripCollection(SchemaRegistry.formats,
              '{"schema_version":1,"id":"f1","name":"Standard"}')['id'],
          'f1');
      expect(
          roundtripCollection(SchemaRegistry.exports,
              '{"schema_version":1,"id":"e1","name":"PDF"}')['id'],
          'e1');
      expect(
          roundtripCollection(
              SchemaRegistry.sessions,
              '{"schema_version":1,"session_id":"s1",'
              '"session_date":"2026-07-20T00:00:00Z"}')['session_id'],
          's1');
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_project_manager/src/project/binder_store.dart';
import 'package:novident_project_manager/src/reducer/binder_actions.dart';

class _FakeBinderIo implements BinderIo {
  _FakeBinderIo([this.json]);

  String? json;
  int writes = 0;

  @override
  Future<String?> readBinder() async => json;

  @override
  Future<void> writeBinder(String value) async {
    writes++;
    json = value;
  }
}

const String _binderFixture = '''
{
  "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "project_name": "The Crystal Labyrinth",
  "schema_version": 1,
  "version": 3,
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-02T00:00:00Z",
  "tree": [
    {
      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "name": "Draft",
      "node_type": "folder",
      "folder_type": "manuscript",
      "attached_section": "structured-based",
      "path": "files/b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "children": [
        {
          "id": "d4e5f6a7-b8c9-0123-defa-234567890123",
          "name": "The Awakening",
          "node_type": "document",
          "attached_section": "scene",
          "path": "files/d4e5f6a7-b8c9-0123-defa-234567890123"
        }
      ]
    },
    {
      "id": "c5d6e7f8-a9b0-1234-cdef-345678901234",
      "name": "Trash",
      "node_type": "folder",
      "folder_type": "trash",
      "attached_section": "structured-based",
      "path": "files/c5d6e7f8-a9b0-1234-cdef-345678901234",
      "children": []
    }
  ],
  "lookup": {},
  "external_files": {}
}
''';

void main() {
  test('load decodes the tree and preserves the header', () async {
    final store = BinderStore(io: _FakeBinderIo(_binderFixture));
    final binder = await store.load();

    expect(binder.projectName, 'The Crystal Labyrinth');
    expect(store.root.children.length, 2);
    expect(store.isLoaded, isTrue);
    expect(store.binder, same(binder));

    // A second load hits the cache.
    final again = await store.load();
    expect(again, same(binder));
  });

  test('persist recomputes lookup and keeps header, bumping updated_at',
      () async {
    final io = _FakeBinderIo(_binderFixture);
    final store = BinderStore(io: io);
    await store.load();

    // Mutate the tree through BinderActions, then flush.
    final String draftId = store.root.children
        .whereType<Folder>()
        .firstWhere((f) => f.type.isManuscriptFolder)
        .id;
    BinderActions.createDocument(
      store.root,
      parentId: draftId,
      name: 'A New Chapter',
      id: 'newdoc',
      section: 'chapter',
    );
    await store.persist();

    expect(io.writes, 1);
    final map = jsonDecode(io.json!) as Map<String, dynamic>;

    // Header preserved.
    expect(map['project_id'], 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
    expect(map['version'], 3);
    expect(map['schema_version'], 1);
    expect(map['created_at'], '2026-01-01T00:00:00Z');
    expect(map['updated_at'], isNot('2026-01-02T00:00:00Z'));

    // Tree changed + lookup recomputed.
    final tree = map['tree'] as List;
    expect(jsonEncode(tree), contains('newdoc'));
    final lookup = map['lookup'] as Map<String, dynamic>;
    expect(lookup.containsKey('newdoc'), isTrue);

    // The persisted file decodes back with the new document.
    final reloaded = BinderStore(io: io);
    await reloaded.load();
    expect(BinderActions.findNode(reloaded.root, 'newdoc'), isNotNull);
  });

  test('persist without load throws a clear error', () async {
    final store = BinderStore(io: _FakeBinderIo());
    await expectLater(store.persist(), throwsStateError);
  });

  test('load throws when the file is missing', () async {
    final store = BinderStore(io: _FakeBinderIo());
    await expectLater(store.load(), throwsStateError);
  });

  test('clear forces a fresh decode on the next load', () async {
    final io = _FakeBinderIo(_binderFixture);
    final store = BinderStore(io: io);
    await store.load();
    expect(store.isLoaded, isTrue);

    store.clear();
    expect(store.isLoaded, isFalse);
    await store.load();
    expect(store.isLoaded, isTrue);
  });
}

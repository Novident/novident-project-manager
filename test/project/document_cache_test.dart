import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_project_manager/src/project/document_cache.dart';

class _FakeDocumentIo implements DocumentIo {
  _FakeDocumentIo({this.content});

  String? content;
  int reads = 0;
  final List<String> writes = <String>[];

  @override
  Future<String?> readContent(String nodeId) async {
    reads++;
    return content;
  }

  @override
  Future<void> writeContent(String nodeId, String json) async =>
      writes.add(json);
}

Document _doc() => Document.fromJson(const <String, dynamic>{
      'document': <String, dynamic>{'type': 'page', 'children': <dynamic>[]},
    });

void main() {
  group('DocumentCache', () {
    test('loads lazily and caches', () async {
      final io = _FakeDocumentIo(
        content: '{"document":{"type":"page","children":[]}}',
      );
      final cache = DocumentCache(io: io);

      final a = await cache.load('doc-1');
      final b = await cache.load('doc-1');

      expect(identical(a, b), isTrue); // second load hits the cache
      expect(io.reads, 1);
    });

    test('debounces rapid saves into a single write', () {
      fakeAsync((async) {
        final io = _FakeDocumentIo(content: '{"document":{"type":"page"}}');
        final cache = DocumentCache(io: io);

        cache.save('doc-1', _doc());
        cache.save('doc-1', _doc());
        cache.save('doc-1', _doc());

        expect(io.writes, isEmpty); // nothing written yet

        async.elapse(DocumentCache.saveDelay);
        expect(io.writes.length, 1); // coalesced into one write
      });
    });

    test('flush writes immediately without waiting for the delay', () {
      fakeAsync((async) {
        final io = _FakeDocumentIo(content: '{"document":{"type":"page"}}');
        final cache = DocumentCache(io: io);

        cache.save('doc-1', _doc());
        cache.flush('doc-1');
        async.flushMicrotasks();

        expect(io.writes.length, 1);
        expect(cache.hasPendingWrites, isFalse);
      });
    });

    test('flushAll drains every pending write', () {
      fakeAsync((async) {
        final io = _FakeDocumentIo(content: '{"document":{"type":"page"}}');
        final cache = DocumentCache(io: io);

        cache.save('a', _doc());
        cache.save('b', _doc());
        cache.flushAll();
        async.flushMicrotasks();

        expect(io.writes.length, 2);
        expect(cache.hasPendingWrites, isFalse);
      });
    });
  });
}

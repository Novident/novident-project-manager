import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/collection_store.dart';

class _FakeCollectionIo implements CollectionIo {
  final Map<String, String> items = <String, String>{};
  int reads = 0;

  @override
  Future<List<String>> listKeys() async => items.keys.toList();

  @override
  Future<String?> readItem(String key) async {
    reads++;
    return items[key];
  }

  @override
  Future<void> writeItem(String key, String json) async => items[key] = json;

  @override
  Future<void> deleteItem(String key) async => items.remove(key);
}

void main() {
  final store = CollectionStore<String>(
    io: _FakeCollectionIo(),
    decode: (String json) => json,
    encode: (String value) => value,
  );

  test('save then load returns the persisted item', () async {
    await store.save('k1', 'hello');
    expect(await store.load('k1'), 'hello');
    expect(await store.listKeys(), <String>['k1']);
  });

  test('load caches: a second read hits memory', () async {
    final io = _FakeCollectionIo()..items['k2'] = 'value';
    final fresh = CollectionStore<String>(
      io: io,
      decode: (String json) => json,
      encode: (String value) => value,
    );
    await fresh.load('k2');
    await fresh.load('k2');
    expect(io.reads, 1);
  });

  test('load throws a clear error for a missing item', () async {
    await expectLater(store.load('missing'), throwsStateError);
  });

  test('delete removes from disk and memory', () async {
    await store.save('k3', 'bye');
    await store.delete('k3');
    expect(await store.listKeys(), isNot(contains('k3')));
    await expectLater(store.load('k3'), throwsStateError);
  });
}

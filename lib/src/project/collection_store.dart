/// I/O for a collection directory: one JSON file per item, keyed by an
/// identifier (an `id` or a date, depending on the collection).
///
/// [listKeys] returns the collection keys (file names without extension). Keys
/// are opaque here; the caller decides how a model maps to its key.
abstract class CollectionIo {
  Future<List<String>> listKeys();
  Future<String?> readItem(String key);
  Future<void> writeItem(String key, String json);
  Future<void> deleteItem(String key);
}

/// Lazy host (not a cache with eviction) of one collection directory.
///
/// Mirrors [FormatStore]'s lifecycle: nothing is loaded eagerly; items are read
/// and decoded on first access and kept in memory for the store's lifetime.
class CollectionStore<T> {
  CollectionStore({
    required this.io,
    required this.decode,
    required this.encode,
  });

  final CollectionIo io;
  final T Function(String json) decode;
  final String Function(T value) encode;
  final Map<String, T> _items = <String, T>{};

  /// Keys of every item in the collection (on disk, uncached).
  Future<List<String>> listKeys() => io.listKeys();

  /// Loads (and decodes) the item for [key] on demand.
  Future<T> load(String key) async {
    final T? cached = _items[key];
    if (cached != null) return cached;

    final String? json = await io.readItem(key);
    if (json == null) throw StateError('item not found: $key');
    final T item = decode(json);
    _items[key] = item;
    return item;
  }

  /// Persists [item] under [key] and updates the in-memory store.
  Future<void> save(String key, T item) async {
    await io.writeItem(key, encode(item));
    _items[key] = item;
  }

  /// Removes the item under [key] from disk and memory.
  Future<void> delete(String key) async {
    await io.deleteItem(key);
    _items.remove(key);
  }

  /// Drops every cached item (does not touch the disk).
  void clear() {
    _items.clear();
  }
}

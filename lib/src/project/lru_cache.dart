import 'dart:collection';

/// A minimal LRU cache backed by a [LinkedHashMap] (insertion order = recency).
///
/// `get` re-inserts the entry at the end (most-recently-used); `put` evicts the
/// least-recently-used entry when over [capacity].
class LruCache<K, V> {
  /// Builds a cache that holds at most [capacity] entries.
  LruCache({required this.capacity}) : assert(capacity > 0);

  /// Maximum number of entries kept before the least recently used is evicted.
  final int capacity;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  /// Returns the value for [key], marking it most-recently-used, or `null`.
  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value;
    }
    return value;
  }

  /// Inserts (or refreshes) [value] under [key], evicting LRU if over capacity.
  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
  }

  /// Whether [key] is present in the cache (without changing recency).
  bool containsKey(K key) => _map.containsKey(key);

  /// Removes and returns the value of [key], or `null` when absent.
  V? remove(K key) => _map.remove(key);

  /// Removes every entry.
  void clear() => _map.clear();

  /// Number of entries currently held.
  int get length => _map.length;

  /// Whether the cache holds no entries.
  bool get isEmpty => _map.isEmpty;
}

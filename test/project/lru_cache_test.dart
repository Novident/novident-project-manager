import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('evicts least-recently-used when over capacity', () {
      final cache = LruCache<String, int>(capacity: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      cache.get('a'); // refresh 'a' recency
      cache.put('c', 3); // evict 'b' (least-recently-used)

      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.length, 2);
    });

    test('get refreshes recency', () {
      final cache = LruCache<String, int>(capacity: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      expect(cache.get('a'), 1);

      cache.put('c', 3);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
    });

    test('put refreshes an existing key without growing', () {
      final cache = LruCache<String, int>(capacity: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('a', 10); // overwrite, not a new entry

      expect(cache.length, 2);
      expect(cache.get('a'), 10);
    });
  });
}

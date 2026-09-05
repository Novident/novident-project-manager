import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/collection_store.dart';
import 'package:novident_project_manager/src/project/session/session.dart';
import 'package:novident_project_manager/src/project/session/session_history.dart';

class _FakeSessionIo implements CollectionIo {
  final Map<String, String> items = <String, String>{};

  @override
  Future<List<String>> listKeys() async => items.keys.toList();

  @override
  Future<String?> readItem(String key) async => items[key];

  @override
  Future<void> writeItem(String key, String json) async => items[key] = json;

  @override
  Future<void> deleteItem(String key) async => items.remove(key);
}

void main() {
  final io = _FakeSessionIo();
  final history = SessionHistory(
    store: CollectionStore<Session>(
      io: io,
      decode: Session.fromJsonString,
      encode: (Session value) => value.toJsonString(),
    ),
  );

  final DateTime fixedNow = DateTime.utc(2026, 7, 20, 18, 30);

  test('openSession creates a fresh session for a new day', () async {
    final session = await history.openSession(
      DateTime.utc(2026, 7, 20),
      author: 'Elena Marlowe',
      now: () => fixedNow,
    );

    expect(session.sessionId, isNotEmpty);
    expect(session.author, 'Elena Marlowe');
    expect(session.sessionDate, '2026-07-20T18:30:00.000Z');
    expect(session.metadata.files, isEmpty);
    expect(session.metadata.total.words, 0);
  });

  test('openSession continues the active session instead of duplicating', () async {
    await history.openSession(
      DateTime.utc(2026, 7, 20),
      author: 'Elena Marlowe',
      now: () => fixedNow,
    );
    final again = await history.openSession(
      DateTime.utc(2026, 7, 20),
      author: 'Elena Marlowe',
      now: () => fixedNow,
    );

    // Only one file for that day.
    expect(io.items.keys, <String>['2026-07-20']);
    expect(again.sessionId, isNotEmpty);
    expect(await history.listDates(), <String>['2026-07-20']);
  });

  test('saveSession persists under the day key derived from the date', () async {
    final session = await history.openSession(
      DateTime.utc(2026, 7, 20),
      author: 'Elena Marlowe',
      now: () => fixedNow,
    );

    final closed = session.copyWith(
      metadata: const SessionMetadata(
        total: SessionTotal(words: 339, characters: 1870),
      ),
    );
    await history.saveSession(closed);

    expect(io.items.containsKey('2026-07-20'), isTrue);
    final stored = Session.fromJsonString(io.items['2026-07-20']!);
    expect(stored.metadata.total.words, 339);
  });

  test('lastSessionDate returns the most recent date', () async {
    await history.openSession(DateTime.utc(2026, 7, 20),
        author: 'A', now: () => fixedNow);
    await history.openSession(DateTime.utc(2026, 7, 22),
        author: 'A', now: () => fixedNow);
    expect(await history.lastSessionDate(), '2026-07-22');
    expect(await history.hasSessionOn(DateTime.utc(2026, 7, 22)), isTrue);
    expect(await history.hasSessionOn(DateTime.utc(2026, 7, 23)), isFalse);
  });
}

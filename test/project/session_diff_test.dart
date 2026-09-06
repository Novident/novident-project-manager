import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/session/session.dart';
import 'package:novident_project_manager/src/project/session/session_diff.dart';

Session _session(
  String date,
  int words,
  int characters, {
  Map<String, (int, int)> files = const {},
}) {
  final fileCounters = files.map(
      (String id, (int, int) counts) => MapEntry<String, SessionFileCounters>(
            id,
            SessionFileCounters(
                originalWords: 0,
                originalCharacters: 0,
                words: counts.$1,
                characters: counts.$2),
          ));
  return Session(
    schemaVersion: 1,
    sessionId: 's-$date',
    sessionDate: date,
    author: 'Elena Marlowe',
    metadata: SessionMetadata(
      files: fileCounters,
      total: SessionTotal(
        typeTarget: 'nanowrimo',
        words: words,
        characters: characters,
        target: 50000,
        targetCharacters: 275000,
      ),
    ),
  );
}

void main() {
  // Fixture values from example.nov history files (2026-07-20 vs 22).
  final july20 = _session('2026-07-20T18:30:00Z', 339, 1870);
  final july22 = _session('2026-07-22T20:15:00Z', 244, 1345);

  test('diffSessions computes totals deltas', () {
    final diff = diffSessions(july20, july22);

    expect(diff.fromSessionDate, '2026-07-20T18:30:00Z');
    expect(diff.toSessionDate, '2026-07-22T20:15:00Z');
    // No shared nodes between the two fixture days.
    expect(diff.files, isEmpty);
    expect(diff.words, 244 - 339);
    expect(diff.characters, 1345 - 1870);
  });

  test('diffSessions reports per-file deltas for shared nodes', () {
    final before = _session(
      '2026-07-01T10:00:00Z',
      100,
      600,
      files: const <String, (int, int)>{
        'nodeA': (40, 220),
        'nodeB': (60, 380),
      },
    );
    final after = _session(
      '2026-07-02T10:00:00Z',
      150,
      900,
      files: const <String, (int, int)>{
        'nodeA': (70, 400),
        'nodeB': (60, 380),
        'nodeC': (20, 120),
      },
    );

    final diff = diffSessions(before, after);

    // nodeA grew, nodeB unchanged, nodeC (new) is ignored (not in both).
    expect(diff.files.map((f) => f.nodeId), <String>['nodeA', 'nodeB']);
    expect(diff.files.firstWhere((f) => f.nodeId == 'nodeA').addedWords, 30);
    expect(diff.files.firstWhere((f) => f.nodeId == 'nodeB').addedWords, 0);
    expect(diff.words, 50);

    expect(diff.grownFiles.map((f) => f.nodeId), <String>['nodeA']);
    expect(diff.shrunkFiles, isEmpty);
  });

  test('diffSessions reports shrink as a negative delta', () {
    final before = _session(
      '2026-07-01T10:00:00Z',
      100,
      600,
      files: const <String, (int, int)>{'nodeA': (90, 540)},
    );
    final after = _session(
      '2026-07-02T10:00:00Z',
      60,
      360,
      files: const <String, (int, int)>{'nodeA': (50, 300)},
    );

    final diff = diffSessions(before, after);
    expect(diff.files.single.addedWords, -40);
    expect(diff.shrunkFiles.map((f) => f.nodeId), <String>['nodeA']);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/session/session.dart';
import 'package:novident_project_manager/src/project/session/session_adjust.dart';

Session _baseSession() {
  return Session(
    schemaVersion: 1,
    sessionId: 's1',
    sessionDate: '2026-07-20T18:30:00Z',
    author: 'Elena',
    metadata: SessionMetadata(
      files: const <String, SessionFileCounters>{
        'nodeA': SessionFileCounters(
          originalWords: 150,
          originalCharacters: 825,
          words: 187,
          characters: 1030,
        ),
      },
      total: const SessionTotal(
        typeTarget: 'nanowrimo',
        words: 187,
        characters: 1030,
        target: 50000,
        targetCharacters: 275000,
      ),
    ),
  );
}

void main() {
  test('adjustSession increases totals and file counters', () {
    final Session adjusted = adjustSession(
      _baseSession(),
      nodeId: 'nodeA',
      adjustment: const CountAdjustment(
        words: 13,
        characters: 75,
      ),
    );

    final SessionFileCounters file = adjusted.metadata.files['nodeA']!;
    expect(file.originalWords, 150); // untouched
    expect(file.words, 200);
    expect(file.characters, 1105);

    expect(adjusted.metadata.total.words, 200);
    expect(adjusted.metadata.total.characters, 1105);
    expect(
      adjusted.metadata.total.distanceFromTargetWords,
      (200 / 50000).clamp(0, 1),
    );
  });

  test('adjustSession can decrease without going below zero', () {
    final Session adjusted = adjustSession(
      _baseSession(),
      nodeId: 'nodeA',
      adjustment: const CountAdjustment(
        words: -50,
        characters: -200,
      ),
    );

    expect(adjusted.metadata.total.words, 137);
    expect(adjusted.metadata.files['nodeA']!.words, 137);
  });

  test('an empty adjustment is a no-op', () {
    final Session base = _baseSession();
    final Session adjusted =
        adjustSession(base, adjustment: CountAdjustment.zero);

    expect(adjusted.metadata.total.words, base.metadata.total.words);
    expect(
      adjusted.metadata.total.characters,
      base.metadata.total.characters,
    );
    expect(adjusted.metadata.files['nodeA']!.words, 187);
    expect(adjusted.metadata.files['nodeA']!.originalWords, 150);
  });

  test('no target keeps distance at zero', () {
    final Session base = _baseSession().copyWith(
      metadata: const SessionMetadata(total: SessionTotal(words: 10)),
    );
    final Session adjusted = adjustSession(
      base,
      adjustment: const CountAdjustment(words: 5),
    );

    expect(adjusted.metadata.total.words, 15);
    expect(adjusted.metadata.total.distanceFromTargetWords, 0);
  });
}

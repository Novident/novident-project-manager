import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/session/session.dart';
import 'package:novident_project_manager/src/project/session/session_builder.dart';

void main() {
  const originals = <String, SessionFileCounters>{
    'nodeA': SessionFileCounters(
      originalWords: 0,
      originalCharacters: 0,
      words: 150,
      characters: 825,
    ),
  };

  test('buildSessionSummary aggregates files and totals', () {
    final SessionSummary summary = buildSessionSummary(
      originals: originals,
      current: const <String, SessionNodeMeasures>{
        'nodeA': SessionNodeMeasures(
          words: 187,
          characters: 1030,
        ),
      },
      target: 50000,
      targetCharacters: 275000,
      typeTarget: 'nanowrimo',
    );

    // Node A: started at 150 words (previous session end), closed at 187.
    final SessionFileCounters file = summary.files['nodeA']!;
    expect(file.originalWords, 150);
    expect(file.originalCharacters, 825);
    expect(file.words, 187);
    expect(file.characters, 1030);

    expect(summary.total.typeTarget, 'nanowrimo');
    expect(summary.total.words, 187);
    expect(summary.total.characters, 1030);
    expect(summary.total.target, 50000);
    // 187/50000, clamped to [0,1].
    expect(summary.total.distanceFromTargetWords, 187 / 50000);
  });

  test('nodes without an original start at zero', () {
    final SessionSummary summary = buildSessionSummary(
      originals: originals,
      current: const <String, SessionNodeMeasures>{
        'nodeB': SessionNodeMeasures(
          words: 10,
          characters: 55,
        ),
      },
      target: 1000,
      targetCharacters: 5000,
    );

    expect(summary.files['nodeB']!.originalWords, 0);
    expect(summary.total.words, 10);
    expect(summary.files.containsKey('nodeA'), isFalse);
  });

  test('distance is clamped to 1 when the target is exceeded', () {
    final SessionSummary summary = buildSessionSummary(
      originals: const <String, SessionFileCounters>{},
      current: const <String, SessionNodeMeasures>{
        'nodeA': SessionNodeMeasures(
          words: 120,
          characters: 600,
        ),
      },
      target: 100,
      targetCharacters: 1000,
    );

    expect(summary.total.distanceFromTargetWords, 1.0);
    expect(summary.total.distanceFromTargetCharacters, 0.6);
  });

  test('no target yields zero distance', () {
    final SessionSummary summary = buildSessionSummary(
      originals: const <String, SessionFileCounters>{},
      current: const <String, SessionNodeMeasures>{},
      target: 0,
      targetCharacters: 0,
    );
    expect(summary.files, isEmpty);
    expect(summary.total.words, 0);
    expect(summary.total.distanceFromTargetWords, 0);
  });
}

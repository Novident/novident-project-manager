import 'package:novident_project_manager/src/project/session/session.dart';

/// A manual, incremental count adjustment.
///
/// External counting services (outside the editor) can report how a batch of
/// edits changed a document without re-counting everything: they only hand the
/// deltas. Negative values decrease the counters; nothing ever goes below zero.
class CountAdjustment {
  const CountAdjustment({
    this.words = 0,
    this.characters = 0,
  });

  final int words;
  final int characters;

  bool get isEmpty => words == 0 && characters == 0;

  static const CountAdjustment zero = CountAdjustment();

  CountAdjustment operator +(CountAdjustment other) => CountAdjustment(
        words: words + other.words,
        characters: characters + other.characters,
      );
}

int _atLeastZero(int value) => value < 0 ? 0 : value;

double _progress(int current, int target) =>
    target > 0 ? (current / target).clamp(0, 1) : 0;

/// Returns [total] with the [adjustment] applied and its distance-to-target
/// recomputed (never negative, progress clamped to 0.0–1.0).
SessionTotal adjustSessionTotal(
    SessionTotal total, CountAdjustment adjustment) {
  final int words = _atLeastZero(total.words + adjustment.words);
  final int characters = _atLeastZero(total.characters + adjustment.characters);
  return SessionTotal(
    typeTarget: total.typeTarget,
    words: words,
    characters: characters,
    distanceFromTargetWords: _progress(words, total.target),
    distanceFromTargetCharacters: _progress(characters, total.targetCharacters),
    target: total.target,
    targetCharacters: total.targetCharacters,
  );
}

/// Returns a copy of [session] with an incremental [adjustment] applied.
///
/// When [nodeId] is given the node's file counters are adjusted too (words and
/// characters only — per-file history has no no-spaces column), keeping its
/// `original_*` (session start) values untouched. Totals are always adjusted.
Session adjustSession(
  Session session, {
  String? nodeId,
  required CountAdjustment adjustment,
}) {
  SessionTotal total = adjustSessionTotal(session.metadata.total, adjustment);

  Map<String, SessionFileCounters> files = session.metadata.files;
  if (nodeId != null) {
    final SessionFileCounters? current = files[nodeId];
    final SessionFileCounters updated = SessionFileCounters(
      originalWords: current?.originalWords ?? 0,
      originalCharacters: current?.originalCharacters ?? 0,
      words: _atLeastZero((current?.words ?? 0) + adjustment.words),
      characters:
          _atLeastZero((current?.characters ?? 0) + adjustment.characters),
    );
    files = <String, SessionFileCounters>{...files, nodeId: updated};
  }

  return session.copyWith(
    metadata: SessionMetadata(files: files, total: total),
  );
}

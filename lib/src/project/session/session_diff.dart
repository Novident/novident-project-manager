import 'package:novident_project_manager/src/project/session/session.dart';

/// Per-file counters delta between two sessions.
class SessionFileDelta {
  const SessionFileDelta({
    required this.nodeId,
    required this.addedWords,
    required this.addedCharacters,
  });

  final String nodeId;
  final int addedWords;
  final int addedCharacters;
}

/// Difference between two history sessions.
///
/// `from` is the earlier session and `to` the later one; positive deltas mean
/// the writer gained words/characters in between (a negative delta means text
/// was removed). Deltas compare the **end** counters of each session.
class SessionDiff {
  const SessionDiff({
    required this.fromSessionDate,
    required this.toSessionDate,
    required this.files,
    required this.words,
    required this.characters,
  });

  final String fromSessionDate;
  final String toSessionDate;

  /// Per-file deltas, only for nodes that were active in both sessions.
  final List<SessionFileDelta> files;

  final int words;
  final int characters;

  /// Nodes that gained words between the two sessions.
  List<SessionFileDelta> get grownFiles =>
      files.where((SessionFileDelta f) => f.addedWords > 0).toList();

  /// Nodes that lost words between the two sessions.
  List<SessionFileDelta> get shrunkFiles =>
      files.where((SessionFileDelta f) => f.addedWords < 0).toList();
}

/// Compares two sessions ([from] earlier, [to] later) and returns the delta.
SessionDiff diffSessions(Session from, Session to) {
  final List<SessionFileDelta> files = <SessionFileDelta>[];

  for (final MapEntry<String, SessionFileCounters> entry
      in from.metadata.files.entries) {
    final SessionFileCounters? later = to.metadata.files[entry.key];
    if (later == null) continue; // node was not active in the later session
    files.add(SessionFileDelta(
      nodeId: entry.key,
      addedWords: later.words - entry.value.words,
      addedCharacters: later.characters - entry.value.characters,
    ));
  }

  return SessionDiff(
    fromSessionDate: from.sessionDate,
    toSessionDate: to.sessionDate,
    files: files,
    words: to.metadata.total.words - from.metadata.total.words,
    characters: to.metadata.total.characters - from.metadata.total.characters,
  );
}

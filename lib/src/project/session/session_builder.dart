import 'package:novident_project_manager/src/project/session/session.dart';

/// Live word/character measures of one node when a session closes.
///
/// [noSpaces] feeds the session *total* `characters_no_spaces`; per-file
/// history entries only carry words/characters.
class SessionNodeMeasures {
  const SessionNodeMeasures({
    required this.words,
    required this.characters,
    required this.noSpaces,
  });

  final int words;
  final int characters;
  final int noSpaces;

  const SessionNodeMeasures.zero()
      : words = 0,
        characters = 0,
        noSpaces = 0;
}

/// The per-file counters + totals produced when a session ends.
class SessionSummary {
  const SessionSummary({required this.files, required this.total});

  final Map<String, SessionFileCounters> files;
  final SessionTotal total;
}

/// Builds the closing data of a writing session.
///
/// `originals` are the counters each node had when the session started (the
/// previous session's end for that node); `current` holds the live measures at
/// close time. Totals aggregate every current file and measure progress against
/// the writing target (`words/target`, 0.0–1.0).
SessionSummary buildSessionSummary({
  required Map<String, SessionFileCounters> originals,
  required Map<String, SessionNodeMeasures> current,
  required int target,
  required int targetCharacters,
  String typeTarget = '',
}) {
  final Map<String, SessionFileCounters> files = <String, SessionFileCounters>{};

  int words = 0;
  int characters = 0;
  int noSpaces = 0;

  for (final MapEntry<String, SessionNodeMeasures> entry in current.entries) {
    final SessionFileCounters? original = originals[entry.key];
    files[entry.key] = SessionFileCounters(
      originalWords: original?.words ?? 0,
      originalCharacters: original?.characters ?? 0,
      words: entry.value.words,
      characters: entry.value.characters,
    );
    words += entry.value.words;
    characters += entry.value.characters;
    noSpaces += entry.value.noSpaces;
  }

  final double distance = target > 0 ? (words / target) : 0;
  final double distanceCharacters =
      targetCharacters > 0 ? (characters / targetCharacters) : 0;

  return SessionSummary(
    files: files,
    total: SessionTotal(
      typeTarget: typeTarget,
      words: words,
      characters: characters,
      charactersNoSpaces: noSpaces,
      distanceFromTargetWords: distance.clamp(0, 1),
      distanceFromTargetCharacters: distanceCharacters.clamp(0, 1),
      target: target,
      targetCharacters: targetCharacters,
    ),
  );
}

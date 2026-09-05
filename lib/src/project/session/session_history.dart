import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_project_manager/src/project/collection_store.dart';
import 'package:novident_project_manager/src/project/session/session.dart';

/// Session (history) file naming: one file per UTC day, `yyyy-MM-dd`.
String sessionDateKey(DateTime day) {
  final String y = day.year.toString().padLeft(4, '0');
  final String m = day.month.toString().padLeft(2, '0');
  final String d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Opens the current writing session, continuing it when one is still active.
///
/// A history file is a *day* of writing. Creating two files for the same day
/// would split a single session, so the guard never creates a new session while
/// the current day's session already exists — it returns the stored one.
///
/// The caller decides when a session is complete; closing (writing the final
/// per-file counters) is just [SessionHistory.saveSession].
class SessionHistory {
  SessionHistory({required this.store});

  /// Underlying session collection (engine-backed in production).
  final CollectionStore<Session> store;

  /// Dates (keys) of every stored session, in ascending order.
  Future<List<String>> listDates() async {
    final List<String> keys = await store.listKeys();
    keys.sort();
    return keys;
  }

  /// The most recent session date, or `null` when there is no history yet.
  Future<String?> lastSessionDate() async {
    final List<String> dates = await listDates();
    return dates.isEmpty ? null : dates.last;
  }

  /// Whether a session already exists for [day].
  Future<bool> hasSessionOn(DateTime day) async {
    final List<String> dates = await listDates();
    return dates.contains(sessionDateKey(day));
  }

  /// Opens the session for [day]: returns the existing one when present, or
  /// creates (and persists) a fresh one with empty counters.
  ///
  /// This is the guard against duplicate active sessions: call it once when
  /// the app starts writing, and keep returning its result until the day ends.
  Future<Session> openSession(
    DateTime day, {
    required String author,
    DateTime Function()? now,
  }) async {
    final String key = sessionDateKey(day);
    final List<String> dates = await listDates();
    if (dates.contains(key)) {
      return store.load(key);
    }
    final Session session = Session(
      schemaVersion: 1,
      sessionId: NodeDetails.createNodeId(),
      sessionDate: (now ?? DateTime.now).call().toUtc().toIso8601String(),
      author: author,
      metadata: const SessionMetadata(),
    );
    await store.save(key, session);
    return session;
  }

  /// Persists an updated session (final counters) under its day key.
  Future<void> saveSession(Session session) async {
    final DateTime? date = DateTime.tryParse(session.sessionDate);
    await store.save(
      date == null ? session.sessionDate : sessionDateKey(date.toUtc()),
      session,
    );
  }
}

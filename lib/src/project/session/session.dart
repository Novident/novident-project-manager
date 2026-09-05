// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import '../../schema/registry.dart';

/// A writing session (`history/<date>.json`).
class Session {
  final int? schemaVersion;
  final String sessionId;
  final String sessionDate;
  final String author;
  final SessionMetadata metadata;

  const Session({
    this.schemaVersion = kCurrentSchemaVersion,
    this.sessionId = '',
    this.sessionDate = '',
    this.author = '',
    this.metadata = const SessionMetadata(),
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        schemaVersion: json['schema_version'] as int?,
        sessionId: json['session_id'] as String? ?? '',
        sessionDate: json['session_date'] as String? ?? '',
        author: json['author'] as String? ?? '',
        metadata: SessionMetadata.fromJson(
            json['metadata'] as Map<String, dynamic>? ?? const {}),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (schemaVersion != null) 'schema_version': schemaVersion,
        'session_id': sessionId,
        'session_date': sessionDate,
        'author': author,
        'metadata': metadata.toJson(),
      };

  String toJsonString() => json.encode(toJson());

  factory Session.fromJsonString(String source) =>
      Session.fromJson(json.decode(source) as Map<String, dynamic>);

  Session copyWith({SessionMetadata? metadata}) {
    return Session(
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      sessionDate: sessionDate,
      author: author,
      metadata: metadata ?? this.metadata,
    );
  }
}

class SessionMetadata {
  final Map<String, SessionFileCounters> files;
  final SessionTotal total;

  const SessionMetadata({
    this.files = const <String, SessionFileCounters>{},
    this.total = const SessionTotal(),
  });

  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    return SessionMetadata(
      files: rawFiles is Map<String, dynamic>
          ? rawFiles.map((String id, dynamic value) => MapEntry(id,
              SessionFileCounters.fromJson(value as Map<String, dynamic>)))
          : const <String, SessionFileCounters>{},
      total: SessionTotal.fromJson(
          json['total'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'files': files.map((String id, SessionFileCounters counters) =>
            MapEntry(id, counters.toJson())),
        'total': total.toJson(),
      };
}

/// Counters for one node: originals are the values at session start, the
/// unprefixed fields are the values at session end.
class SessionFileCounters {
  final int originalWords;
  final int originalCharacters;
  final int words;
  final int characters;

  const SessionFileCounters({
    this.originalWords = 0,
    this.originalCharacters = 0,
    this.words = 0,
    this.characters = 0,
  });

  factory SessionFileCounters.fromJson(Map<String, dynamic> json) =>
      SessionFileCounters(
        originalWords: json['original_words'] as int? ?? 0,
        originalCharacters: json['original_characters'] as int? ?? 0,
        words: json['words'] as int? ?? 0,
        characters: json['characters'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'original_words': originalWords,
        'original_characters': originalCharacters,
        'words': words,
        'characters': characters,
      };
}

class SessionTotal {
  final String typeTarget;
  final int words;
  final int characters;
  final double distanceFromTargetWords;
  final double distanceFromTargetCharacters;
  final int target;
  final int targetCharacters;

  const SessionTotal({
    this.typeTarget = '',
    this.words = 0,
    this.characters = 0,
    this.distanceFromTargetWords = 0,
    this.distanceFromTargetCharacters = 0,
    this.target = 0,
    this.targetCharacters = 0,
  });

  factory SessionTotal.fromJson(Map<String, dynamic> json) => SessionTotal(
        typeTarget: json['type_target'] as String? ?? '',
        words: json['words'] as int? ?? 0,
        characters: json['characters'] as int? ?? 0,
        distanceFromTargetWords:
            (json['distance_from_target_words'] as num?)?.toDouble() ?? 0,
        distanceFromTargetCharacters:
            (json['distance_from_target_characters'] as num?)?.toDouble() ?? 0,
        target: json['target'] as int? ?? 0,
        targetCharacters: json['target_characters'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type_target': typeTarget,
        'words': words,
        'characters': characters,
        'distance_from_target_words': distanceFromTargetWords,
        'distance_from_target_characters': distanceFromTargetCharacters,
        'target': target,
        'target_characters': targetCharacters,
      };
}

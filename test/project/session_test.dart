import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/session/session.dart';

void main() {
  final Map<String, dynamic> fixture = jsonDecode('''
{
  "schema_version": 1,
  "session_id": "3f8e2a1b-9c4d-5678-abcd-ef0123456789",
  "session_date": "2026-07-20T18:30:00Z",
  "author": "Elena Marlowe",
  "metadata": {
    "files": {
      "d4e5f6a7-b8c9-0123-defa-234567890123": {
        "original_words": 150,
        "original_characters": 825,
        "words": 187,
        "characters": 1030
      }
    },
    "total": {
      "type_target": "nanowrimo",
      "words": 339,
      "characters": 1870,
      "distance_from_target_words": 0.1,
      "distance_from_target_characters": 0.1,
      "target": 50000,
      "target_characters": 275000
    }
  }
}
''') as Map<String, dynamic>;

  test('Session roundtrips the real fixture shape', () {
    final decoded = Session.fromJson(fixture);
    expect(json.decode(decoded.toJsonString()), fixture);
  });

  test('Session reads nested values', () {
    final session = Session.fromJson(fixture);

    expect(session.schemaVersion, 1);
    expect(session.sessionId, '3f8e2a1b-9c4d-5678-abcd-ef0123456789');
    expect(session.author, 'Elena Marlowe');

    final counters =
        session.metadata.files['d4e5f6a7-b8c9-0123-defa-234567890123']!;
    expect(counters.originalWords, 150);
    expect(counters.words, 187);

    final total = session.metadata.total;
    expect(total.distanceFromTargetWords, 0.1);
    expect(total.target, 50000);
  });

  test('Session.fromJson tolerates missing fields', () {
    final session = Session.fromJson(const <String, dynamic>{});
    expect(session.sessionId, '');
    expect(session.metadata.files, isEmpty);
    expect(session.metadata.total.words, 0);
  });
}

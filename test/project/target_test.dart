import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/target/target.dart';

void main() {
  final Map<String, dynamic> fixture = jsonDecode('''
{
  "schema_version": 1,
  "general": {
    "type_target": "nanowrimo",
    "target": 50000,
    "target_characters": 275000,
    "deadline": "2026-11-30T23:59:59Z",
    "genre": "Fantasy",
    "subgenre": "High Fantasy / Coming of Age",
    "audience": "Young Adult to Adult crossover",
    "target_word_count": 90000,
    "current_word_count": 970,
    "language": "en-US"
  },
  "files": {
    "b2c3d4e5-f6a7-8901-bcde-f12345678901": {
      "notify": true,
      "deadline": "2026-09-30T23:59:59Z",
      "words": 50000,
      "characters": 275000
    }
  }
}
''') as Map<String, dynamic>;

  test('TargetIndex roundtrips the real fixture shape', () {
    final decoded = TargetIndex.fromJson(fixture);
    expect(json.decode(decoded.toJsonString()), fixture);
  });

  test('TargetIndex reads nested values', () {
    final target = TargetIndex.fromJson(fixture);

    expect(target.schemaVersion, 1);
    expect(target.general.typeTarget, 'nanowrimo');
    expect(target.general.target, 50000);
    expect(target.general.deadline, '2026-11-30T23:59:59Z');

    final file = target.files['b2c3d4e5-f6a7-8901-bcde-f12345678901'];
    expect(file, isNotNull);
    expect(file!.notify, isTrue);
    expect(file.words, 50000);
    expect(file.characters, 275000);
  });

  test('TargetFile keeps the hyphenated characters_no_spaces key', () {
    final target = TargetIndex.fromJson(fixture);
    final files =
        (json.decode(target.toJsonString()) as Map<String, dynamic>)['files']
            as Map<String, dynamic>;
    final file = files.values.single as Map<String, dynamic>;
    expect(file.containsKey('characters_no_spaces'), isTrue);
    expect(file.containsKey('charactersNoSpaces'), isFalse);
  });

  test('TargetIndex.fromJson tolerates missing fields', () {
    final target = TargetIndex.fromJson(const <String, dynamic>{});
    expect(target.schemaVersion, isNull);
    expect(target.general.target, 0);
    expect(target.general.typeTarget, '');
    expect(target.files, isEmpty);
  });

  test('TargetFile omits optional keys when absent', () {
    final file = const TargetFile(words: 100, characters: 500).toJson();
    expect(file.containsKey('deadline'), isFalse);
    expect(file.containsKey('characters_no_spaces'), isFalse);
    expect(file['words'], 100);
  });
}

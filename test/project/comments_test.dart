import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/comments/comments.dart';

void main() {
  final Map<String, dynamic> fixture = jsonDecode('''
{
  "12db1nf-Roman": {
    "path": [2],
    "date": "12/20/2015",
    "content": "Very well-structured magic system."
  },
  "ab34cd2": {
    "path": [0, 3],
    "date": "12/21/2015",
    "content": "No username suffix."
  }
}
''') as Map<String, dynamic>;

  test('Comments roundtrips keys with and without username suffix', () {
    final decoded = Comments.fromJson(fixture);
    expect(json.decode(decoded.toJsonString()), fixture);
  });

  test('Comments reads comments keyed by <id>[-<username>]', () {
    final comments = Comments.fromJson(fixture);

    expect(comments.comments.length, 2);

    final roman = comments.comments['12db1nf-Roman']!;
    expect(roman.path, <int>[2]);
    expect(roman.date, '12/20/2015');
    expect(roman.content, 'Very well-structured magic system.');

    final bare = comments.comments['ab34cd2']!;
    expect(bare.path, <int>[0, 3]);
  });

  test('Comments.fromJson ignores non-object values', () {
    final comments = Comments.fromJson(const <String, dynamic>{
      'garbage': 'not a comment',
      'ok': <String, dynamic>{
        'path': <int>[1],
        'date': '',
        'content': ''
      },
    });
    expect(comments.comments.length, 1);
    expect(comments.comments.containsKey('garbage'), isFalse);
  });

  test('Comments.fromJson tolerates missing fields', () {
    final comments = Comments.fromJson(const <String, dynamic>{});
    expect(comments.comments, isEmpty);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/author/author.dart';
import 'package:novident_project_manager/src/project/project_configurations.dart';

Map<String, dynamic> _fullMetadata() => <String, dynamic>{
      'schema_version': 1,
      'project': <String, dynamic>{
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'name': 'The Crystal Labyrinth',
        'version': 1,
        'revisions': <String>[],
        'synopsis': '',
        'path': 'The Crystal Labyrinth.nov',
        'language': 'en-US',
        'background': '#f4f1ea',
        'cover': null,
        'created_at': '2026-07-15T09:00:00Z',
        'updated_at': '2026-07-23T14:30:00Z',
      },
      'author': <String, dynamic>{
        'name': 'Elena Marlowe',
        'email': 'e@x.com',
        'state_and_country': 'US',
        'street': '',
        'city': '',
        'zip_and_post_code': '',
        'phone_number': '',
        'website': 'https://example.com',
      },
      'book': <String, dynamic>{
        'title': 'The Crystal Labyrinth',
        'abbreviated_title': 'Crystal Labyrinth',
        'isbn': '978-0-000-00000-0',
        'subject': 'Fantasy',
        'company': '',
        'copyright': '© 2026 Elena Marlowe',
        'keywords': 'fantasy, labyrinth',
        'comments': '',
      },
      'compile_defaults': <String, dynamic>{
        'default_format_id': 'f1e2d3c4',
        'default_output': 'pdf',
        'include_synopsis': false,
        'include_notes': false,
        'include_comments': false,
      },
      'editor_preferences': <String, dynamic>{
        'binder': true,
        'inspector': true,
        'base_style_ref': 'kBaseStyle',
        'page_width': 750,
        'theme': 'novident_light',
      },
      'session': <String, dynamic>{
        'last_opened_document': 'd4e5f6a7',
        'last_opened_at': '2026-07-23T14:30:00Z',
        'binder_expanded_nodes': <String>['a', 'b'],
        'active_view': 'tree',
        'split_ratio': 0.3,
        'corkboard_visible': false,
      },
      'statistics': <String, dynamic>{
        'total_documents': 7,
        'total_folders': 8,
        'total_external_files': 5,
        'total_word_count': 970,
        'manuscript_word_count': 514,
        'research_word_count': 344,
        'trash_word_count': 112,
      },
    };

void main() {
  group('Metadata codec', () {
    test('full metadata.json roundtrips', () {
      final metadata = Metadata.fromJson(_fullMetadata());
      final roundtripped = Metadata.fromJson(metadata.toJson());

      expect(roundtripped, metadata);
    });

    test('jsonEncode/jsonDecode roundtrip preserves data', () {
      final metadata = Metadata.fromJson(_fullMetadata());
      final decoded = jsonDecode(jsonEncode(metadata.toJson()))
          as Map<String, dynamic>;

      expect(Metadata.fromJson(decoded), metadata);
    });

    test('empty/partial metadata defaults to empty blocks', () {
      final metadata = Metadata.fromJson(const <String, dynamic>{});

      expect(metadata.schemaVersion, isNull);
      expect(metadata.project.name, '');
      expect(metadata.author.name, '');
      expect(metadata.author.website, '');
      expect(metadata.book.title, '');
      expect(metadata.book.abbreviatedTitle, '');
      expect(metadata.compileDefaults.defaultFormatId, '');
      expect(metadata.editorPreferences.pageWidth, 0);
      expect(metadata.session.splitRatio, 0.0);
      expect(metadata.statistics.totalWordCount, 0);
    });

    test('book block roundtrips with abbreviated_title and isbn', () {
      const book = Book(
        title: 'Title',
        abbreviatedTitle: 'Abbr',
        isbn: '978-0-000-00000-0',
        subject: 'Fantasy',
      );

      final roundtripped = Book.fromJson(book.toJson());

      expect(roundtripped, book);
      expect(roundtripped.abbreviatedTitle, 'Abbr');
      expect(roundtripped.isbn, '978-0-000-00000-0');
    });

    test('author website roundtrips and is tolerant', () {
      final author = Author.fromMap(<String, dynamic>{
        'name': 'Elena',
        'email': 'e@x.com',
        'website': 'https://example.com',
      });

      expect(author.website, 'https://example.com');
      expect(author.stateAndCountry, ''); // missing → default
      expect(Author.fromMap(author.toMap()).website, 'https://example.com');
    });
  });
}

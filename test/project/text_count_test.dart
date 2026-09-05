import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart'
    as editor;
import 'package:novident_project_manager/src/project/content/text_count.dart';

int _runes(String text) => text.runes.length;

int _runesNoSpaces(String text) => text.runes
    .where((int r) => String.fromCharCode(r).trim().isNotEmpty)
    .length;

editor.Document _documentOf(String text) {
  // One paragraph whose delta holds the whole text (newlines included).
  return editor.Document.fromJson(<String, dynamic>{
    'document': <String, dynamic>{
      'type': 'page',
      'children': <dynamic>[
        <String, dynamic>{
          'type': 'paragraph',
          'data': <String, dynamic>{
            'delta': <dynamic>[
              <String, dynamic>{'insert': text},
            ],
          },
        },
      ],
    },
  });
}

void main() {
  test('countText counts words as non-whitespace runs', () {
    const String text = 'The Awakening\n\nKira opened her eyes.';

    final TextCount count = countText(text);

    expect(count.words, 6);
    expect(count.characters, _runes(text));
    expect(count.charactersNoSpaces, _runesNoSpaces(text));
  });

  test('countText handles accents and unicode (runes)', () {
    const String text = 'Café corazón — 日本語';

    final TextCount count = countText(text);

    expect(count.words, 4); // Café, corazón, —, 日本語 (— is its own \S+ token)
    expect(count.characters, _runes(text));
    expect(count.charactersNoSpaces, _runesNoSpaces(text));
  });

  test('countEditorDocument counts the plain text of the whole tree', () {
    final String text = 'Title text\nFirst bullet\n';
    final editor.Document document = _documentOf(text);

    final TextCount count = countEditorDocument(document);

    expect(count.words, 4); // Title, text, First, bullet
    expect(count.characters, _runes(text));
    expect(count.charactersNoSpaces, _runesNoSpaces(text));
  });

  test('countEditorDocument counts text spread over several blocks', () {
    final editor.Document document = editor.Document.fromJson(<String, dynamic>{
      'document': <String, dynamic>{
        'type': 'page',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'paragraph',
            'data': <String, dynamic>{
              'delta': <dynamic>[
                <String, dynamic>{'insert': 'Chapter one'},
                <String, dynamic>{'insert': '\n'},
              ],
            },
          },
          <String, dynamic>{
            'type': 'paragraph',
            'data': <String, dynamic>{
              'delta': <dynamic>[
                <String, dynamic>{'insert': 'Second paragraph words'},
              ],
            },
          },
        ],
      },
    });

    final String text = 'Chapter one\nSecond paragraph words';
    final TextCount count = countEditorDocument(document);

    expect(count.words, 5);
    expect(count.characters, _runes(text));
    expect(count.charactersNoSpaces, _runesNoSpaces(text));
  });

  test('an empty page yields zero counts', () {
    final editor.Document document = editor.Document.fromJson(<String, dynamic>{
      'document': <String, dynamic>{
        'type': 'page',
        'children': <dynamic>[],
      },
    });
    final TextCount count = countEditorDocument(document);

    expect(count.words, 0);
    expect(count.characters, 0);
    expect(count.charactersNoSpaces, 0);
  });
}

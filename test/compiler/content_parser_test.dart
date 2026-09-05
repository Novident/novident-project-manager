import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_project_manager/src/ast/ast.dart';
import 'package:novident_project_manager/src/compiler/content_parser.dart';

void main() {
  test('parses heading, nested list, image and paragraph structurally', () {
    final Document document = Document.fromJson(const <String, dynamic>{
      'document': <String, dynamic>{
        'type': 'page',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'heading',
            'data': <String, dynamic>{
              'delta': <dynamic>[
                <String, dynamic>{'insert': 'Chapter'}
              ],
              'level': 1,
            },
          },
          <String, dynamic>{
            'type': 'bulleted_list',
            'data': <String, dynamic>{
              'delta': <dynamic>[
                <String, dynamic>{'insert': 'Parent'}
              ],
            },
            'children': <dynamic>[
              <String, dynamic>{
                'type': 'bulleted_list',
                'data': <String, dynamic>{
                  'delta': <dynamic>[
                    <String, dynamic>{'insert': 'Child'}
                  ],
                },
              },
            ],
          },
          <String, dynamic>{
            'type': 'image',
            'data': <String, dynamic>{
              'url': 'https://example.com/a.png',
              'align': 'center',
            },
          },
          <String, dynamic>{
            'type': 'paragraph',
            'data': <String, dynamic>{
              'delta': <dynamic>[
                <String, dynamic>{'insert': 'Done'}
              ],
            },
          },
        ],
      },
    });

    final List<Content> contents = ContentParser.parseDocument(document);

    // heading → Paragraph with level in metadata
    expect(contents.length, 4);
    final Paragraph heading = contents[0] as Paragraph;
    expect(heading.metadata['block_type'], 'heading');
    expect(
        (heading.metadata['attributes'] as Map<String, dynamic>)['level'], 1);

    // bulleted list → ListItem that keeps the nested child inside its value
    final ListItem parent = contents[1] as ListItem;
    final Map<String, dynamic> listMeta =
        parent.metadata['list'] as Map<String, dynamic>;
    expect(listMeta['kind'], 'bulleted');
    expect(parent.value.first, isA<Paragraph>());
    expect(parent.value.last, isA<ListItem>());

    // image → AST Image
    final Image image = contents[2] as Image;
    expect(image.value, 'https://example.com/a.png');
    expect((image.metadata['attributes'] as Map<String, dynamic>)['align'],
        'center');

    // plain paragraph
    final Paragraph paragraph = contents[3] as Paragraph;
    expect(paragraph.metadata['block_type'], 'paragraph');
  });

  test('parses a todo list item with checked flag', () {
    final Document document = Document.fromJson(const <String, dynamic>{
      'document': <String, dynamic>{
        'type': 'page',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'todo_list',
            'data': <String, dynamic>{
              'delta': <dynamic>[
                <String, dynamic>{'insert': 'Buy milk'}
              ],
              'checked': false,
            },
          },
        ],
      },
    });

    final List<Content> contents = ContentParser.parseDocument(document);
    final ListItem item = contents.single as ListItem;
    final Map<String, dynamic> listMeta =
        item.metadata['list'] as Map<String, dynamic>;
    expect(listMeta['kind'], 'todo');
    expect(listMeta['checked'], false);
  });

  test('parses divider and columns structurally', () {
    final Document document = Document.fromJson(const <String, dynamic>{
      'document': <String, dynamic>{
        'type': 'page',
        'children': <dynamic>[
          <String, dynamic>{'type': 'divider'},
          <String, dynamic>{
            'type': 'columns',
            'children': <dynamic>[
              <String, dynamic>{
                'type': 'column',
                'children': <dynamic>[
                  <String, dynamic>{
                    'type': 'paragraph',
                    'data': <String, dynamic>{
                      'delta': <dynamic>[
                        <String, dynamic>{'insert': 'Left'},
                      ],
                    },
                  },
                ],
              },
              <String, dynamic>{
                'type': 'column',
                'children': <dynamic>[
                  <String, dynamic>{
                    'type': 'paragraph',
                    'data': <String, dynamic>{
                      'delta': <dynamic>[
                        <String, dynamic>{'insert': 'Right'},
                      ],
                    },
                  },
                ],
              },
            ],
          },
        ],
      },
    });

    final List<Content> contents = ContentParser.parseDocument(document);
    expect(contents.length, 2);

    final Divider divider = contents[0] as Divider;
    expect(divider.metadata['block_type'], 'divider');

    final Columns columns = contents[1] as Columns;
    expect(columns.metadata['block_type'], 'columns');
    expect(columns.value.length, 2);
    expect(columns.value.first.value.single, isA<Paragraph>());
    expect(columns.value.last.metadata['block_type'], 'column');
  });
}

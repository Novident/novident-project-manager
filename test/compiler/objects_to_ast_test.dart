import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_project_manager/src/ast/ast.dart';
import 'package:novident_project_manager/src/compiler/content_parser.dart';

/// Builds an editor [Document] from its JSON shape.
Document docOf(Map<String, dynamic> page) =>
    Document.fromJson(<String, dynamic>{'document': page});

Map<String, dynamic> paragraph(String text,
        {List<Map<String, dynamic>>? extraOps}) =>
    <String, dynamic>{
      'type': 'paragraph',
      'data': <String, dynamic>{
        'delta': <dynamic>[
          <String, dynamic>{'insert': text},
          ...?extraOps,
        ],
      },
    };

void main() {
  test('inline attributes are preserved on text spans', () {
    final Document document = docOf(<String, dynamic>{
      'type': 'page',
      'children': <dynamic>[
        <String, dynamic>{
          'type': 'paragraph',
          'data': <String, dynamic>{
            'delta': <dynamic>[
              <String, dynamic>{'insert': 'Hello '},
              <String, dynamic>{
                'insert': 'bold',
                'attributes': <String, dynamic>{'bold': true},
              },
            ],
          },
        },
      ],
    });

    final List<Content> contents = ContentParser.parseDocument(document);
    final Paragraph p = contents.single as Paragraph;
    expect(p.value.length, 2);
    expect(
      (p.value[1].metadata['attributes'] as Map<String, dynamic>)['bold'],
      isTrue,
    );
  });

  test('numbered list keeps number and ordered kind', () {
    final Document document = docOf(<String, dynamic>{
      'type': 'page',
      'children': <dynamic>[
        <String, dynamic>{
          'type': 'numbered_list',
          'data': <String, dynamic>{
            'delta': <dynamic>[
              <String, dynamic>{'insert': 'Step'}
            ],
            'number': 5,
          },
        },
      ],
    });

    final ListItem item =
        ContentParser.parseDocument(document).single as ListItem;
    final Map<String, dynamic> list =
        item.metadata['list'] as Map<String, dynamic>;
    expect(list['kind'], 'numbered');
    expect(list['number'], 5);
  });

  test('table is converted column-major with cell paragraphs', () {
    final Document document = docOf(<String, dynamic>{
      'type': 'page',
      'children': <dynamic>[
        <String, dynamic>{
          'type': 'table',
          'data': <String, dynamic>{'colsLen': 2, 'rowsLen': 1},
          'children': <dynamic>[
            <String, dynamic>{
              'type': 'table/cell',
              'data': <String, dynamic>{
                'colPosition': 0,
                'rowPosition': 0,
              },
              'children': <dynamic>[paragraph('Name')],
            },
            <String, dynamic>{
              'type': 'table/cell',
              'data': <String, dynamic>{
                'colPosition': 1,
                'rowPosition': 0,
              },
              'children': <dynamic>[paragraph('Role')],
            },
          ],
        },
      ],
    });

    final Table table = ContentParser.parseDocument(document).single as Table;
    expect(table.value.length, 2); // two columns
    expect((table.value[0].single as Paragraph).value.single.value, 'Name');
    expect((table.value[1].single as Paragraph).value.single.value, 'Role');
  });

  test('quote is parsed as a paragraph carrying its block type', () {
    final Document document = docOf(<String, dynamic>{
      'type': 'page',
      'children': <dynamic>[
        <String, dynamic>{
          'type': 'quote',
          'data': <String, dynamic>{
            'delta': <dynamic>[
              <String, dynamic>{'insert': 'Quoted'}
            ],
          },
        },
      ],
    });

    final Paragraph quote =
        ContentParser.parseDocument(document).single as Paragraph;
    expect(quote.metadata['block_type'], 'quote');
    expect(quote.value.single.value, 'Quoted');
  });

  test('divider and unknown containers keep structure', () {
    final Document document = docOf(<String, dynamic>{
      'type': 'page',
      'children': <dynamic>[
        <String, dynamic>{'type': 'divider'},
        <String, dynamic>{
          'type': 'columns',
          'children': <dynamic>[
            <String, dynamic>{
              'type': 'column',
              'children': <dynamic>[paragraph('Left')],
            },
          ],
        },
      ],
    });

    final List<Content> contents = ContentParser.parseDocument(document);
    expect(contents[0], isA<Divider>());
    final Columns columns = contents[1] as Columns;
    expect(columns.value.single.value.single, isA<Paragraph>());
  });
}

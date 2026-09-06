import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/ast/ast.dart';

void main() {
  group('AST content types expose their type and emptiness', () {
    test('text leaves', () {
      expect(Paragraph.empty().type, 'paragraph');
      expect(Paragraph.empty().isEmpty, isTrue);

      final TextSpan span = TextSpan(value: 'Hi');
      expect(span.type, 'span');
      expect(span.isEmpty, isFalse);
      expect(NewLine().value, '\n');
    });

    test('page aggregates contents', () {
      final DocumentPage page = DocumentPage.empty();
      expect(page.type, 'page');
      expect(page.isEmpty, isTrue);

      page.insert(Paragraph.text(text: 'A'));
      page.addAll(<Content>[Paragraph.text(text: 'B')]);
      expect(page.value.length, 2);
      expect(page.isEmpty, isFalse);
    });

    test('structural types', () {
      final ListItem listItem = ListItem(
        value: <Content>[Paragraph.empty()],
        metadata: const <String, dynamic>{
          'list': <String, dynamic>{'kind': 'bulleted'}
        },
      );
      expect(listItem.type, 'list');
      expect(listItem.isEmpty, isFalse);

      final Divider divider = Divider(metadata: const <String, dynamic>{});
      expect(divider.type, 'divider');
      expect(divider.isEmpty, isTrue);

      final Column column = Column(
        value: <Content>[],
        metadata: const <String, dynamic>{},
      );
      expect(column.type, 'column');
      expect(column.isEmpty, isTrue);

      final Columns columns = Columns(
        value: <Column>[column],
        metadata: const <String, dynamic>{},
      );
      expect(columns.type, 'columns');
      expect(columns.isEmpty, isFalse);

      final Image image = Image(
        value: 'url',
        metadata: const <String, dynamic>{},
      );
      expect(image.type, 'image');
      expect(image.isEmpty, isFalse);

      final Table table = Table(
        value: const <List<Content>>[<Content>[]],
        metadata: const <String, dynamic>{},
      );
      expect(table.type, 'table');
    });
  });

  group('mergeable behavior', () {
    test('paragraphs with equal metadata merge their spans', () {
      final Paragraph a = Paragraph.text(text: 'Hello ');
      final Paragraph b = Paragraph.text(text: 'world');
      expect(a.canMerge, isTrue);
      a.merge(b);
      expect(
        a.value.map((TextSpan s) => s.value).join(),
        'Hello world',
      );
    });

    test('text spans only merge when metadata matches', () {
      final TextSpan a = TextSpan(value: 'foo');
      final TextSpan b =
          TextSpan(value: 'bar', metadata: const <String, dynamic>{'x': 1});
      expect(a.canMerge, isTrue);
      a.merge(b);
      // Different metadata → nothing is merged.
      expect(a.value, 'foo');
    });

    test('structural types do not merge', () {
      expect(
          ListItem(value: <Content>[], metadata: const {}).canMerge, isFalse);
      expect(Column(value: <Content>[], metadata: const {}).canMerge, isFalse);
      expect(Columns(value: <Column>[], metadata: const {}).canMerge, isFalse);
      expect(Table(value: <List<Content>>[], metadata: const {}).canMerge,
          isFalse);
      expect(NewLine().canMerge, isFalse);
    });
  });
}

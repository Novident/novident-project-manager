import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../ast/ast.dart';

typedef CustomNodeToContent = List<Content> Function(Node);

/// Converts a `novident_editor_document` [Document] into the AST content model.
///
/// This is the structural “agnostic parser”: every editor block is mapped to
/// its AST equivalent preserving the tree — lists (including nested lists),
/// tables, images — instead of flattening everything into paragraphs.
///
/// Block mapping:
/// - `paragraph`, `heading`, `quote`, `todo_list` → [Paragraph] (kind carried
///   in metadata; `heading` keeps `level`, `todo_list` keeps `checked`).
/// - `bulleted_list` / `numbered_list` / `todo_list` → [ListItem] with its own
///   text paragraph and nested items as children.
/// - `image` → [Image].
/// - `table` → [Table] (`List<List<Content>>`, cell contents parsed
///   recursively).
/// - `divider` → [Divider].
/// - `columns` → [Columns] with one [Column] per editor `column` child.
///
/// Non-text leaf blocks without an AST equivalent are traversed so their text
/// is not lost, with the block type kept in metadata.
class ContentParser {
  const ContentParser._();

  static final Map<String, CustomNodeToContent>
      customNodeToAstCallbacksRegistry = {};

  /// Parses the whole [document] into AST content (pre-order).
  static List<Content> parseDocument(Document document) {
    return parseNode(document.root);
  }

  /// Parses [node] and its descendants into a list of AST content.
  static List<Content> parseNode(Node node, {int indent = 0}) {
    final List<Content> contents = <Content>[];
    final String type = node.type;

    if (type == BulletedListBlockKeys.type ||
        type == NumberedListBlockKeys.type ||
        type == TodoListBlockKeys.type) {
      contents.add(_listItem(
        node,
        indent: indent,
      ));
      return contents;
    }
    if (type == ImageBlockKeys.type) {
      contents.add(_image(node));
      return contents;
    }
    if (type == TableBlockKeys.type) {
      contents.add(_table(node));
      return contents;
    }
    if (type == DividerBlockKeys.type) {
      contents.add(Divider(
        metadata: _nodeMetadata(node, DividerBlockKeys.type),
      ));
      return contents;
    }
    if (type == ColumnsBlockKeys.type) {
      contents.add(_columns(node));
      return contents;
    }

    if (node.delta != null && node.delta!.isNotEmpty) {
      contents.add(_paragraph(node));
    }

    if (customNodeToAstCallbacksRegistry[node.type] != null) {
      final custom = customNodeToAstCallbacksRegistry[node.type]!.call(node);
      assert(
        custom.every((content) =>
            content is! LayoutDocument && content is! DocumentPage),
        'LayoutDocument or DocumentPage are not accepted as part '
        'of the available AST nodes to be returned on custom ast callbacks',
      );
      contents.addAll(custom);
    }

    // Recurse so nested/unknown blocks keep their text in order.
    for (final Node child in node.children) {
      contents.addAll(parseNode(child));
    }
    return contents;
  }

  /// Maps a `columns` node to a [Columns] group, one [Column] per child.
  static Columns _columns(Node node) {
    final List<Column> columns = <Column>[];
    for (final Node child in node.children) {
      if (child.type != ColumnBlockKeys.type) continue;
      columns.add(Column(
        value: parseNode(child),
        metadata: _nodeMetadata(child, ColumnBlockKeys.type),
      ));
    }
    return Columns(value: columns, metadata: _nodeMetadata(node));
  }

  /// Builds the metadata map of [node]: block type plus (optionally) the
  /// node-level attributes under the `attributes` key.
  static Map<String, dynamic> _nodeMetadata(Node node, [String? type]) {
    final Map<String, dynamic> blockAttributes = _blockAttributes(node);
    return <String, dynamic>{
      'block_type': type ?? node.type,
      if (blockAttributes.isNotEmpty) 'attributes': blockAttributes,
    };
  }

  static Paragraph _paragraph(Node node) {
    final Delta delta = node.delta!;
    final List<TextSpan> spans = <TextSpan>[];
    for (final TextOperation op in delta.operations) {
      if (op is TextInsert && op.data is String) {
        spans.add(TextSpan(
          value: op.data as String,
          metadata: <String, dynamic>{
            if (op.attributes != null && op.attributes!.isNotEmpty)
              'attributes': op.attributes,
          },
        ));
      }
    }
    return Paragraph(
      value: spans,
      metadata: _nodeMetadata(node),
    );
  }

  /// One list item: its text paragraph plus every nested list item child.
  static ListItem _listItem(Node node, {int indent = 0}) {
    final String kind = switch (node.type) {
      NumberedListBlockKeys.type => 'numbered',
      TodoListBlockKeys.type => 'todo',
      _ => 'bulleted',
    };
    final List<Content> value = <Content>[];
    if (node.delta != null && node.delta!.isNotEmpty) {
      value.add(_paragraph(node));
    }
    for (final Node child in node.children) {
      final List<Content> parsed = parseNode(child, indent: indent + 1);
      // Nested children of a list are deeper list items; keep them together.
      value.addAll(parsed);
    }

    final int? number = node.attributes['number'] as int?;
    final bool? checked = node.attributes['checked'] as bool?;
    return ListItem(
      value: value,
      metadata: <String, dynamic>{
        'indent': indent,
        'list': <String, dynamic>{
          'kind': kind,
          if (number != null) 'number': number,
          if (checked != null) 'checked': checked,
        },
        'block_type': node.type,
      },
    );
  }

  static Image _image(Node node) {
    return Image(
      value: (node.attributes[ImageBlockKeys.url] as String?) ?? '',
      metadata: _nodeMetadata(node, ImageBlockKeys.type),
    );
  }

  static Table _table(Node node) {
    final int cols = node.attributes[TableBlockKeys.colsLen] as int? ?? 0;
    final int rows = node.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
    final List<List<Content>> grid =
        List<List<Content>>.generate(cols, (_) => <Content>[]);

    for (final Node cell in node.children) {
      if (cell.type != TableCellBlockKeys.type) continue;
      final int col =
          cell.attributes[TableCellBlockKeys.colPosition] as int? ?? 0;
      final int row =
          cell.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
      final List<Content> cellContent = <Content>[];
      for (final Node contentNode in cell.children) {
        cellContent.addAll(parseNode(contentNode));
      }
      while (grid[col].length <= row) {
        grid[col].add(Paragraph.empty());
      }
      grid[col][row] = _singleContent(cellContent);
    }

    return Table(
      value: grid,
      metadata: <String, dynamic>{
        'block_type': TableBlockKeys.type,
        'cols': cols,
        'rows': rows,
      },
    );
  }

  /// Block-level attributes of the editor node (its `data` map) minus `delta`.
  static Map<String, dynamic> _blockAttributes(Node node) {
    final Map<String, dynamic> attributes =
        Map<String, dynamic>.from(node.attributes);
    attributes.remove('delta');
    return attributes;
  }

  /// Collapses parsed cell contents into one AST content: a single item is
  /// returned as-is; several paragraphs are merged into one; anything else
  /// falls back to the first item.
  static Content _singleContent(List<Content> contents) {
    if (contents.isEmpty) return Paragraph.empty();
    if (contents.length == 1) return contents.first;
    final List<TextSpan> spans = contents
        .whereType<Paragraph>()
        .expand((Paragraph p) => p.value)
        .toList();
    return spans.isEmpty ? contents.first : Paragraph(value: spans);
  }
}

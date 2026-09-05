# Parsing to AST — parsers & expected output

The compiler converts two sources into the AST content model
(`lib/src/ast/`): a **layout** (via `LayoutCompiler`) and rich editor
**documents** (via `ContentParser`).

## AST recap (`lib/src/ast/`)

Every AST node is a `Content<T>` with `value`, `metadata`, optional `style`,
a `type` string, `isEmpty` and (for some) mergeability.

| Type | `type` | Value | Notes |
|---|---|---|---|
| `DocumentPage` | `page` | `List<Content>` | page aggregate (insert/addAll/split) |
| `Paragraph` | `paragraph` | `List<TextSpan>` | text block (spans) |
| `TextSpan` | `span` | `String` | single text run |
| `NewLine` | `span` (`\n`) | `String` | non-mergeable line |
| `ListItem` | `list` | `List<Content>` | list item + nested items |
| `Image` | `image` | `String` (url) | embedded image |
| `Table` | `table` | `List<List<Content>>` | column-major grid |
| `Divider` | `divider` | `null` | horizontal rule |
| `Column` | `column` | `List<Content>` | one column of a group |
| `Columns` | `columns` | `List<Column>` | side-by-side columns |

Metadata conventions: `block_type` always present; editor block attributes
(level, align, styleRef, checked, …) are copied under `attributes`; list
items carry `indent` and a `list` map (`kind`, `number`, `checked`).

## `ContentParser` — editor Document → AST

```dart
final Document document = /* novident_editor_document */;
final List<Content> contents = ContentParser.parseDocument(document);
```

Mapping (structural, never flattened):

| Editor block | AST |
|---|---|
| `paragraph` / `heading` / `quote` | `Paragraph` (`attributes.level`, `styleRef`, …) |
| `bulleted_list` / `numbered_list` / `todo_list` | `ListItem` (own paragraph + nested items in `value`) |
| `image` | `Image` (url + align/width/height) |
| `table` (`colsLen`/`rowsLen` + `table/cell`) | `Table` rebuilt by `colPosition`/`rowPosition` |
| `divider` | `Divider` |
| `columns` → `column` children | `Columns` of `Column`s |

Inline delta attributes (bold, italic, href, …) are preserved per span under
`attributes`:

```dart
final List<Content> c = ContentParser.parseDocument(document);
final Paragraph p = c.first as Paragraph;
p.value // List<TextSpan>, each with optional metadata.attributes
```

## `LayoutCompiler` — Layout + Node + Context → page

```dart
final DocumentPage? page = LayoutCompiler.compileLayout(layout, node, context,
    fontFamily: 'Georgia');
```

- Returns `null` for non-normal folders.
- Emits page new-lines (from `NewPageOptions`), title & synopsis sections
  (`LayoutSectionBuilder`) and the body text (parsed via `ContentParser`, with
  placeholder replacement unless the context defers it).
- `Layout.applyLayout` is a thin delegate to this method.

## Expected output (example)

Input editor document (JSON): heading “Chapter” (`level: 1`), a bulleted list
`Parent` → `Child`, an image and a paragraph “Done”. Output AST:

```
DocumentPage
├─ Paragraph  metadata{block_type: heading, attributes:{level:1}}
│    └─ TextSpan("Chapter")
├─ ListItem   metadata{indent:0, list:{kind:bulleted}}
│    ├─ Paragraph("Parent")
│    └─ ListItem  metadata{indent:1, list:{kind:bulleted}}
│         └─ Paragraph("Child")
├─ Image      value: url   metadata{block_type:image, attributes:{align:…}}
└─ Paragraph  "Done"
```

## Notes & future

- List numbering restart/indentation is resolved by the compiler consumer
  using `metadata.indent` + `list.number`.
- Table cells are parsed recursively; a cell with several paragraphs is merged
  into one `Paragraph` (single-content cells stay as-is).
- `quote` is currently represented as a `Paragraph` (block_type `quote`);
  a dedicated AST type can be added if the compiler needs it.

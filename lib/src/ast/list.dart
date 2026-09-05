import 'ast.dart';

/// A list item in the AST, mirroring an editor list block
/// (`bulleted_list` / `numbered_list` / `todo_list`).
///
/// The structure is preserved: [value] holds the item's contents — the item's
/// own text paragraph first, followed by every nested list item (its
/// `children`), so indentation/numbering can be re-derived by the compiler.
/// The list kind is carried in [metadata] (`list`):
/// `{ kind: 'bulleted'|'numbered'|'todo', number: int?, checked: bool? }`.
class ListItem extends Content<List<Content>> with Mergable {
  ListItem({
    required super.value,
    required super.metadata,
    super.style,
  });

  @override
  String get type => 'list';

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get canMerge => false;

  @override
  Set<Type> get mergeableTypesSupported => <Type>{};

  @override
  void merge(Object entity) {
    super.merge(entity);
    return;
  }
}

import 'ast.dart';

/// A single column inside a [Columns] group (editor `column` block).
class Column extends Content<List<Content>> with Mergable {
  Column({
    required super.value,
    required super.metadata,
  });

  @override
  String get type => 'column';

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

/// A columns group in the AST (editor `columns` block): a list of [Column]s
/// rendered side by side.
class Columns extends Content<List<Column>> with Mergable {
  Columns({
    required super.value,
    required super.metadata,
  });

  @override
  String get type => 'columns';

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

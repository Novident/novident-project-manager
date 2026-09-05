import 'package:novident_editor_styles/novident_editor_styles.dart';
import 'ast.dart';

class Table extends Content<List<List<Content>>> with Mergable {
  Table({
    required super.value,
    required super.metadata,
    NovidentTableStyleDefinition? super.style,
  });

  @override
  String get type => 'table';

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get canMerge => false;

  @override
  Set<Type> get mergeableTypesSupported => {};

  @override
  void merge(Object entity) {
    super.merge(entity);
    return;
  }
}

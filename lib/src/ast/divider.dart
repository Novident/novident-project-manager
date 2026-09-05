import 'ast.dart';

/// A divider block in the AST (editor `divider` block). It carries no value
/// and is never merged.
class Divider extends Content<Null> {
  Divider({
    required super.metadata,
    super.style,
  }) : super(value: null);

  @override
  String get type => 'divider';

  @override
  bool get isEmpty => true;
}

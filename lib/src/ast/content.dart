import 'package:novident_editor_styles/novident_editor_styles.dart';

abstract class Content<T extends Object?> {
  T value;
  NovidentStyleDefinition? style;
  final Map<String, dynamic> metadata;

  Content({required this.value, required this.metadata, this.style});

  void pushStyle(NovidentStyleDefinition style) => this.style = style;

  bool get isEmpty;

  String get type;
}

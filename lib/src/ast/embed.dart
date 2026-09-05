import 'ast.dart';

abstract class Embed<T> extends Content<T> {
  final bool local;

  Embed({required super.value, required super.metadata, required this.local});
}

class Image extends Content<String> {
  Image({required super.value, required super.metadata});

  @override
  String get type => 'image';

  @override
  bool get isEmpty => value.isEmpty;
}

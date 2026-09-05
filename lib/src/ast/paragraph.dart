import 'package:flutter/foundation.dart';

import '../extensions/cast_extension.dart';
import '../extensions/string_extension.dart';
import 'ast.dart';

class Paragraph extends Content<List<TextSpan>> with Mergable {
  Paragraph({
    required super.value,
    Map<String, dynamic> metadata = const {},
    super.style,
  }) : super(metadata: {...metadata});

  Paragraph.empty({
    Map<String, dynamic> metadata = const {},
    super.style,
  }) : super(
          value: [],
          metadata: {...metadata},
        );

  Paragraph.text({
    required String text,
    Map<String, dynamic> metadata = const {},
  }) : super(
          value: <TextSpan>[TextSpan(value: text)],
          metadata: {...metadata},
        );

  void insertSpan(TextSpan span) {
    value.add(span);
  }

  void insert(
    String text, {
    Map<String, dynamic> metadata = const {},
  }) {
    value.add(
      TextSpan(
        value: text,
        metadata: metadata,
      ),
    );
  }

  @override
  String get type => 'paragraph';

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get canMerge => true;

  @override
  Set<Type> get mergeableTypesSupported => {TextSpan, Paragraph};

  @override
  void merge(Object entity) {
    super.merge(entity);

    if (entity is TextSpan) {
      value.add(entity);
      return;
    }

    final Paragraph other = entity as Paragraph;
    if (!mapEquals(metadata, other.metadata)) {
      return;
    }
    value.addAll(other.value);
  }
}

class TextSpan extends Content<String> with Mergable {
  TextSpan({required super.value, super.metadata = const {}});

  NewLine? get asNewLine => value == '\n' ? NewLine() : null;

  @override
  String get type => 'span';

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get canMerge => true;

  @override
  Set<Type> get mergeableTypesSupported => {TextSpan};

  @override
  void merge(Object entity) {
    super.merge(entity);

    final TextSpan other = entity as TextSpan;
    if (!mapEquals(metadata, other.metadata)) {
      return;
    }

    value = value.insert(other.value);
  }
}

class NewLine extends TextSpan with Mergable {
  NewLine() : super(value: '\n');

  NewLine.fixed({String newLine = '\n', String? prefix, String? suffix})
      : super(value: '${prefix.orEmpty()}$newLine${suffix.orEmpty()}');

  @override
  bool get canMerge => false;

  @override
  Set<Type> get mergeableTypesSupported => <Type>{NewLine};

  @override
  void merge(Object entity) {
    super.merge(entity);

    value = value.insert(entity.cast<NewLine>().value);
    metadata.addAll(entity.cast<NewLine>().metadata);
  }
}

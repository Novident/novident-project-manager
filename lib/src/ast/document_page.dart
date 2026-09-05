import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'ast.dart';

final class DocumentPage extends Content<List<Content>>
    with LinkedListEntry<DocumentPage>, Mergable {
  DocumentPage({required super.value, required super.metadata});

  DocumentPage.empty({Map<String, dynamic>? metadata})
      : super(value: <Content<Object?>>[], metadata: metadata ?? {});

  void addAll(Iterable<Content> contents) {
    value.addAll(contents);
  }

  void insert(Content content) {
    value.add(content);
  }

  //TODO: we should support char offsets
  (DocumentPage, DocumentPage?) splitAt(
    int index, {
    Map<String, dynamic>? nextMetadata,
  }) {
    if (isEmpty) return (this, null);
    return (
      DocumentPage(
        value: value.getRange(0, index).toList(),
        metadata: metadata,
      ),
      DocumentPage(
        value: value.getRange(index, value.length).toList(),
        metadata: nextMetadata ?? metadata,
      ),
    );
  }

  @override
  String get type => 'page';

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get canMerge => true;

  @override
  Set<Type> get mergeableTypesSupported => <Type>{DocumentPage};

  @override
  void merge(Object entity) {
    super.merge(entity);

    final DocumentPage other = entity as DocumentPage;
    if (!mapEquals(metadata, other.metadata)) {
      return;
    }

    value.insertAll(value.length, other.value);
  }
}

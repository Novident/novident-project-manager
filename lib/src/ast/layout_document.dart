import 'dart:collection';

import 'ast.dart';

class LayoutDocument with Mergable {
  final LinkedList<DocumentPage> pages;

  LayoutDocument({required this.pages});

  LayoutDocument.single({required DocumentPage page})
      : pages = LinkedList()..add(page);
  LayoutDocument.iterable({required Iterable<DocumentPage> pages})
      : pages = LinkedList()..addAll(pages);

  LayoutDocument.empty() : pages = LinkedList();

  void add(DocumentPage page, {int? index}) {
    if (index != null) {
      pages.elementAt(index).insertBefore(page);
      return;
    }
    pages.add(page);
  }

  void insertContent(Content content) {
    if (content is DocumentPage) {
      pages.add(content);
      return;
    }

    if (pages.isEmpty) {
      pages.add(DocumentPage.empty());
    }

    last.value.add(content);
  }

  DocumentPage get first => pages.first;

  DocumentPage get last => pages.last;

  @override
  bool get canMerge => true;

  @override
  void merge(Object entity) {
    super.merge(entity);

    final LayoutDocument other = entity as LayoutDocument;
    pages.addAll(other.pages);
  }

  @override
  Set<Type> get mergeableTypesSupported => {LayoutDocument};
}


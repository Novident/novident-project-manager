part of '../separators/layout_separator.dart';

/// A separator that breaks the page: the following content is written on a
/// completely different page from the current one.
@immutable
class PageBreakSeparatorStrategy extends LayoutSeparator {
  const PageBreakSeparatorStrategy._();

  /// Shared instance of the page-break separator.
  static PageBreakSeparatorStrategy get instance => _instance == null
      ? _instance = PageBreakSeparatorStrategy._()
      : _instance!;

  static PageBreakSeparatorStrategy? _instance;

  /// Whether using this separator forces a page break: always true.
  @override
  bool get breakAfterUse => true;

  /// Stable identifier of the page-break separator.
  @override
  String get id => '3';

  /// Writes nothing (the page break itself is handled by the compiler).
  @override
  String buildSeparator() {
    return '';
  }

  @override
  bool operator ==(covariant PageBreakSeparatorStrategy other) {
    if (identical(this, other)) return true;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
